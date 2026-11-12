-- BIG BROTHER A/R Bank Assistant V1 · 12-Nov-2026
-- Read-only overview, staged requests (NO bank deduction), Admin approval,
-- and staff Invoice Generator received-date enforcement.
-- Run on Local Brain only after a full database backup.
CREATE OR REPLACE FUNCTION public.bb_ar_bank_assistant_list_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE
  v_balances jsonb;
  v_invoices jsonb;
  v_all boolean;
BEGIN
  IF auth.uid() IS NULL OR NOT public.bb_has_module_access('accounts_receivable','view') THEN
    RAISE EXCEPTION 'Accounts Receivable view access required';
  END IF;
  v_all := public.bb_has_module_access('route.ar-all','view');
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'transactionId',b.transaction_id,
    'customerId',b.customer_id,'customer',c.customer_name,'locationCode',c.location_code,
    'payer',coalesce(t.payer_name,''),'receivedDate',b.received_date,
    'bankName',coalesce(t.bank_name,''),'currency',b.currency,
    'invoiceCurrency',coalesce(b.invoice_currency,b.currency),
    'exchangeRate',coalesce(b.approved_exchange_rate,1),
    'originalAmount',b.original_amount,'usedAmount',b.used_amount,
    'remainingAmount',b.remaining_amount,
    'equivalentRemaining',case
       when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount
       when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0)
       else b.remaining_amount*b.approved_exchange_rate end
  ) ORDER BY b.received_date,b.transaction_id,b.customer_id),'[]'::jsonb)
  INTO v_balances
  FROM public.bb_bank_balance_snapshot b
  JOIN public.bb_verified_bank_transactions t ON t.transaction_id=b.transaction_id
  JOIN public.customers c ON c.customer_id=b.customer_id AND c.active=true
  WHERE b.status='AVAILABLE' AND b.remaining_amount>0 AND t.status='AVAILABLE'
    AND (public.bb_is_admin() OR
       (v_all AND public.bb_has_location_access(c.location_code)) OR
       (NOT v_all AND private.bb_is_current_receivable_owner(c.location_code)));

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'invoiceId',i.invoice_id,'invoiceNo',i.invoice_no,'invoiceDate',i.invoice_date,
    'customerId',i.customer_id,'customer',i.customer_name_snapshot,
    'locationCode',i.location_code,'currency',i.currency,'outstanding',i.outstanding,
    'pendingRequestId',coalesce(pr.request_id,'')
  ) ORDER BY i.invoice_date,i.invoice_no,i.invoice_id),'[]'::jsonb)
  INTO v_invoices
  FROM public.invoices i
  LEFT JOIN LATERAL (
    SELECT r.request_id FROM public.ar_request_allocations a
    JOIN public.ar_payment_requests r ON r.request_id=a.request_id
    WHERE a.invoice_id=i.invoice_id AND lower(coalesce(r.status,''))='processing'
    ORDER BY r.created_at DESC LIMIT 1
  ) pr ON true
  WHERE i.outstanding>0
    AND lower(btrim(coalesce(i.payment_method,''))) IN
       ('credit','partially paid in cash','partially paid in bank')
    AND (public.bb_is_admin()
       OR (v_all AND public.bb_has_location_access(i.location_code))
       OR (NOT v_all AND private.bb_is_current_receivable_owner(i.location_code)))
    AND EXISTS (SELECT 1 FROM public.bb_bank_balance_snapshot b
       JOIN public.bb_verified_bank_transactions t ON t.transaction_id=b.transaction_id
       WHERE b.customer_id=i.customer_id AND b.status='AVAILABLE'
         AND b.remaining_amount>0 AND t.status='AVAILABLE');

  RETURN jsonb_build_object('success',true,'balances',v_balances,'invoices',v_invoices,
    'canSubmit',public.bb_has_module_access('accounts_receivable','create'),
    'canApprove',public.bb_is_admin() AND public.bb_has_module_access('accounts_receivable','approve'),
    'scope',case when public.bb_is_admin() then 'ADMIN'
       when v_all then 'ASSIGNED_LOCATIONS' else 'RECEIVABLE_OWNER' end);
END;
$func$;

CREATE OR REPLACE FUNCTION public.bb_ar_bank_assistant_submit_v1(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE
  v_tx text:=upper(btrim(coalesce(p_payload->>'transactionId','')));
  v_customer text:=btrim(coalesce(p_payload->>'customerId',''));
  v_reg public.bb_verified_bank_transactions%ROWTYPE;
  v_invoice public.invoices%ROWTYPE;
  v_item jsonb;
  v_id text;
  v_seen text[]:=array[]::text[];
  v_currency text;
  v_amount numeric;
  v_total numeric:=0;
  v_available numeric;
  v_count integer:=0;
  v_idx integer:=0;
  v_request_id text;
  v_actor text:=public.bb_actor_name();
  v_staff text:=public.bb_actor_staff_id();
  v_all boolean;
  v_precision integer;
  v_customer_name text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.bb_has_module_access('accounts_receivable','view')
     OR NOT public.bb_has_module_access('accounts_receivable','create')
  THEN RAISE EXCEPTION 'A/R recommendation submission access denied'; END IF;
  IF length(v_tx)<4 OR length(v_tx)>160 OR v_customer=''
    THEN RAISE EXCEPTION 'Select one registered bank receipt and customer'; END IF;
  IF jsonb_typeof(p_payload->'allocations') IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_payload->'allocations') NOT BETWEEN 1 AND 50
  THEN RAISE EXCEPTION 'Select 1–50 invoices for this bank receipt'; END IF;

  v_all:=public.bb_has_module_access('route.ar-all','view');
  IF NOT EXISTS(SELECT 1 FROM public.customers c
    WHERE c.customer_id=v_customer AND c.active=true
    AND (public.bb_is_admin()
      OR (v_all AND public.bb_has_location_access(c.location_code))
      OR (NOT v_all AND private.bb_is_current_receivable_owner(c.location_code))))
  THEN RAISE EXCEPTION 'Customer outside authorized A/R scope'; END IF;
  SELECT c.customer_name INTO v_customer_name FROM public.customers c WHERE c.customer_id=v_customer;
  PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tx));
  SELECT * INTO v_reg FROM public.bb_verified_bank_transactions t
     WHERE upper(btrim(t.transaction_id))=v_tx FOR UPDATE;
  IF NOT FOUND OR v_reg.status<>'AVAILABLE'
    THEN RAISE EXCEPTION 'Registered bank balance is no longer available'; END IF;
  IF v_reg.received_date IS NULL
    THEN RAISE EXCEPTION 'Bank received date is missing; correct the Bank Register before submitting'; END IF;
  IF EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=v_reg.transaction_id) THEN
    IF NOT EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s
       WHERE s.transaction_id=v_reg.transaction_id AND s.customer_id=v_customer)
    THEN RAISE EXCEPTION 'Customer has no approved share of this receipt'; END IF;
  ELSIF v_reg.customer_id<>v_customer THEN
    RAISE EXCEPTION 'Registered receipt belongs to another customer';
  END IF;

  SELECT b.invoice_currency,
    case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount
      when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0)
      else b.remaining_amount*b.approved_exchange_rate end
  INTO v_currency,v_available FROM public.bb_bank_balance_snapshot b
  WHERE b.transaction_id=v_reg.transaction_id AND b.customer_id=v_customer
    AND b.status='AVAILABLE' AND b.remaining_amount>0;
  IF NOT FOUND OR v_available IS NULL OR v_available<=0
    THEN RAISE EXCEPTION 'Registered balance was consumed or not allocated to this customer'; END IF;
  v_currency:=upper(v_currency);
  v_precision:=case when v_currency='KHR' then 0 else 2 end;

  FOR v_item IN SELECT x.value FROM jsonb_array_elements(p_payload->'allocations') x(value)
      ORDER BY x.value->>'invoiceId' LOOP
    v_id:=btrim(coalesce(v_item->>'invoiceId',''));
    IF v_id='' OR v_id=ANY(v_seen)
       THEN RAISE EXCEPTION 'Duplicate or missing invoice in recommendation'; END IF;
    v_seen:=array_append(v_seen,v_id);
    IF coalesce(v_item->>'amount','') !~ '^[0-9]+([.][0-9]+)?$'
       THEN RAISE EXCEPTION 'Invalid invoice allocation amount'; END IF;
    v_amount:=(v_item->>'amount')::numeric;
    IF v_amount<=0 OR v_amount<>round(v_amount,v_precision)
       THEN RAISE EXCEPTION 'Invoice amount must use valid currency precision'; END IF;
    SELECT * INTO v_invoice FROM public.invoices WHERE invoice_id=v_id FOR UPDATE;
    IF NOT FOUND OR v_invoice.customer_id<>v_customer
       THEN RAISE EXCEPTION 'Invoice is not assigned to this bank customer'; END IF;
    IF NOT (public.bb_is_admin()
       OR (v_all AND public.bb_has_location_access(v_invoice.location_code))
       OR (NOT v_all AND private.bb_is_current_receivable_owner(v_invoice.location_code)))
       THEN RAISE EXCEPTION 'Invoice outside authorized A/R scope'; END IF;
    IF v_invoice.outstanding<=0 OR
       lower(btrim(coalesce(v_invoice.payment_method,''))) NOT IN
          ('credit','partially paid in cash','partially paid in bank')
       THEN RAISE EXCEPTION 'Selected invoice is not an active A/R invoice'; END IF;
    IF upper(v_invoice.currency)<>v_currency
       THEN RAISE EXCEPTION 'Registered balance and invoice currencies differ'; END IF;
    IF v_amount>v_invoice.outstanding+0.000001
       THEN RAISE EXCEPTION 'Selected invoice amount exceeds its outstanding balance'; END IF;
    IF EXISTS(SELECT 1 FROM public.ar_request_allocations a
       JOIN public.ar_payment_requests r ON r.request_id=a.request_id
       WHERE a.invoice_id=v_invoice.invoice_id AND lower(coalesce(r.status,''))='processing')
       THEN RAISE EXCEPTION 'Invoice % already has a pending payment request',v_invoice.invoice_no; END IF;
    v_total:=v_total+v_amount;
    v_count:=v_count+1;
  END LOOP;
  IF v_total>v_available+0.000001
  THEN RAISE EXCEPTION 'Receipt balance changed: only % % remains for this customer',round(v_available,v_precision),v_currency; END IF;

  v_request_id:=public.bb_next_prefixed_id('public.ar_payment_requests'::regclass,'request_id','ARR',5);
  INSERT INTO public.ar_payment_requests(
    request_id,request_date,customer_id,customer_name_snapshot,currency,
    request_type,payment_method,bank_payment,bank_reference,transaction_id,note,
    requested_by_staff_id,requested_by_name_snapshot,requested_by_user_id,status)
  VALUES(v_request_id,(now() AT TIME ZONE 'Asia/Phnom_Penh')::date,
    v_customer,v_customer_name,v_currency,'Bank Assistant','Bank',
    v_reg.bank_name,NULL,v_reg.transaction_id,
    'Registered bank recommendation. Received '||v_reg.received_date::text||
      '. '||left(btrim(coalesce(p_payload->>'note','')),300),
    v_staff,v_actor,auth.uid(),'Processing');

  FOR v_item IN SELECT x.value FROM jsonb_array_elements(p_payload->'allocations') x(value)
     ORDER BY x.value->>'invoiceId' LOOP
    v_idx:=v_idx+1;
    INSERT INTO public.ar_request_allocations(
       request_allocation_id,request_id,invoice_id,invoice_no_snapshot,requested_amount,currency)
    SELECT v_request_id||'-'||lpad(v_idx::text,2,'0'),
      v_request_id,i.invoice_id,i.invoice_no,(v_item->>'amount')::numeric,i.currency
    FROM public.invoices i WHERE i.invoice_id=btrim(v_item->>'invoiceId');
  END LOOP;
  RETURN jsonb_build_object('success',true,'requestId',v_request_id,
     'totalAmount',v_total,'invoiceCount',v_count,'currency',v_currency,
     'transactionId',v_reg.transaction_id,'status','Processing');
END;
$func$;

CREATE OR REPLACE FUNCTION public.bb_ar_bank_assistant_clear_v1(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE
  v_request public.ar_payment_requests%ROWTYPE;
  v_reg public.bb_verified_bank_transactions%ROWTYPE;
  v_a public.ar_request_allocations%ROWTYPE;
  v_inv public.invoices%ROWTYPE;
  v_first public.invoices%ROWTYPE;
  v_tx text;
  v_bank text:=nullif(btrim(coalesce(p_payload->>'bankPayment','')),'');
  v_payment_id text;
  v_currency text;
  v_available numeric;
  v_total numeric:=0;
  v_count int:=0;
  v_idx int:=0;
  v_date date:=(now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
  v_actor text:=public.bb_actor_name();
  v_staff text:=public.bb_actor_staff_id();
  v_invoice_names text;
  v_rate numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT public.bb_is_admin()
     OR NOT public.bb_has_module_access('accounts_receivable','approve')
  THEN RAISE EXCEPTION 'Only Admin can approve Bank Assistant recommendations'; END IF;
  SELECT * INTO v_request FROM public.ar_payment_requests
   WHERE request_id=btrim(coalesce(p_payload->>'requestId','')) FOR UPDATE;
  IF NOT FOUND OR v_request.request_type<>'Bank Assistant'
    THEN RAISE EXCEPTION 'Not a Bank Assistant request'; END IF;
  IF lower(coalesce(v_request.status,''))<>'processing'
    THEN RAISE EXCEPTION 'Request already reviewed'; END IF;
  IF lower(btrim(coalesce(p_payload->>'paymentMethod',''))) <>'bank'
    THEN RAISE EXCEPTION 'Bank Assistant recommendations must clear by registered Bank only'; END IF;
  v_tx:=upper(btrim(coalesce(v_request.transaction_id,'')));
  IF v_tx='' OR (nullif(btrim(coalesce(p_payload->>'transactionId','')),'') IS NOT NULL
      AND upper(btrim(p_payload->>'transactionId'))<>v_tx)
    THEN RAISE EXCEPTION 'The registered bank transaction cannot be replaced during approval'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tx));
  SELECT * INTO v_reg FROM public.bb_verified_bank_transactions t
    WHERE upper(btrim(t.transaction_id))=v_tx FOR UPDATE;
  IF NOT FOUND OR v_reg.status<>'AVAILABLE'
    THEN RAISE EXCEPTION 'Registered bank receipt was already consumed or cancelled'; END IF;
  IF v_reg.bank_name IS NOT NULL AND lower(btrim(v_reg.bank_name))<>lower(coalesce(v_bank,''))
    THEN RAISE EXCEPTION 'Actual receiving bank does not match Bank Register'; END IF;
  IF v_bank IS NULL THEN RAISE EXCEPTION 'Enter the actual receiving Bank name'; END IF;
  IF v_reg.received_date IS NULL THEN RAISE EXCEPTION 'Registered bank received date is missing'; END IF;

  SELECT b.invoice_currency,case
    when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount
    when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0)
    else b.remaining_amount*b.approved_exchange_rate end
  INTO v_currency,v_available FROM public.bb_bank_balance_snapshot b
  WHERE b.transaction_id=v_reg.transaction_id AND b.customer_id=v_request.customer_id
     AND b.status='AVAILABLE' AND b.remaining_amount>0;
  IF NOT FOUND OR v_available<=0 THEN RAISE EXCEPTION 'No available outlet allocation for this receipt'; END IF;
  IF v_request.currency<>v_currency THEN RAISE EXCEPTION 'Registered bank currency changed after request'; END IF;

  FOR v_a IN SELECT * FROM public.ar_request_allocations
    WHERE request_id=v_request.request_id ORDER BY invoice_id LOOP
    SELECT * INTO v_inv FROM public.invoices WHERE invoice_id=v_a.invoice_id FOR UPDATE;
    IF NOT FOUND OR v_inv.customer_id<>v_request.customer_id
      THEN RAISE EXCEPTION 'Invoice no longer belongs to the selected customer'; END IF;
    IF v_a.currency<>v_request.currency OR v_inv.currency<>v_request.currency
      THEN RAISE EXCEPTION 'Invoice currency mismatch in recommendation'; END IF;
    IF v_a.requested_amount<=0 OR v_a.requested_amount>v_inv.outstanding+0.000001
      THEN RAISE EXCEPTION 'Invoice % outstanding changed; review this request again',v_inv.invoice_no; END IF;
    IF v_count=0 THEN v_first:=v_inv; END IF;
    v_count:=v_count+1;
    v_total:=v_total+v_a.requested_amount;
  END LOOP;
  IF v_count=0 OR v_total>v_available+0.000001
    THEN RAISE EXCEPTION 'Insufficient registered balance at approval. Refresh Bank Assistant'; END IF;
  v_rate:=case when v_reg.currency=v_request.currency
    then coalesce(nullif(v_first.exchange_rate,0),1)
    else v_reg.approved_exchange_rate end;
  IF v_rate<=0 THEN RAISE EXCEPTION 'Invalid approved bank exchange rate'; END IF;
  SELECT string_agg(a.invoice_no_snapshot,', ' ORDER BY a.invoice_id) INTO v_invoice_names
   FROM public.ar_request_allocations a WHERE a.request_id=v_request.request_id;
  v_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
  INSERT INTO public.payments(
    payment_id,invoice_id,invoice_no_snapshot,payment_date,customer_id,customer_name_snapshot,
    location_code,salesperson_staff_id,salesperson_name_snapshot,payment_method,bank_payment,
    bank_reference,currency,exchange_rate,amount,physical_cash_usd,physical_cash_khr,
    note,transaction_id,entered_by_staff_id,entered_by_name_snapshot,approved_by_name_snapshot,
    payment_source,entered_by_user_id,approved_by_user_id)
  VALUES(v_payment_id,case when v_count=1 then v_first.invoice_id else null end,
    v_invoice_names,v_date,v_request.customer_id,v_request.customer_name_snapshot,
    case when v_count=1 then v_first.location_code else null end,
    v_request.requested_by_staff_id,v_request.requested_by_name_snapshot,'Bank',v_bank,
    nullif(btrim(coalesce(p_payload->>'bankReference','')),''),
    v_request.currency,v_rate,v_total,0,0,
    'Bank Assistant '||v_request.request_id||'; bank received '||v_reg.received_date::text||
       '; Admin approved '||v_date::text,
    v_reg.transaction_id,v_staff,v_actor,v_actor,'Receivable',auth.uid(),auth.uid());

  FOR v_a IN SELECT * FROM public.ar_request_allocations
    WHERE request_id=v_request.request_id ORDER BY invoice_id LOOP
    v_idx:=v_idx+1;
    INSERT INTO public.payment_allocations(
      allocation_id,payment_id,invoice_id,invoice_no_snapshot,applied_amount,currency)
    VALUES(v_payment_id||'-'||lpad(v_idx::text,2,'0'),v_payment_id,
      v_a.invoice_id,v_a.invoice_no_snapshot,v_a.requested_amount,v_request.currency);
    UPDATE public.invoices SET
      amount_paid=least(grand_total,amount_paid+v_a.requested_amount),
      outstanding=greatest(grand_total-least(grand_total,amount_paid+v_a.requested_amount),0),
      credit_amount=greatest(grand_total-least(grand_total,amount_paid+v_a.requested_amount),0),
      status=case when greatest(grand_total-least(grand_total,amount_paid+v_a.requested_amount),0)<=0
         then 'Paid' else 'Processing' end
    WHERE invoice_id=v_a.invoice_id;
  END LOOP;
  UPDATE public.ar_payment_requests SET
     status='Cleared',reviewed_by_name_snapshot=v_actor,
     reviewed_by_user_id=auth.uid(),reviewed_at=now(),payment_id=v_payment_id,
     payment_method='Bank',bank_payment=v_bank,
     bank_reference=nullif(btrim(coalesce(p_payload->>'bankReference','')),''),
     reject_reason=NULL
  WHERE request_id=v_request.request_id;
  RETURN jsonb_build_object('success',true,'requestId',v_request.request_id,
    'paymentId',v_payment_id,'paymentMethod','Bank','approvedBy',v_actor,
    'paymentDate',v_date,'bankReceivedDate',v_reg.received_date,
    'invoiceCount',v_count,'totalAmount',v_total,'currency',v_request.currency);
END;
$func$;

-- Staff may use only receipts received ON/AFTER the sale date in Invoice Generator.
-- Covers single wallet, split payment, and multi-bank: all INSERT initial payments.
CREATE OR REPLACE FUNCTION private.bb_invoice_bank_received_date_guard_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $func$
DECLARE
  v_received date;
  v_sale date;
BEGIN
  IF upper(btrim(coalesce(NEW.payment_source,'')))<>'INVOICE'
     OR upper(btrim(coalesce(NEW.payment_method,'')))<>'BANK'
     OR public.bb_is_admin() OR nullif(btrim(coalesce(NEW.transaction_id,'')),'') IS NULL
  THEN RETURN NEW; END IF;
  SELECT t.received_date INTO v_received FROM public.bb_verified_bank_transactions t
   WHERE upper(btrim(t.transaction_id))=upper(btrim(NEW.transaction_id));
  IF NOT FOUND THEN RETURN NEW; END IF; -- manual unregistered bank IDs already blocked for staff
  SELECT i.invoice_date INTO v_sale FROM public.invoices i WHERE i.invoice_id=NEW.invoice_id;
  IF v_sale IS NULL OR v_received IS NULL
    THEN RAISE EXCEPTION 'Invoice bank date guard requires recorded sale and bank receipt dates'; END IF;
  IF v_received<v_sale THEN
    RAISE EXCEPTION 'Staff cannot use bank receipt dated % for invoice sale dated %. Ask Admin to approve older bank balance use',
      to_char(v_received,'DD-Mon-YYYY'),to_char(v_sale,'DD-Mon-YYYY');
  END IF;
  RETURN NEW;
END;
$func$;
DROP TRIGGER IF EXISTS bb_invoice_received_date_guard_v1 ON public.payments;
CREATE TRIGGER bb_invoice_received_date_guard_v1 BEFORE INSERT ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.bb_invoice_bank_received_date_guard_v1();

-- Existing review remains the ONE approval entry point.
CREATE OR REPLACE FUNCTION public.bb_ar_clear_request(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_r public.ar_payment_requests%rowtype;
  v_a public.ar_request_allocations%rowtype;
  v_inv public.invoices%rowtype;
  v_first public.invoices%rowtype;
  v_count int:=0; v_total numeric:=0; v_idx int:=0;
  v_method text:=case when lower(trim(coalesce(p_payload->>'paymentMethod','')))='bank' then 'Bank' when lower(trim(coalesce(p_payload->>'paymentMethod','')))='cash' then 'Cash' else '' end;
  v_bank text:=nullif(trim(coalesce(p_payload->>'bankPayment','')),'');
  v_tx text:=nullif(trim(coalesce(p_payload->>'transactionId','')),'');
  v_ref text:=nullif(trim(coalesce(p_payload->>'bankReference','')),'');
  v_cash_usd numeric:=greatest(coalesce(nullif(p_payload->>'physicalCashUSD','')::numeric,0),0);
  v_cash_khr numeric:=greatest(coalesce(nullif(p_payload->>'physicalCashKHR','')::numeric,0),0);
  v_payment_rate numeric:=greatest(coalesce(nullif(p_payload->>'exchangeRate','')::numeric,0),0);
  v_rate numeric; v_actual numeric;
  v_payment_id text; v_actor text:=public.bb_actor_name(); v_staff_id text:=public.bb_actor_staff_id();
  v_vault_id text; v_usd_eq numeric:=0; v_share numeric; v_invoice_list text;
begin
  if not public.bb_has_module_access('accounts_receivable','approve') then raise exception 'Accounts Receivable approval access denied'; end if;
  select * into v_r from public.ar_payment_requests where lower(request_id)=lower(trim(coalesce(p_payload->>'requestId',''))) for update;
  if not found then raise exception 'Request was not found'; end if;
  if lower(coalesce(v_r.request_type,''))='bank assistant' then
    return public.bb_ar_bank_assistant_clear_v1(p_payload);
  end if;
  if lower(coalesce(v_r.status,''))<>'processing' then raise exception 'Request is no longer Processing'; end if;
  if v_method='' then raise exception 'Choose final Payment Method'; end if;

  for v_a in select * from public.ar_request_allocations where request_id=v_r.request_id order by request_allocation_id loop
    select * into v_inv from public.invoices where invoice_id=v_a.invoice_id for update;
    if not found then raise exception 'Invoice % was not found',v_a.invoice_no_snapshot; end if;
    if v_a.requested_amount>v_inv.outstanding+0.000001 then raise exception 'Invoice % outstanding changed; review the request again',v_inv.invoice_no; end if;
    if not public.bb_is_admin() and not public.bb_has_location_access(v_inv.location_code) then raise exception 'Location access denied for invoice %',v_inv.invoice_no; end if;
    if v_count=0 then v_first:=v_inv; end if;
    v_count:=v_count+1; v_total:=v_total+v_a.requested_amount;
  end loop;
  if v_count=0 then raise exception 'Request has no invoice allocations'; end if;

  if v_method='Bank' then
    if v_bank is null then raise exception 'Bank Name is required'; end if;
    if v_tx is null then raise exception 'Transaction ID is required'; end if;
  else
    if v_cash_usd<=0 and v_cash_khr<=0 then raise exception 'Enter physical cash received'; end if;
    v_rate:=v_payment_rate;
    if upper(v_r.currency)='USD' then
      if v_cash_khr>0 and v_rate<=0 then raise exception 'Payment Exchange Rate is required for KHR cash'; end if;
      v_actual:=v_cash_usd+case when v_cash_khr>0 then v_cash_khr/v_rate else 0 end;
      if abs(v_actual-v_total)>0.05 then raise exception 'Physical cash does not match requested total'; end if;
    else
      if v_cash_usd>0 and v_rate<=0 then raise exception 'Payment Exchange Rate is required for USD cash'; end if;
      v_actual:=v_cash_khr+case when v_cash_usd>0 then v_cash_usd*v_rate else 0 end;
      if abs(v_actual-v_total)>1 then raise exception 'Physical cash does not match requested total'; end if;
    end if;
  end if;

  if v_payment_rate<=0 then v_payment_rate:=coalesce(v_first.exchange_rate,1); end if;

  select string_agg(a.invoice_no_snapshot,', ' order by a.request_allocation_id) into v_invoice_list from public.ar_request_allocations a where a.request_id=v_r.request_id;
  v_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
  insert into public.payments(
    payment_id,invoice_id,invoice_no_snapshot,payment_date,customer_id,customer_name_snapshot,location_code,salesperson_staff_id,
    salesperson_name_snapshot,payment_method,bank_payment,bank_reference,currency,exchange_rate,amount,physical_cash_usd,
    physical_cash_khr,note,transaction_id,entered_by_staff_id,entered_by_name_snapshot,approved_by_name_snapshot,payment_source,
    entered_by_user_id,approved_by_user_id
  ) values (
    v_payment_id,case when v_count=1 then v_first.invoice_id else null end,v_invoice_list,coalesce(v_r.request_date,current_date),
    v_r.customer_id,v_r.customer_name_snapshot,case when v_count=1 then v_first.location_code else null end,
    v_r.requested_by_staff_id,v_r.requested_by_name_snapshot,v_method,case when v_method='Bank' then v_bank else null end,
    case when v_method='Bank' then v_ref else null end,v_r.currency,v_payment_rate,v_total,
    case when v_method='Cash' then v_cash_usd else 0 end,case when v_method='Cash' then v_cash_khr else 0 end,
    v_r.note,case when v_method='Bank' then v_tx else null end,v_staff_id,v_actor,v_actor,'Receivable',auth.uid(),auth.uid()
  );

  for v_a in select * from public.ar_request_allocations where request_id=v_r.request_id order by request_allocation_id loop
    select * into v_inv from public.invoices where invoice_id=v_a.invoice_id;
    v_idx:=v_idx+1;
    insert into public.payment_allocations(allocation_id,payment_id,invoice_id,invoice_no_snapshot,applied_amount,currency)
    values(v_payment_id||'-'||lpad(v_idx::text,2,'0'),v_payment_id,v_inv.invoice_id,v_inv.invoice_no,v_a.requested_amount,v_inv.currency);

    if v_method='Cash' then
      v_share:=case when v_total>0 then v_a.requested_amount/v_total else 0 end;
      insert into public.daily_receivable_cash_collections(
        collection_line_id,payment_id,receive_date,invoice_id,invoice_no_snapshot,invoice_date,customer_id,customer_name_snapshot,
        salesperson_staff_id,salesman_name_snapshot,location_code,payment_method,invoice_currency,receivable_applied,cash_received_usd,
        cash_received_khr,approved_by_name_snapshot,approved_by_user_id
      ) values (
        v_payment_id||'-'||lpad(v_idx::text,2,'0'),v_payment_id,coalesce(v_r.request_date,current_date),v_inv.invoice_id,v_inv.invoice_no,
        v_inv.invoice_date,v_inv.customer_id,v_inv.customer_name_snapshot,v_inv.salesperson_staff_id,v_inv.salesperson_name_snapshot,
        v_inv.location_code,'Cash',v_inv.currency,v_a.requested_amount,v_cash_usd*v_share,v_cash_khr*v_share,v_actor,auth.uid()
      );
    end if;

    update public.invoices set amount_paid=least(grand_total,amount_paid+v_a.requested_amount),outstanding=greatest(grand_total-least(grand_total,amount_paid+v_a.requested_amount),0),credit_amount=greatest(grand_total-least(grand_total,amount_paid+v_a.requested_amount),0),status=case when greatest(grand_total-least(grand_total,amount_paid+v_a.requested_amount),0)<=0 then 'Paid' else 'Processing' end where invoice_id=v_inv.invoice_id;
  end loop;

  if v_method='Cash' then
    v_vault_id:=public.bb_next_prefixed_id('public.cash_vault_ledger'::regclass,'vault_entry_id','VLT',6);
    if v_payment_rate>0 then v_usd_eq:=v_cash_usd+(v_cash_khr/v_payment_rate); end if;
    insert into public.cash_vault_ledger(vault_entry_id,entry_at,entry_type,source,salesperson_staff_id,salesperson_name_snapshot,usd_amount,khr_amount,exchange_rate,usd_equivalent,note,admin_name_snapshot,admin_user_id)
    values(v_vault_id,now(),'IN','Receivable Cash',v_r.requested_by_staff_id,v_r.requested_by_name_snapshot,v_cash_usd,v_cash_khr,v_payment_rate,v_usd_eq,'Receivable cash collection',v_actor,auth.uid());
  end if;

  update public.ar_payment_requests set status='Cleared',reviewed_by_name_snapshot=v_actor,reviewed_by_user_id=auth.uid(),reviewed_at=now(),payment_id=v_payment_id,payment_method=v_method,bank_payment=case when v_method='Bank' then v_bank else null end,bank_reference=case when v_method='Bank' then v_ref else null end,transaction_id=case when v_method='Bank' then v_tx else null end,reject_reason=null where request_id=v_r.request_id;

  return jsonb_build_object('success',true,'requestId',v_r.request_id,'paymentId',v_payment_id,'paymentMethod',v_method,'approvedBy',v_actor,'invoiceCount',v_count,'totalAmount',v_total,'currency',v_r.currency,'exchangeRate',v_payment_rate);
end;
$function$
;

REVOKE ALL ON FUNCTION public.bb_ar_bank_assistant_list_v1() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bb_ar_bank_assistant_submit_v1(jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bb_ar_bank_assistant_clear_v1(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_ar_bank_assistant_list_v1() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bb_ar_bank_assistant_submit_v1(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bb_ar_bank_assistant_clear_v1(jsonb) TO authenticated;
