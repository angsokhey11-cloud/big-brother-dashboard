-- BIG BROTHER: one registered bank transfer can clear A/R invoices from several APPROVED outlets.
-- Requires the guarded shared-bank-receipt migration installed before this file.
-- This migration never posts real payments; it only installs the new atomic clearing path.
-- Admin only for multi-outlet pilot; existing single-customer and Cash paths unchanged.

CREATE OR REPLACE FUNCTION public.bb_ar_receive_batch_registered_outlets_v1(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
 v_tx text:=upper(btrim(coalesce(p_payload->>'transactionId','')));
 v_bank text:=nullif(btrim(coalesce(p_payload->>'bankPayment','')),'');
 v_ids text[];
 v_inv public.invoices%ROWTYPE;
 v_reg public.bb_verified_bank_transactions%ROWTYPE;
 v_id text;
 v_date date:=coalesce(nullif(p_payload->>'paymentDate','')::date,(now() at time zone 'Asia/Phnom_Penh')::date);
 v_currency text;
 v_count int:=0;
 v_customer_count int:=0;
 v_total numeric:=0;
 v_global_remaining numeric;
 v_paid numeric;
 v_outstanding numeric;
 v_paid_ids jsonb:='[]'::jsonb;
 v_payment_id text;
 v_first_payment_id text;
 v_actor text:=public.bb_actor_name();
 v_staff_id text:=public.bb_actor_staff_id();
 v_require record;
 v_bank_rate numeric;
BEGIN
 IF NOT public.bb_is_admin() OR auth.uid() IS NULL
   OR NOT public.bb_has_module_access('accounts_receivable','edit') THEN
   RAISE EXCEPTION 'Admin A/R approval required for multi-outlet bank clearing';
 END IF;
 IF lower(trim(coalesce(p_payload->>'paymentMethod',''))) <> 'bank'
   OR v_bank IS NULL OR length(v_tx)<4 OR length(v_tx)>160
 THEN RAISE EXCEPTION 'Choose Bank, actual receiving bank, and registered transaction ID';END IF;
 IF v_date>(now() at time zone 'Asia/Phnom_Penh')::date OR v_date<DATE '2000-01-01'
 THEN RAISE EXCEPTION 'Payment date outside allowed range';END IF;
 IF jsonb_typeof(p_payload->'invoiceIds') IS DISTINCT FROM 'array'
   OR jsonb_array_length(p_payload->'invoiceIds') NOT BETWEEN 2 AND 60
 THEN RAISE EXCEPTION 'Select 2 to 60 A/R invoices';END IF;
 SELECT array_agg(DISTINCT btrim(value) ORDER BY btrim(value)) INTO v_ids
 FROM jsonb_array_elements_text(p_payload->'invoiceIds');
 IF cardinality(v_ids)<>jsonb_array_length(p_payload->'invoiceIds')
   OR EXISTS(SELECT 1 FROM unnest(v_ids) x WHERE x='') THEN
   RAISE EXCEPTION 'Duplicate or missing invoice ID in bank batch';END IF;
 -- Same lock as the existing bank wallet payment trigger and outlet-share editor.
 PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tx));
 SELECT * INTO v_reg FROM public.bb_verified_bank_transactions
 WHERE upper(btrim(transaction_id))=v_tx FOR UPDATE;
 IF NOT FOUND OR v_reg.status<>'AVAILABLE' THEN
   RAISE EXCEPTION 'Select an available Admin-registered bank receipt';END IF;
 IF v_reg.bank_name IS NOT NULL AND lower(btrim(v_reg.bank_name))<>lower(v_bank)
 THEN RAISE EXCEPTION 'Selected receiving bank does not match verified bank receipt';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=v_reg.transaction_id)
 THEN RAISE EXCEPTION 'This bank receipt is not allocated between outlets. Open Bank History → Allocate Outlets first';END IF;
 v_bank_rate:=coalesce(v_reg.approved_exchange_rate,1);
 -- Sorted invoice locking prevents two simultaneous batch clearances from silently overlapping.
 FOREACH v_id IN ARRAY v_ids LOOP
  SELECT * INTO v_inv FROM public.invoices i
  WHERE i.invoice_id=v_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invoice % does not exist',v_id;END IF;
  IF coalesce(v_inv.outstanding,0)<=0 THEN
    RAISE EXCEPTION 'Invoice % has already been cleared',v_inv.invoice_no;END IF;
  IF v_inv.customer_id IS NULL OR v_inv.customer_id=''
     OR NOT EXISTS(SELECT 1 FROM public.customers c
       WHERE c.customer_id=v_inv.customer_id AND coalesce(c.active,true))
  THEN RAISE EXCEPTION 'Invoice % has no active customer',v_inv.invoice_no;END IF;
  IF EXISTS(SELECT 1 FROM public.ar_request_allocations a
    JOIN public.ar_payment_requests r ON r.request_id=a.request_id
    WHERE a.invoice_id=v_inv.invoice_id AND lower(coalesce(r.status,''))='processing')
  THEN RAISE EXCEPTION 'Invoice % has a Processing A/R request',v_inv.invoice_no;END IF;
  IF v_currency IS NULL THEN v_currency:=upper(coalesce(v_inv.currency,'USD'));END IF;
  IF upper(coalesce(v_inv.currency,'USD'))<>v_currency
    OR v_currency NOT IN ('USD','KHR') THEN
    RAISE EXCEPTION 'Multi-outlet bank batch invoices must use the same currency';END IF;
  IF v_reg.currency<>v_currency THEN
    RAISE EXCEPTION 'Multi-outlet A/R pilot requires the registered bank receipt and invoices to use the same currency';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s
     WHERE s.transaction_id=v_reg.transaction_id AND s.customer_id=v_inv.customer_id)
  THEN RAISE EXCEPTION 'Outlet % is not allocated any of the selected bank receipt',v_inv.customer_name_snapshot;END IF;
  v_total:=v_total+v_inv.outstanding;
  v_count:=v_count+1;
 END LOOP;
 SELECT count(DISTINCT i.customer_id) INTO v_customer_count
 FROM public.invoices i WHERE i.invoice_id=ANY(v_ids);
 IF v_customer_count<2 THEN
   RAISE EXCEPTION 'Multi-outlet clearing requires invoices from two or more customers';END IF;
 -- Check each outlet's share and aggregate receipt before posting any payment.
 FOR v_require IN
 SELECT i.customer_id,sum(i.outstanding) AS needed
 FROM public.invoices i WHERE i.invoice_id=ANY(v_ids)
 GROUP BY i.customer_id
 LOOP
  IF coalesce((SELECT b.remaining_amount FROM public.bb_bank_balance_snapshot b
    WHERE b.transaction_id=v_reg.transaction_id AND b.customer_id=v_require.customer_id
     AND b.status='AVAILABLE'),0)<v_require.needed THEN
    RAISE EXCEPTION 'Not enough allocated bank balance for outlet %; needs % %',
        v_require.customer_id,v_require.needed,v_currency;
  END IF;
 END LOOP;
 SELECT v_reg.amount-coalesce(sum(a.applied_bank_amount),0)
   INTO v_global_remaining
 FROM public.bb_bank_balance_allocations a
 WHERE a.transaction_id=v_reg.transaction_id AND a.reversed_at IS NULL;
 IF v_global_remaining<v_total THEN RAISE EXCEPTION 'One bank receipt has insufficient remaining balance';END IF;
 -- ONE physical bank receipt, but ONE customer-owned payment per invoice.
 -- The existing private bank guard atomically debits the correct customer share.
 FOREACH v_id IN ARRAY v_ids LOOP
  SELECT * INTO v_inv FROM public.invoices i WHERE i.invoice_id=v_id;
  v_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
  IF v_first_payment_id IS NULL THEN v_first_payment_id:=v_payment_id;END IF;
  INSERT INTO public.payments(
   payment_id,invoice_id,invoice_no_snapshot,payment_date,customer_id,
   customer_name_snapshot,location_code,salesperson_staff_id,salesperson_name_snapshot,
   payment_method,bank_payment,bank_reference,currency,exchange_rate,amount,
   physical_cash_usd,physical_cash_khr,note,transaction_id,
   entered_by_staff_id,entered_by_name_snapshot,approved_by_name_snapshot,
   payment_source,entered_by_user_id,approved_by_user_id
  ) VALUES(
   v_payment_id,v_inv.invoice_id,v_inv.invoice_no,v_date,v_inv.customer_id,
   v_inv.customer_name_snapshot,v_inv.location_code,v_inv.salesperson_staff_id,v_inv.salesperson_name_snapshot,
   'Bank',v_bank,nullif(trim(coalesce(p_payload->>'bankReference','')),''),
   v_inv.currency,case when v_reg.currency=v_inv.currency then coalesce(v_inv.exchange_rate,1) else v_bank_rate end,
   v_inv.outstanding,0,0,
   'Combined payer bank receipt, allocated by outlet. '||coalesce(p_payload->>'note',''),
   v_reg.transaction_id,v_staff_id,v_actor,v_actor,'Receivable',auth.uid(),auth.uid()
  );
  INSERT INTO public.payment_allocations(
    allocation_id,payment_id,invoice_id,invoice_no_snapshot,applied_amount,currency
  ) VALUES(v_payment_id||'-01',v_payment_id,v_inv.invoice_id,v_inv.invoice_no,v_inv.outstanding,v_inv.currency);
  UPDATE public.invoices SET amount_paid=grand_total,outstanding=0,credit_amount=0,status='Paid'
  WHERE invoice_id=v_inv.invoice_id;
  v_paid_ids:=v_paid_ids||jsonb_build_array(v_payment_id);
 END LOOP;
 IF (SELECT count(*) FROM public.bb_bank_balance_allocations a
     WHERE a.payment_id IN (SELECT value FROM jsonb_array_elements_text(v_paid_ids))
       AND a.transaction_id=v_reg.transaction_id AND a.reversed_at IS NULL)<>v_count
 THEN RAISE EXCEPTION 'Bank payment allocations did not match the selected A/R invoices';END IF;
 RETURN jsonb_build_object('success',true,'paymentId',v_first_payment_id,
   'paymentIds',v_paid_ids,'approvedBy',v_actor,'invoiceCount',v_count,
   'totalAmount',v_total,'currency',v_currency,'customerCount',v_customer_count,
   'multiOutletBank',true,'bankTransactionId',v_reg.transaction_id);
END $fn$;
REVOKE ALL ON FUNCTION public.bb_ar_receive_batch_registered_outlets_v1(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_ar_receive_batch_registered_outlets_v1(jsonb) TO authenticated;
