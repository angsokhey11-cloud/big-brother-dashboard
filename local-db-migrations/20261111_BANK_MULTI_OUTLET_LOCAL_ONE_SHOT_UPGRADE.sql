-- BIG BROTHER LOCAL BRAIN | 11-Nov-2026
-- ONE-TIME ATOMIC multi-outlet bank wallet schema upgrade.
-- STOP: before Cloud -> Local refresh, apply using existing local SQL upgrade process.
-- Existing 08C merge and Local-only historical data are NOT changed here.
-- Does NOT register or allocate any real bank receipt.
\set ON_ERROR_STOP on
BEGIN;

-- BIG BROTHER: approved multi-outlet shares for ONE physical bank receipt.
-- Before running locally: snapshot/backup. Apply before syncing new Cloud table.
-- Existing single-customer bank transactions are unchanged; no data backfill.
CREATE TABLE IF NOT EXISTS public.bb_bank_outlet_shares (
 transaction_id text NOT NULL REFERENCES public.bb_verified_bank_transactions(transaction_id) ON DELETE CASCADE,
 customer_id text NOT NULL REFERENCES public.customers(customer_id) ON DELETE RESTRICT,
 allocated_amount numeric(20,4) NOT NULL CHECK(allocated_amount>0),
 approved_by uuid NOT NULL,
 approved_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(transaction_id,customer_id)
);
CREATE INDEX IF NOT EXISTS bb_bank_outlet_shares_customer_idx ON public.bb_bank_outlet_shares(customer_id);
ALTER TABLE public.bb_bank_outlet_shares ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_bank_outlet_shares FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.bb_bank_payer_key(p_name text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $fn$ SELECT lower(regexp_replace(translate(trim(coalesce(p_name,'')), '.,-_', '    '), '\s+', ' ', 'g')) $fn$;
REVOKE ALL ON FUNCTION public.bb_bank_payer_key(text) FROM PUBLIC,anon,authenticated;

-- Preserve the existing public view interface and column order.
-- One row per legacy receipt, one row per outlet on explicitly split receipts.
CREATE OR REPLACE VIEW public.bb_bank_balance_snapshot AS
WITH entitlements AS (
 SELECT t.transaction_id,t.customer_id,t.amount AS share_amount
 FROM public.bb_verified_bank_transactions t
 WHERE NOT EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=t.transaction_id)
 UNION ALL
 SELECT s.transaction_id,s.customer_id,s.allocated_amount FROM public.bb_bank_outlet_shares s
), spent AS (
 SELECT a.transaction_id,coalesce(p.customer_id,t.customer_id) AS customer_id,
        coalesce(sum(a.applied_bank_amount),0)::numeric AS spent
 FROM public.bb_bank_balance_allocations a
 JOIN public.bb_verified_bank_transactions t ON t.transaction_id=a.transaction_id
 LEFT JOIN public.payments p ON p.payment_id=a.payment_id
 WHERE a.reversed_at IS NULL
 GROUP BY a.transaction_id,coalesce(p.customer_id,t.customer_id)
)
SELECT t.transaction_id,e.customer_id,t.currency,t.invoice_currency,t.approved_exchange_rate,
 t.received_date,e.share_amount::numeric(18,4) AS original_amount,
 CASE WHEN t.status='USED' THEN e.share_amount
      WHEN t.status='CANCELLED' THEN 0::numeric ELSE coalesce(s.spent,0) END AS used_amount,
 CASE WHEN t.status='AVAILABLE' THEN greatest(0::numeric,e.share_amount-coalesce(s.spent,0))
      ELSE 0::numeric END AS remaining_amount,
 t.status
FROM entitlements e
JOIN public.bb_verified_bank_transactions t ON t.transaction_id=e.transaction_id
LEFT JOIN spent s ON s.transaction_id=e.transaction_id AND s.customer_id=e.customer_id;

CREATE OR REPLACE FUNCTION public.bb_bank_outlet_share_list_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v jsonb;
BEGIN
 IF NOT public.bb_is_admin() THEN RAISE EXCEPTION 'Admin required'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('transactionId',s.transaction_id,'customerId',s.customer_id,
  'customerName',c.customer_name,'location',c.location_code,'currency',t.currency,'amount',s.allocated_amount,
  'used',coalesce(b.used_amount,0),'remaining',coalesce(b.remaining_amount,0))
  ORDER BY s.transaction_id,c.customer_name,s.customer_id),'[]'::jsonb) INTO v
 FROM public.bb_bank_outlet_shares s
 JOIN public.customers c ON c.customer_id=s.customer_id
 LEFT JOIN public.bb_bank_balance_snapshot b ON b.transaction_id=s.transaction_id AND b.customer_id=s.customer_id
 JOIN public.bb_verified_bank_transactions t ON t.transaction_id=s.transaction_id
 WHERE t.status IN ('AVAILABLE','USED');
 RETURN v;
END $fn$;
REVOKE ALL ON FUNCTION public.bb_bank_outlet_share_list_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_bank_outlet_share_list_v1() TO authenticated;

CREATE OR REPLACE FUNCTION public.bb_bank_outlet_share_info_v1(p_transaction_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE t public.bb_verified_bank_transactions%ROWTYPE;
 v_payer text;v_key text;v_candidates jsonb;v_existing jsonb;v_spent numeric;v_count integer;
BEGIN
 IF NOT public.bb_is_admin() THEN RAISE EXCEPTION 'Admin required'; END IF;
 SELECT * INTO t FROM public.bb_verified_bank_transactions
 WHERE transaction_id=upper(trim(coalesce(p_transaction_id,'')));
 IF NOT FOUND THEN RAISE EXCEPTION 'Bank receipt not found'; END IF;
 v_payer:=coalesce(nullif(trim(t.payer_name),''),
   (select b.account_holder_name from public.bb_customer_bank_identities b where b.identity_id=t.payer_identity_id));
 v_key:=public.bb_bank_payer_key(v_payer);
 SELECT coalesce(jsonb_agg(jsonb_build_object('customerId',c.customer_id,'name',c.customer_name,
 'location',c.location_code) ORDER BY c.customer_name,c.customer_id),'[]'::jsonb) INTO v_candidates
 FROM public.customers c
 WHERE c.active=true AND (
   c.customer_id=t.customer_id OR
   (v_key<>'' AND exists (
      select 1 from public.bb_customer_bank_identities b where b.customer_id=c.customer_id AND b.active
        AND (public.bb_bank_payer_key(b.account_holder_name)=v_key
        OR exists(select 1 from unnest(coalesce(b.alternative_names,'{}'::text[])) a
                  where public.bb_bank_payer_key(a)=v_key))
   ))
 );
 SELECT coalesce(jsonb_agg(jsonb_build_object('customerId',s.customer_id,
   'amount',s.allocated_amount) ORDER BY s.customer_id),'[]'::jsonb),count(*)
 INTO v_existing,v_count
 FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=t.transaction_id;
 SELECT coalesce(sum(a.applied_bank_amount),0) INTO v_spent
 FROM public.bb_bank_balance_allocations a WHERE a.transaction_id=t.transaction_id AND a.reversed_at IS NULL;
 RETURN jsonb_build_object('success',true,'transactionId',t.transaction_id,
  'anchorCustomerId',t.customer_id,'amount',t.amount,'currency',t.currency,'bankName',t.bank_name,
  'receivedDate',t.received_date,'payerName',v_payer,'eligible',v_candidates,
  'allocations',v_existing,'isSplit',v_count>0,
  'canAllocate',t.status='AVAILABLE' AND v_spent=0,'usedAmount',v_spent,'status',t.status);
END $fn$;
REVOKE ALL ON FUNCTION public.bb_bank_outlet_share_info_v1(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_bank_outlet_share_info_v1(text) TO authenticated;

-- Can create or revise a split only while receipt is completely unused.
-- Changes are atomic; each revision records before/after data in system audit.
CREATE OR REPLACE FUNCTION public.bb_bank_outlet_share_save_v1(p_transaction_id text,p_shares jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE t public.bb_verified_bank_transactions%ROWTYPE;
 v_tid text:=upper(trim(coalesce(p_transaction_id,'')));
 v_e jsonb;v_id text;v_amt numeric;v_total numeric:=0;
 v_seen text[]:='{}';v_clean jsonb:='[]'::jsonb;v_before jsonb;v_payer text;v_key text;
 v_spent numeric;v_n integer;v_revision boolean;
BEGIN
 IF NOT public.bb_is_admin() OR auth.uid() IS NULL THEN RAISE EXCEPTION 'Admin required'; END IF;
 IF jsonb_typeof(p_shares) IS DISTINCT FROM 'array' OR jsonb_array_length(p_shares) NOT BETWEEN 2 AND 30
 THEN RAISE EXCEPTION 'Select 2 to 30 outlet shares'; END IF;
 IF length(v_tid)<4 OR length(v_tid)>160 THEN RAISE EXCEPTION 'Invalid bank transaction ID';END IF;
 PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tid));
 SELECT * INTO t FROM public.bb_verified_bank_transactions
 WHERE transaction_id=v_tid FOR UPDATE;
 IF NOT FOUND OR t.status<>'AVAILABLE' THEN
  RAISE EXCEPTION 'Only available registered bank receipts can be allocated'; END IF;
 SELECT coalesce(sum(a.applied_bank_amount),0) INTO v_spent
 FROM public.bb_bank_balance_allocations a WHERE a.transaction_id=v_tid AND a.reversed_at IS NULL;
 IF v_spent<>0 OR t.used_payment_id IS NOT NULL THEN
  RAISE EXCEPTION 'This receipt has already been used; outlet allocation is locked'; END IF;
 v_payer:=coalesce(nullif(trim(t.payer_name),''),
  (select b.account_holder_name FROM public.bb_customer_bank_identities b where b.identity_id=t.payer_identity_id));
 v_key:=public.bb_bank_payer_key(v_payer);
 IF v_key='' THEN RAISE EXCEPTION 'Payer name must be verified before sharing between outlets';END IF;
 FOR v_e IN SELECT value FROM jsonb_array_elements(p_shares) LOOP
  v_id:=trim(coalesce(v_e->>'customerId',''));
  IF v_id='' OR v_id=ANY(v_seen) OR
     coalesce(v_e->>'amount','') !~ '^[0-9]+([.][0-9]{1,4})?$'
  THEN RAISE EXCEPTION 'Duplicate outlet or invalid share amount';END IF;
  v_amt:=(v_e->>'amount')::numeric;
  IF v_amt<=0 OR v_amt>t.amount OR
     v_amt<>trunc(v_amt,case when t.currency='KHR' then 0 else 2 end)
  THEN RAISE EXCEPTION 'Share amount must be positive, in bank-currency precision';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.customer_id=v_id AND c.active)
  THEN RAISE EXCEPTION 'Inactive or unknown outlet: %',v_id; END IF;
  IF v_id<>t.customer_id AND NOT EXISTS(
     SELECT 1 FROM public.bb_customer_bank_identities b
     WHERE b.customer_id=v_id AND b.active
       AND (public.bb_bank_payer_key(b.account_holder_name)=v_key OR
            EXISTS(SELECT 1 FROM unnest(coalesce(b.alternative_names,'{}'::text[])) al
                   WHERE public.bb_bank_payer_key(al)=v_key))
  ) THEN RAISE EXCEPTION 'Outlet % is not linked to this payer in Bank Directory',v_id;END IF;
  v_total:=v_total+v_amt;
  v_seen:=array_append(v_seen,v_id);
  v_clean:=v_clean||jsonb_build_array(jsonb_build_object('customerId',v_id,'amount',v_amt));
 END LOOP;
 IF v_total<>t.amount THEN
   RAISE EXCEPTION 'Outlet shares total % %, but bank received % %',
     v_total,t.currency,t.amount,t.currency;END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('customerId',s.customer_id,
  'amount',s.allocated_amount) ORDER BY s.customer_id),'[]'::jsonb)
 INTO v_before FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=v_tid;
 IF v_before=(
   SELECT coalesce(jsonb_agg(value ORDER BY value->>'customerId'),'[]'::jsonb)
   FROM jsonb_array_elements(v_clean)
 ) THEN RETURN jsonb_build_object('success',true,'already',true,'transactionId',v_tid,'outlets',array_length(v_seen,1)); END IF;
 v_revision:=jsonb_array_length(v_before)>0;
 DELETE FROM public.bb_bank_outlet_shares WHERE transaction_id=v_tid;
 FOR v_e IN SELECT value FROM jsonb_array_elements(v_clean) LOOP
  INSERT INTO public.bb_bank_outlet_shares(transaction_id,customer_id,allocated_amount,approved_by)
  VALUES(v_tid,v_e->>'customerId',(v_e->>'amount')::numeric,auth.uid());
 END LOOP;
 INSERT INTO public.system_activity_log(actor_user_id,actor_staff_id,actor_name,module_key,
  action,entity_type,entity_id,summary,metadata)
 VALUES(auth.uid(),public.bb_actor_staff_id(),coalesce(nullif(public.bb_actor_name(),''),'Admin'),
   'admin_work',case when v_revision then 'BANK_OUTLET_SPLIT_EDIT' else 'BANK_OUTLET_SPLIT_CREATE' end,
   'bank_transaction',v_tid,'Bank receipt allocated to '||array_length(v_seen,1)||' outlets',
   jsonb_build_object('before',v_before,'after',v_clean,'bankAmount',t.amount,
     'bankCurrency',t.currency,'payer',v_payer));
 RETURN jsonb_build_object('success',true,'already',false,'transactionId',v_tid,
   'outlets',array_length(v_seen,1),'amount',t.amount,'currency',t.currency);
END $fn$;
REVOKE ALL ON FUNCTION public.bb_bank_outlet_share_save_v1(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_bank_outlet_share_save_v1(text,jsonb) TO authenticated;


-- BIG BROTHER multi-outlet bank receipts. Run AFTER 20261111_bank_receipt_multi_outlet_core_v1.sql.
-- Functions below copy live definitions and narrowly replace per-customer wallet permissions.
-- Existing single-customer receipts, staff authorization and FX checks are preserved.

CREATE OR REPLACE FUNCTION private.bb_bank_guard_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 tid text:=upper(trim(coalesce(new.transaction_id,'')));
 reg public.bb_verified_bank_transactions%rowtype;
 inv text;
 rate numeric;
 debit numeric;
 spent numeric;
 remains numeric;
 tolerance numeric;
 outlet_limit numeric;
 outlet_spent numeric;
 source text:=upper(trim(coalesce(new.payment_source,'')));
begin
 if tid='' then
   if lower(trim(coalesce(new.payment_method,'')))='bank' then raise exception 'Bank Transaction ID required'; end if;
   return new;
 end if;
 perform pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||tid));
 -- Nonbank references must stay unique too, even without the old index.
 if lower(trim(coalesce(new.payment_method,'')))<>'bank' then
   if exists(select 1 from public.payments p where upper(trim(coalesce(p.transaction_id,'')))=tid)
   then raise exception 'Transaction ID already exists'; end if;
   return new;
 end if;
 if exists(select 1 from public.company_deposits where upper(trim(coalesce(collection_transaction_id,'')))=tid)
 then raise exception 'Bank Transaction ID already used by company deposit'; end if;
 select * into reg from public.bb_verified_bank_transactions where upper(trim(transaction_id))=tid for update;
 if not found then
  -- Only a registered, AVAILABLE wallet may reuse its real transfer ID.
  -- For unregistered/manual IDs keep the original strict uniqueness rule.
  if exists(select 1 from public.payments p where upper(trim(coalesce(p.transaction_id,'')))=tid)
  then raise exception 'Transaction ID already exists'; end if;
  if not public.bb_is_admin() then
   raise exception 'Manual Bank Transaction ID is Admin-only. Staff must choose an Admin-registered bank payment.';
  end if;
  return new;
 end if;
 if source not in ('INVOICE','RECEIVABLE') then
  raise exception 'Verified customer bank balance must be used from Invoice or A/R collection';
 end if;
 if reg.status<>'AVAILABLE' then raise exception 'Verified bank balance already fully used or cancelled'; end if;

 if nullif(new.customer_id,'') is null then
   raise exception 'Bank payment customer is required';
 end if;
 if exists(select 1 from public.bb_bank_outlet_shares s where s.transaction_id=reg.transaction_id) then
   if not exists(select 1 from public.bb_bank_outlet_shares s
       where s.transaction_id=reg.transaction_id and s.customer_id=new.customer_id) then
     raise exception 'Customer has no approved share of this bank receipt';
   end if;
 elsif new.customer_id<>reg.customer_id then
   raise exception 'Verified bank balance belongs to another customer';
 end if;
 inv:=upper(trim(coalesce(new.currency,'')));
 if inv not in ('USD','KHR') then raise exception 'Unsupported invoice currency'; end if;
 rate:=case when reg.currency=inv then 1
   when coalesce(reg.approved_exchange_rate,0)>1 then reg.approved_exchange_rate
   else new.exchange_rate end;
 if reg.currency<>inv then
  if rate is null or rate<=1 or abs(coalesce(new.exchange_rate,0)-rate)>0.000001 then
   raise exception 'Payment exchange rate must match the approved or invoice exchange rate';
  end if;
 end if;
 if reg.bank_name is not null and lower(trim(coalesce(new.bank_payment,'')))<>lower(trim(reg.bank_name)) then
  raise exception 'Verified bank receiving bank does not match';
 end if;
 if coalesce(new.amount,0)<=0 then raise exception 'Bank balance usage amount must be positive'; end if;
 debit:=case when reg.currency=inv then new.amount
   when reg.currency='KHR' then new.amount*rate
   else new.amount/rate end;
 select coalesce(sum(a.applied_bank_amount),0) into spent
 from public.bb_bank_balance_allocations a where a.transaction_id=reg.transaction_id and a.reversed_at is null;
 remains:=reg.amount-spent;
 tolerance:=case when reg.currency='KHR' then 0.5 else 0.005 end;
 outlet_limit:=null;
 outlet_spent:=0;
 select s.allocated_amount INTO outlet_limit
 from public.bb_bank_outlet_shares s
 where s.transaction_id=reg.transaction_id AND s.customer_id=new.customer_id;
 if outlet_limit is not null then
   select coalesce(sum(a.applied_bank_amount),0) INTO outlet_spent
   from public.bb_bank_balance_allocations a
   join public.payments p on p.payment_id=a.payment_id
   where a.transaction_id=reg.transaction_id and p.customer_id=new.customer_id
     and a.reversed_at is null;
   if outlet_spent>=outlet_limit or debit>outlet_limit-outlet_spent+tolerance then
     raise exception 'Outlet bank balance insufficient: remaining % %',
       greatest(outlet_limit-outlet_spent,0),reg.currency;
   end if;
 end if;
 if remains<=0 or debit>remains+tolerance then
   raise exception 'Bank balance insufficient: remaining % %',greatest(remains,0),reg.currency;
 end if;
 debit:=least(debit,remains);
 if outlet_limit is not null THEN debit:=least(debit,outlet_limit-outlet_spent); END IF;
 insert into public.bb_bank_balance_allocations(transaction_id,payment_id,payment_source,
   applied_bank_amount,applied_invoice_amount,invoice_currency)
 values(reg.transaction_id,new.payment_id,case when source='INVOICE' then 'INVOICE' else 'AR' end,
   debit,new.amount,inv);
 new.actual_bank_amount:=debit;
 new.actual_bank_currency:=reg.currency;
 new.approved_bank_rate:=rate;
 if remains-debit<=tolerance then
  update public.bb_verified_bank_transactions set status='USED',
   used_payment_id=new.payment_id,used_at=now() where transaction_id=reg.transaction_id;
 end if;
 return new;
end $function$;


CREATE OR REPLACE FUNCTION public.bb_bank_customer_available_transactions(p_customer_id text)
 RETURNS TABLE(transaction_id text, amount numeric, currency text, invoice_currency text, approved_exchange_rate numeric, bank_name text, received_date date, equivalent_amount numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_location text;
begin
  if not public.bb_has_module_access('invoice_generator','create') then
    raise exception 'Invoice Generator access required';
  end if;

  if nullif(trim(coalesce(p_customer_id,'')),'') is null then
    return;
  end if;

  select c.location_code
  into v_location
  from public.customers c
  where c.customer_id=p_customer_id
    and coalesce(c.active,true)=true;

  if not found then return; end if;

  if not public.bb_is_admin()
     and not public.bb_has_location_access(coalesce(v_location,'')) then
    raise exception 'Customer location access denied';
  end if;

  return query
  select
    t.transaction_id,
    b.remaining_amount,
    t.currency,
    coalesce(t.invoice_currency,t.currency),
    coalesce(t.approved_exchange_rate,1),
    t.bank_name,
    t.received_date,
    case
      when t.currency=coalesce(t.invoice_currency,t.currency) then b.remaining_amount
      when t.currency='KHR' then b.remaining_amount/nullif(t.approved_exchange_rate,0)
      else b.remaining_amount*t.approved_exchange_rate
    end
  from public.bb_bank_balance_snapshot b
  join public.bb_verified_bank_transactions t on t.transaction_id=b.transaction_id
  where b.customer_id=p_customer_id
    and b.status='AVAILABLE' and b.remaining_amount>0
  order by t.received_date asc,t.created_at asc;
end
$function$;


CREATE OR REPLACE FUNCTION public.bb_bank_customer_has_available(p_customer_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
if not public.bb_has_module_access('invoice_generator','create') then raise exception 'Invoice Generator access required';end if;
if public.bb_is_admin() or nullif(trim(coalesce(p_customer_id,'')),'') is null then return false;end if;
return exists(select 1 from public.bb_bank_balance_snapshot b where b.customer_id=p_customer_id and b.status='AVAILABLE' and b.remaining_amount>0);
end $function$;


CREATE OR REPLACE FUNCTION public.bb_invoice_bank_bulk_sync()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_data jsonb;
begin
 if auth.uid() is null or not public.bb_has_module_access('invoice_generator','create') then
  raise exception 'Invoice Generator access required';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'customer_id',b.customer_id,'transaction_id',b.transaction_id,
 'original_amount',b.original_amount,'used_amount',b.used_amount,'remaining_amount',b.remaining_amount,
 'amount',b.remaining_amount,'currency',b.currency,'invoice_currency',coalesce(b.invoice_currency,b.currency),
 'approved_exchange_rate',b.approved_exchange_rate,'received_date',b.received_date,
 'equivalent_remaining',case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0) else b.remaining_amount*b.approved_exchange_rate end,
 'equivalent_amount',case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0) else b.remaining_amount*b.approved_exchange_rate end,
 'bank_name',coalesce(t.bank_name,'')
 )), '[]'::jsonb) into v_data
 from public.bb_bank_balance_snapshot b
 join public.customers c on c.customer_id=b.customer_id and coalesce(c.active,true)=true
 left join public.bb_verified_bank_transactions t on t.transaction_id=b.transaction_id
 where b.status='AVAILABLE' and b.remaining_amount>0
 and (public.bb_is_admin() or public.bb_has_location_access(coalesce(c.location_code,'')));
 return v_data;
end $function$;


CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_multi_bank_v1(p_invoice jsonb, p_payment jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := auth.uid();
  v_req uuid;
  v_existing public.bb_invoice_multi_bank_requests%rowtype;
  v_fingerprint text;
  v_location text := btrim(coalesce(p_invoice->>'locationCode',''));
  v_customer text := nullif(btrim(coalesce(p_invoice->>'customerId','')),'');
  v_currency text := upper(btrim(coalesce(p_invoice->>'currency','')));
  v_method text := btrim(coalesce(p_invoice->>'paymentMethod',''));
  v_sources jsonb := p_payment->'settlement_sources';
  v_item jsonb;
  v_source_id text;
  v_source public.bb_verified_bank_transactions%rowtype;
  v_amount numeric;
  v_total numeric := 0;
  v_count int;
  v_precision int;
  v_details jsonb := '[]'::jsonb;
  v_first_bank text;
  -- Older registered payments may have no saved receiving-bank name.
  -- Use the admin's explicit Payment Bank selection only for those rows.
  v_fallback_bank text := nullif(btrim(coalesce(p_invoice->>'paymentBank','')),'');
  v_ids text[];
  v_key text;
  v_invoice_result jsonb;
  v_invoice public.invoices%rowtype;
  v_payment_id text;
  v_payment_ids jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if v_actor is null then raise exception 'Sign-in required'; end if;
  -- First deployment remains an admin-only pilot even if EXECUTE is later granted.
  if not coalesce(public.bb_is_admin(),false) then
    raise exception 'Multi-bank invoice pilot is Admin-only';
  end if;
  if not public.bb_has_module_access('invoice_generator','create')
     or not public.bb_has_sales_write() then
    raise exception 'Invoice Generator create permission denied';
  end if;
  if not public.bb_has_location_access(v_location) then
    raise exception 'Invoice location access denied';
  end if;
  if v_customer is null or not exists(
    select 1 from public.customers c where c.customer_id=v_customer
      and coalesce(c.active,true)=true
  ) then raise exception 'A valid customer ID is required'; end if;
  if v_currency not in ('USD','KHR') then raise exception 'Unsupported currency'; end if;
  if v_method not in ('Bank','Partially Paid in Bank') then
    raise exception 'This endpoint only supports Bank or Partially Paid in Bank';
  end if;
  if jsonb_typeof(v_sources) is distinct from 'array' then
    raise exception 'settlement_sources must be an array';
  end if;
  if jsonb_array_length(v_sources) not between 2 and 30 then
    raise exception 'Select between 2 and 30 registered bank transactions';
  end if;
  v_precision := case when v_currency='USD' then 2 else 0 end;
  v_req := nullif(p_payment->>'settlement_request_id','')::uuid;
  if v_req is null then raise exception 'A settlement_request_id UUID is required'; end if;

  v_fingerprint:=md5(p_invoice::text||'|'||p_payment::text);
  -- Serializes retries for the same request, and prevents two simultaneous
  -- identical invoice submissions creating separate payment sets.
  perform pg_advisory_xact_lock(hashtext('BB_MULTI_BANK_REQ_'||v_req::text));
  select * into v_existing
    from public.bb_invoice_multi_bank_requests r where r.request_id=v_req;
  if found then
    if v_existing.actor_user_id<>v_actor
       or v_existing.payload_fingerprint<>v_fingerprint then
      raise exception 'Settlement request ID already belongs to another payload';
    end if;
    return v_existing.response;
  end if;

  -- Normalize, deduplicate and lock every source in deterministic order.
  select array_agg(distinct upper(btrim(x->>'source_id')) order by upper(btrim(x->>'source_id')))
    into v_ids
    from jsonb_array_elements(v_sources) x;
  if coalesce(array_length(v_ids,1),0)<>jsonb_array_length(v_sources)
    or exists(select 1 from jsonb_array_elements(v_sources) x
       where (x->>'kind') is distinct from 'BANK_REGISTER'
          or nullif(btrim(x->>'source_id'),'') is null) then
    raise exception 'Duplicate or invalid registered bank source';
  end if;

  foreach v_key in array v_ids loop
    perform pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_key));
    select * into v_source from public.bb_verified_bank_transactions b
     where upper(btrim(b.transaction_id))=v_key for update;
    if not found or v_source.status<>'AVAILABLE'
      or v_source.currency<>v_currency
      or not exists(select 1 from public.bb_bank_balance_snapshot s
        where s.transaction_id=v_source.transaction_id and s.customer_id=v_customer
          and s.status='AVAILABLE' and s.remaining_amount>0) then
      raise exception 'Source % unavailable, wrong customer or currency',v_key;
    end if;
  end loop;

  -- Validate each source amount against the server-side wallet view.
  for v_item in select value from jsonb_array_elements(v_sources)
  loop
    v_source_id:=upper(btrim(v_item->>'source_id'));
    if coalesce(v_item->>'source_amount','') !~ '^[0-9]+([.][0-9]+)?$'
      then raise exception 'Invalid amount for %',v_source_id; end if;
    v_amount:=(v_item->>'source_amount')::numeric;
    if v_amount<=0 or v_amount<>trunc(v_amount,v_precision)
       then raise exception 'Unsupported amount or precision for %',v_source_id; end if;
    if (v_item->>'source_currency') is distinct from v_currency then
      raise exception 'Source currency differs from invoice currency';
    end if;
    if v_item ? 'invoice_amount' then
      if coalesce(v_item->>'invoice_amount','') !~ '^[0-9]+([.][0-9]+)?$'
         or (v_item->>'invoice_amount')::numeric <> v_amount then
        raise exception 'Same-currency invoice allocation mismatch';
      end if;
    end if;
    select * into v_source from public.bb_verified_bank_transactions b
      where upper(btrim(b.transaction_id))=v_source_id;
    if v_amount>coalesce((select s.remaining_amount
                       from public.bb_bank_balance_snapshot s
                       where s.transaction_id=v_source.transaction_id and s.customer_id=v_customer),0) then
       raise exception 'Insufficient registered bank balance for %',v_source_id; end if;
    if nullif(btrim(coalesce(v_source.bank_name,'')),'') is null
       and (v_fallback_bank is null or upper(v_fallback_bank)='OTHER') then
      raise exception 'Select the actual receiving Payment Bank for registered transfer %',v_source_id;
    end if;
    v_total:=v_total+v_amount;
    v_details:=v_details||jsonb_build_array(
      jsonb_build_object('source_id',v_source.transaction_id,
                         'bank_name',coalesce(nullif(btrim(v_source.bank_name),''),v_fallback_bank),'amount',v_amount)
    );
  end loop;

  select bank_name into v_first_bank
  from public.bb_verified_bank_transactions
  where upper(btrim(transaction_id))=v_ids[1];
  v_first_bank:=coalesce(nullif(btrim(coalesce(v_first_bank,'')),''),v_fallback_bank);
  if v_first_bank is null or upper(v_first_bank)='OTHER' then
    raise exception 'Select an actual receiving Payment Bank for the invoice';
  end if;
  -- p_payment NULL prevents the legacy save from inserting an accidental
  -- single bank payment; we insert one payment per bank source below.
  -- The original function still creates stock lines and the invoice record.
  v_invoice_result:=public.bb_sales_save_invoice_bundle_core_access_v1(
     p_invoice||jsonb_build_object(
        'transactionId',v_ids[1],
        'paymentBank',v_first_bank,
        'amountPaid',v_total
     ),
     null
  );
  select * into v_invoice from public.invoices i
    where i.invoice_id=v_invoice_result->>'invoiceId' for update;
  if not found then raise exception 'Invoice save returned missing invoice'; end if;
  if v_method='Bank' and v_total<>v_invoice.grand_total then
    raise exception 'Full Bank payment must cover entire invoice';
  end if;
  if v_method='Partially Paid in Bank' and v_total>=v_invoice.grand_total then
    raise exception 'Partially paid invoice must have a positive outstanding balance';
  end if;
  if v_total<>v_invoice.amount_paid then
    raise exception 'Payment allocations do not equal the saved invoice amount';
  end if;

  -- Each inserted payment automatically calls the bank guard trigger, which
  -- locks the source and inserts bb_bank_balance_allocations.
  for v_item in select value from jsonb_array_elements(v_details)
  loop
    v_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
    insert into public.payments (
      payment_id,invoice_id,invoice_no_snapshot,payment_date,
      customer_id,customer_name_snapshot,location_code,
      salesperson_staff_id,salesperson_name_snapshot,
      payment_method,bank_payment,bank_reference,currency,exchange_rate,
      amount,note,transaction_id,payment_source
    ) values (
      v_payment_id,v_invoice.invoice_id,v_invoice.invoice_no,v_invoice.invoice_date,
      v_invoice.customer_id,v_invoice.customer_name_snapshot,v_invoice.location_code,
      v_invoice.salesperson_staff_id,v_invoice.salesperson_name_snapshot,
      'Bank',nullif(v_item->>'bank_name',''),v_item->>'source_id',
      v_currency,v_invoice.exchange_rate,(v_item->>'amount')::numeric,
      'Initial invoice multi-source bank allocation',
      v_item->>'source_id','Invoice'
    );
    v_payment_ids:=v_payment_ids||jsonb_build_array(v_payment_id);
  end loop;

  -- Fail closed unless every successful payment created its bank allocation.
  select count(*) into v_count
    from public.bb_bank_balance_allocations a
    join public.payments p on p.payment_id=a.payment_id
   where p.invoice_id=v_invoice.invoice_id
     and p.payment_source='Invoice'
     and a.reversed_at is null;
  if v_count<>jsonb_array_length(v_sources) then
    raise exception 'Missing bank allocation after invoice save';
  end if;
  -- Also verify the exact bank transfers and amounts. A matching row count
  -- alone is insufficient evidence that the intended wallet was debited.
  if exists (
    select 1 from jsonb_array_elements(v_details) d
    where not exists (
      select 1
      from public.bb_bank_balance_allocations a
      join public.payments p on p.payment_id=a.payment_id
      where p.invoice_id=v_invoice.invoice_id
        and p.payment_source='Invoice'
        and a.reversed_at is null
        and a.transaction_id=d->>'source_id'
        and p.transaction_id=d->>'source_id'
        and a.applied_bank_amount=(d->>'amount')::numeric
        and a.applied_invoice_amount=(d->>'amount')::numeric
        and p.amount=(d->>'amount')::numeric
    )
  ) then
    raise exception 'Multi-bank allocation source or amount mismatch';
  end if;

  v_result:=v_invoice_result||jsonb_build_object(
     'multiSource',true,'sourceCount',v_count,
     'paymentId',v_payment_ids->>0,'paymentIds',v_payment_ids,
     'allocatedBank',v_total,'settlementRequestId',v_req
  );
  insert into public.bb_invoice_multi_bank_requests
   (request_id,actor_user_id,payload_fingerprint,invoice_id,response)
  values(v_req,v_actor,v_fingerprint,v_invoice.invoice_id,v_result);
  return v_result;
end $function$;


CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_bundle_core_v1(p_invoice jsonb, p_payment jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice_id text:=trim(coalesce(p_invoice->>'invoiceId',''));
  v_invoice_no text:=trim(coalesce(p_invoice->>'invoiceNo',''));
  v_invoice_date date:=coalesce(nullif(p_invoice->>'invoiceDate','')::date,current_date);
  v_due_date date:=nullif(p_invoice->>'dueDate','')::date;
  v_location_code text:=trim(coalesce(p_invoice->>'locationCode',''));
  v_customer_id text:=nullif(trim(coalesce(p_invoice->>'customerId','')),'');
  v_customer_name text:=trim(coalesce(p_invoice->>'customer',''));
  v_salesperson_staff_id text:=nullif(trim(coalesce(p_invoice->>'salespersonStaffId','')),'');
  v_salesperson_name text:=trim(coalesce(p_invoice->>'salesperson',''));
  v_payment_method text:=trim(coalesce(p_invoice->>'paymentMethod',''));
  v_currency text:=upper(trim(coalesce(p_invoice->>'currency','USD')));
  v_exchange_rate numeric:=greatest(coalesce(nullif(p_invoice->>'exchangeRate','')::numeric,1),0);
  v_discount numeric:=greatest(coalesce(nullif(p_invoice->>'discount','')::numeric,0),0);
  v_amount_paid numeric:=greatest(coalesce(nullif(p_invoice->>'amountPaid','')::numeric,0),0);
  v_batch text:=nullif(trim(coalesce(p_invoice->>'batchNumber','')),'');
  v_shipping text:=nullif(trim(coalesce(p_invoice->>'shippingTo','')),'');
  v_note text:=nullif(trim(coalesce(p_invoice->>'note','')),'');
  v_bank text:=nullif(trim(coalesce(p_invoice->>'paymentBank','')),'');
  v_tx text:=nullif(trim(coalesce(p_invoice->>'transactionId','')),'');
  v_subtotal numeric:=0;
  v_grand numeric:=0;
  v_outstanding numeric:=0;
  v_status text;
  v_items jsonb:=coalesce(p_invoice->'items','[]'::jsonb);
  v_item jsonb;
  v_line_no integer:=0;
  v_line_id text;
  v_entry text;
  v_product_code text;
  v_group_code text;
  v_display_code text;
  v_product_name text;
  v_barcode text;
  v_unit text;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_alloc jsonb;
  v_need numeric;
  v_take numeric;
  v_r record;
  v_count integer;
  v_payment_id text:='';
  v_payment_amount numeric:=0;
  v_payment_method_normalized text;
  v_client_line_id text;
begin
  if not public.bb_has_sales_write() then
    raise exception 'BIG BROTHER sales write access denied';
  end if;

  if v_invoice_no='' then raise exception 'Invoice No. is required'; end if;
  if v_location_code='' then raise exception 'Main Location is required'; end if;
  if v_customer_name='' then raise exception 'Customer is required'; end if;
  if v_salesperson_name='' then raise exception 'Sale Person is required'; end if;
  if v_payment_method='' then raise exception 'Payment Method is required'; end if;
  if v_currency not in ('USD','KHR') then raise exception 'Currency must be USD or KHR'; end if;
  if jsonb_typeof(v_items)<>'array' or jsonb_array_length(v_items)=0 then raise exception 'At least one Product is required'; end if;

  if not exists(select 1 from public.locations where location_code=v_location_code and active=true) then
    raise exception 'Main Location % is not active',v_location_code;
  end if;


  if v_invoice_id='' then
    v_invoice_id := 'BB-' || to_char(clock_timestamp() at time zone 'Asia/Phnom_Penh','YYYYMMDD-HH24MISSMS') || '-' || substr(md5(random()::text),1,5);
  end if;
  if exists(select 1 from public.invoices where invoice_id=v_invoice_id) then
    raise exception 'Invoice ID already exists. Please retry.';
  end if;

  if v_customer_id is not null then
    if not exists(select 1 from public.customers c where c.customer_id=v_customer_id and coalesce(c.active,true)=true) then
      v_customer_id:=null;
    end if;
  end if;
  if v_customer_id is null then
    select count(*),min(c.customer_id)
    into v_count,v_customer_id
    from public.customers c
    where lower(trim(coalesce(c.customer_name,'')))=lower(v_customer_name)
      and coalesce(c.location_code,'')=v_location_code
      and coalesce(c.active,true)=true;
    if v_count<>1 then v_customer_id:=null; end if;
  end if;

  if v_salesperson_staff_id is not null and not exists(
    select 1 from public.staff s where s.staff_id=v_salesperson_staff_id and lower(coalesce(s.status,'active'))='active'
  ) then
    v_salesperson_staff_id:=null;
  end if;
  if v_salesperson_staff_id is null then
    select count(*),min(s.staff_id)
    into v_count,v_salesperson_staff_id
    from public.staff s
    where lower(trim(s.staff_name))=lower(v_salesperson_name)
      and lower(coalesce(s.status,'active'))='active';
    if v_count<>1 then v_salesperson_staff_id:=null; end if;
  end if;

  if v_batch is not null then
    if not exists(
      select 1 from public.stock_batches b
      where b.batch_id=v_batch
        and upper(coalesce(b.status,'OPEN')) not in ('CLOSED','CANCELLED','CANCELED')
    ) then raise exception 'Batch % is not open',v_batch; end if;
    if exists(select 1 from public.stock_batches b where b.batch_id=v_batch and b.location_code<>v_location_code) then
      raise exception 'Batch % belongs to a different Location',v_batch;
    end if;
  end if;

  -- Validate products and calculate authoritative subtotal from line quantities/prices.
  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_entry:=upper(trim(coalesce(v_item->>'entryType','EXACT')));
    v_qty:=greatest(coalesce(nullif(v_item->>'qty','')::numeric,0),0);
    v_unit_price:=greatest(coalesce(nullif(v_item->>'unitPrice','')::numeric,0),0);
    if v_qty<=0 then continue; end if;

    if v_entry='GROUP' then
      v_group_code:=nullif(trim(coalesce(v_item->>'productGroupCode',v_item->>'productCode')),'');
      if v_group_code is null or not exists(select 1 from public.product_groups g where g.group_code=v_group_code and g.active=true) then
        raise exception 'Product Group % is invalid',coalesce(v_group_code,'');
      end if;
      if v_batch is null then raise exception 'Product Group % requires a Batch',v_group_code; end if;
    elsif v_entry='EXACT' then
      v_product_code:=nullif(trim(coalesce(v_item->>'productCode','')),'');
      if v_product_code is null or not exists(select 1 from public.products p where p.product_code=v_product_code and p.active=true) then
        raise exception 'Product % is invalid',coalesce(v_product_code,'');
      end if;
    else
      raise exception 'Invalid line Entry Type: %',v_entry;
    end if;

    v_subtotal:=v_subtotal+(v_qty*v_unit_price);
    v_line_no:=v_line_no+1;
  end loop;

  if v_line_no=0 then raise exception 'Purchase quantities are empty'; end if;
  v_discount:=least(v_discount,v_subtotal);
  v_grand:=greatest(v_subtotal-v_discount,0);
  v_amount_paid:=least(v_amount_paid,v_grand);

  if v_payment_method in ('Cash','Bank') then v_amount_paid:=v_grand; end if;
  if v_payment_method='Credit' then v_amount_paid:=0; end if;
  v_outstanding:=greatest(v_grand-v_amount_paid,0);
  v_status:=case when v_outstanding<=0 then 'Paid' when v_amount_paid>0 then 'Processing' else 'Unpaid' end;

  if v_payment_method in ('Bank','Partially Paid in Bank') then
    if v_bank is null then raise exception 'Payment Bank is required'; end if;
    if v_tx is null then raise exception 'Transaction ID is required for Bank payment'; end if;
  end if;
  -- A registered transfer can fund multiple invoices until its balance is
  -- consumed. Manual/unregistered transaction IDs remain strictly unique.
  if v_tx is not null
     and exists(select 1 from public.payments p where lower(trim(p.transaction_id))=lower(v_tx))
     and not (v_payment_method in ('Bank','Partially Paid in Bank')
       and v_customer_id is not null and exists(
         select 1 from public.bb_verified_bank_transactions r
         join public.bb_bank_balance_snapshot b on b.transaction_id=r.transaction_id
         where lower(trim(r.transaction_id))=lower(v_tx)
           and b.customer_id=v_customer_id
           and r.status='AVAILABLE' and b.remaining_amount>0
       ))
  then
    raise exception 'Transaction ID already exists';
  end if;

  insert into public.invoices(
    invoice_id,invoice_no,invoice_date,customer_id,customer_name_snapshot,
    salesperson_staff_id,salesperson_name_snapshot,payment_method,currency,exchange_rate,
    subtotal,discount,grand_total,amount_paid,change_amount,outstanding,status,note,due_date,
    bank_payment,bank_reference,credit_amount,batch_number,location_code,shipping_to_legacy
  ) values (
    v_invoice_id,v_invoice_no,v_invoice_date,v_customer_id,v_customer_name,
    v_salesperson_staff_id,v_salesperson_name,v_payment_method,v_currency,v_exchange_rate,
    v_subtotal,v_discount,v_grand,v_amount_paid,0,v_outstanding,v_status,v_note,v_due_date,
    v_bank,v_tx,v_outstanding,v_batch,v_location_code,v_shipping
  );

  v_line_no:=0;
  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_entry:=upper(trim(coalesce(v_item->>'entryType','EXACT')));
    v_qty:=greatest(coalesce(nullif(v_item->>'qty','')::numeric,0),0);
    if v_qty<=0 then continue; end if;
    v_unit_price:=greatest(coalesce(nullif(v_item->>'unitPrice','')::numeric,0),0);
    v_line_total:=v_qty*v_unit_price;
    v_line_no:=v_line_no+1;
    v_client_line_id:=trim(coalesce(v_item->>'lineId',''));
    v_line_id:=case when v_client_line_id<>'' and not exists(select 1 from public.invoice_lines where line_id=v_client_line_id)
                    then v_client_line_id
                    else 'LINE-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' || v_line_no::text || '-' || substr(md5(random()::text),1,5)
               end;
    v_product_name:=nullif(trim(coalesce(v_item->>'productName','')),'');
    v_barcode:=nullif(trim(coalesce(v_item->>'productBarcode','')),'');
    v_unit:=nullif(trim(coalesce(v_item->>'unit','')),'');
    v_alloc:=null;

    /* ========================================================
       DIRECT SALE SOURCE ALLOCATION V1
       ======================================================== */

    if

      v_batch is null

      and

      jsonb_typeof(
        v_item->'stockAllocations'
      )
      =
      'array'

      and

      jsonb_array_length(
        v_item->'stockAllocations'
      )
      >
      0

    then

      v_alloc :=
        v_item->'stockAllocations';

    end if;

    -- Batch Exact stock source allocations preserve the operator's explicit split.
    -- Direct Sale retains its existing handling; Group lines remain legacy allocated.
    if v_batch is not null and v_entry='EXACT' and v_item ? 'stockAllocations' then
      if jsonb_typeof(v_item->'stockAllocations') <> 'array'
         or jsonb_array_length(v_item->'stockAllocations') = 0 then
        raise exception 'Batch line requires Purchased or Zero-Cost allocation';
      end if;
      v_alloc := (
        select jsonb_agg(jsonb_build_object(
          'productCode',trim(coalesce(v_item->>'productCode','')),
          'source',upper(trim(coalesce(e.value->>'source',''))),
          'qty',e.value->'qty'))
        from jsonb_array_elements(v_item->'stockAllocations') e
      );
    end if;

    if v_entry='EXACT' then
      v_product_code:=trim(coalesce(v_item->>'productCode',''));
      v_group_code:=null;
      v_display_code:=v_product_code;
      if v_product_name is null or v_barcode is null or v_unit is null then
        select coalesce(v_product_name,p.product_name),coalesce(v_barcode,p.barcode),coalesce(v_unit,p.unit)
        into v_product_name,v_barcode,v_unit
        from public.products p where p.product_code=v_product_code;
      end if;
    else
      v_product_code:=null;
      v_group_code:=trim(coalesce(v_item->>'productGroupCode',v_item->>'productCode'));
      v_display_code:=v_group_code;
      if v_product_name is null then select g.group_name into v_product_name from public.product_groups g where g.group_code=v_group_code; end if;

      v_alloc:='[]'::jsonb;
      v_need:=v_qty;
      for v_r in
        select r.product_code,greatest(r.difference_qty,0) as available
        from public.v_batch_reconciliation r
        join public.product_group_mapping m
          on m.product_code=r.product_code
         and m.group_code=v_group_code
         and m.use_group=true
         and lower(m.status)='active'
        where r.batch_id=v_batch
        order by r.product_code
      loop
        exit when v_need<=0.0000001;
        v_take:=least(v_need,v_r.available);
        if v_take>0 then
          v_alloc:=v_alloc || jsonb_build_array(jsonb_build_object('productCode',v_r.product_code,'qty',v_take));
          v_need:=v_need-v_take;
        end if;
      end loop;
      if v_need>0.0000001 then
        raise exception 'Batch % does not have enough remaining stock for Group % (short by %)',v_batch,v_group_code,v_need;
      end if;
    end if;

    insert into public.invoice_lines(
      line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,product_code,product_group_code,
      display_product_code,product_name_snapshot,product_barcode_snapshot,product_note,qty,unit_snapshot,
      unit_price,line_total,stock_allocation_json
    ) values (
      v_line_id,v_invoice_id,v_invoice_no,v_line_no,v_entry,v_product_code,v_group_code,
      v_display_code,v_product_name,v_barcode,nullif(trim(coalesce(v_item->>'productNote','')),''),v_qty,v_unit,
      v_unit_price,v_line_total,v_alloc
    );
  end loop;

  if p_payment is not null and jsonb_typeof(p_payment)='object' and v_amount_paid>0 then
    v_payment_amount:=least(greatest(coalesce(nullif(p_payment->>'amount','')::numeric,v_amount_paid),0),v_amount_paid);
    if v_payment_amount>0 then
      v_payment_method_normalized:=case when v_payment_method in ('Bank','Partially Paid in Bank') then 'Bank' else 'Cash' end;
      v_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
      insert into public.payments(
        payment_id,invoice_id,invoice_no_snapshot,payment_date,customer_id,customer_name_snapshot,
        location_code,salesperson_staff_id,salesperson_name_snapshot,payment_method,bank_payment,
        bank_reference,currency,exchange_rate,amount,note,transaction_id,payment_source
      ) values (
        v_payment_id,v_invoice_id,v_invoice_no,v_invoice_date,v_customer_id,v_customer_name,
        v_location_code,v_salesperson_staff_id,v_salesperson_name,v_payment_method_normalized,
        case when v_payment_method_normalized='Bank' then v_bank else null end,
        case when v_payment_method_normalized='Bank' then v_tx else null end,
        v_currency,v_exchange_rate,v_payment_amount,
        coalesce(nullif(trim(coalesce(p_payment->>'note','')),''),'Initial invoice payment'),
        case when v_payment_method_normalized='Bank' then v_tx else null end,'Invoice'
      );
    end if;
  end if;

  return jsonb_build_object(
    'success',true,
    'invoiceId',v_invoice_id,
    'invoiceNo',v_invoice_no,
    'paymentId',v_payment_id,
    'subtotal',v_subtotal,
    'grandTotal',v_grand,
    'amountPaid',v_amount_paid,
    'outstanding',v_outstanding,
    'status',v_status
  );
exception
  when unique_violation then
    if position('uq_payments_transaction_id_normalized' in sqlerrm)>0 then
      raise exception 'Transaction ID already exists';
    elsif position('uq_invoices_invoice_no_customer_id' in sqlerrm)>0 then
      raise exception 'Invoice No. % already exists for this Customer',v_invoice_no;
    elsif position('invoices_invoice_no_key' in sqlerrm)>0 then
      raise exception 'Invoice No. % already exists',v_invoice_no;
    else
      raise;
    end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_split_payment(p_invoice jsonb, p_payment jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_location text:=trim(coalesce(p_invoice->>'locationCode',''));
  v_method text:=trim(coalesce(p_invoice->>'paymentMethod',''));
  v_bank text:=nullif(trim(coalesce(p_invoice->>'paymentBank','')),'');
  v_tx text:=nullif(trim(coalesce(p_invoice->>'transactionId','')),'');
  v_currency text:=upper(trim(coalesce(p_invoice->>'currency','USD')));
  v_cash numeric:=greatest(coalesce(nullif(p_payment->>'cashAmount','')::numeric,0),0);
  v_bank_amount numeric:=greatest(coalesce(nullif(p_payment->>'bankAmount','')::numeric,0),0);
  v_invoice_payload jsonb;
  v_cash_payload jsonb;
  v_result jsonb;
  v_invoice public.invoices%rowtype;
  v_bank_payment_id text;
  v_cash_payment_id text;
begin
  if not public.bb_has_module_access('invoice_generator','create') then
    raise exception 'Invoice Generator create access denied';
  end if;

  if not public.bb_has_location_access(v_location) then
    raise exception 'Invoice location access denied';
  end if;

  if v_method<>'Cash + Bank' then
    raise exception 'Cash + Bank payment method is required';
  end if;

  if v_cash<=0 then
    raise exception 'Cash Amount must be greater than 0';
  end if;

  if v_bank_amount<=0 then
    raise exception 'Bank Amount must be greater than 0';
  end if;

  if v_bank is null then
    raise exception 'Payment Bank is required';
  end if;

  if v_tx is null then
    raise exception 'Transaction ID is required for the Bank portion';
  end if;

  if v_currency not in ('USD','KHR') then
    raise exception 'Currency must be USD or KHR';
  end if;

  -- Permit verified balances to be split across invoices only while funds
  -- remain for the very same customer. The payment trigger checks the amount.
  if exists(
    select 1 from public.payments p
    where lower(trim(coalesce(p.transaction_id,'')))=lower(v_tx)
  ) and not exists(
    select 1 from public.bb_verified_bank_transactions r
    join public.bb_bank_balance_snapshot b on b.transaction_id=r.transaction_id
    where lower(trim(r.transaction_id))=lower(v_tx)
      and b.customer_id=nullif(trim(coalesce(p_invoice->>'customerId','')),'')
      and r.status='AVAILABLE' and b.remaining_amount>0
  ) then
    raise exception 'Transaction ID already exists';
  end if;

  v_invoice_payload :=
    p_invoice
    || jsonb_build_object(
         'paymentMethod','Cash',
         -- The interim cash step must not claim the existing bank transfer.
         -- The bank payment below carries the true transaction ID, and the
         -- finished invoice restores it after the bank allocation succeeds.
         'transactionId','',
         'bankReference','',
         'paymentBank','',
         'amountPaid',coalesce(nullif(p_invoice->>'grandTotal','')::numeric,0),
         'creditAmount',0,
         'outstanding',0,
         'status','Paid'
       );

  v_cash_payload :=
    coalesce(p_payment,'{}'::jsonb)
    || jsonb_build_object(
         'paymentMethod','Cash',
         'amount',v_cash,
         'bankPayment','',
         'transactionId','',
         'bankReference','',
         'note','Initial invoice split payment - Cash'
       );

  v_result :=
    public.bb_sales_save_invoice_bundle_core_access_v1(
      v_invoice_payload,
      v_cash_payload
    );

  select *
  into v_invoice
  from public.invoices i
  where i.invoice_id=v_result->>'invoiceId'
  for update;

  if not found then
    raise exception 'Split payment invoice was not created';
  end if;

  if abs((v_cash+v_bank_amount)-v_invoice.grand_total)
     > (case when v_invoice.currency='KHR' then 0.5 else 0.005 end)
  then
    raise exception
      'Cash Amount + Bank Amount must equal Grand Total (% + % <> %)',
      v_cash,
      v_bank_amount,
      v_invoice.grand_total;
  end if;

  v_cash_payment_id:=nullif(trim(coalesce(v_result->>'paymentId','')),'');

  v_bank_payment_id :=
    public.bb_next_prefixed_id(
      'public.payments'::regclass,
      'payment_id',
      'PAY',
      4
    );

  insert into public.payments(
    payment_id,
    invoice_id,
    invoice_no_snapshot,
    payment_date,
    customer_id,
    customer_name_snapshot,
    location_code,
    salesperson_staff_id,
    salesperson_name_snapshot,
    payment_method,
    bank_payment,
    bank_reference,
    currency,
    exchange_rate,
    amount,
    note,
    transaction_id,
    payment_source
  )
  values(
    v_bank_payment_id,
    v_invoice.invoice_id,
    v_invoice.invoice_no,
    v_invoice.invoice_date,
    v_invoice.customer_id,
    v_invoice.customer_name_snapshot,
    v_invoice.location_code,
    v_invoice.salesperson_staff_id,
    v_invoice.salesperson_name_snapshot,
    'Bank',
    v_bank,
    v_tx,
    v_invoice.currency,
    v_invoice.exchange_rate,
    v_bank_amount,
    'Initial invoice split payment - Bank',
    v_tx,
    'Invoice'
  );

  update public.invoices
  set
    payment_method='Cash + Bank',
    amount_paid=grand_total,
    outstanding=0,
    credit_amount=0,
    status='Paid',
    bank_payment=v_bank,
    bank_reference=v_tx
  where invoice_id=v_invoice.invoice_id;

  return
    v_result
    || jsonb_build_object(
         'paymentMethod','Cash + Bank',
         'paymentIds',jsonb_build_array(v_cash_payment_id,v_bank_payment_id),
         'cashPaymentId',v_cash_payment_id,
         'bankPaymentId',v_bank_payment_id,
         'splitCashAmount',v_cash,
         'splitBankAmount',v_bank_amount,
         'amountPaid',v_invoice.grand_total,
         'outstanding',0,
         'status','Paid'
       );
exception
  when unique_violation then
    if position('uq_payments_transaction_id_normalized' in sqlerrm)>0 then
      raise exception 'Transaction ID already exists';
    else
      raise;
    end if;
end;
$function$;


-- Invoice Generator's pre-save validation must respect per-outlet bank receipt balance.
CREATE OR REPLACE FUNCTION public.bb_bank_validate_invoice_input(p_customer_id text, p_transaction_id text, p_actual_amount numeric, p_actual_currency text, p_invoice_currency text, p_exchange_rate numeric, p_equivalent_amount numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare reg public.bb_verified_bank_transactions%rowtype;
 cur text:=upper(trim(coalesce(p_invoice_currency,'')));
 actual_cur text:=upper(trim(coalesce(p_actual_currency,'')));
 rate numeric; debit numeric; spent numeric; remaining numeric; tol numeric;
begin
 if not public.bb_has_module_access('invoice_generator','create') then raise exception 'Invoice Generator access required'; end if;
 if cur not in ('USD','KHR') or actual_cur not in ('USD','KHR') or coalesce(p_equivalent_amount,0)<=0 then return false; end if;
 select * into reg from public.bb_verified_bank_transactions where upper(trim(transaction_id))=upper(trim(coalesce(p_transaction_id,'')));
 if not found then
   return public.bb_is_admin() and nullif(trim(coalesce(p_transaction_id,'')),'') is not null
      and coalesce(p_equivalent_amount,0)>0;
 end if;
 if reg.status<>'AVAILABLE' or reg.currency<>actual_cur
   or p_actual_amount is null or p_actual_amount<=0
   or not exists(select 1 from public.bb_bank_balance_snapshot b
     where b.transaction_id=reg.transaction_id and b.customer_id=p_customer_id
       and b.status='AVAILABLE' and b.remaining_amount>0)
 then return false; end if;
 rate:=case when reg.currency=cur then 1
     when coalesce(reg.approved_exchange_rate,0)>1 then reg.approved_exchange_rate
     else p_exchange_rate end;
 if reg.currency<>cur and (rate is null or rate<=1 or p_exchange_rate is null
     or abs(rate-p_exchange_rate)>0.000001) then return false; end if;
 debit:=case when reg.currency=cur then p_equivalent_amount
   when reg.currency='KHR' then p_equivalent_amount*rate
   else p_equivalent_amount/rate end;
 select b.remaining_amount,b.original_amount
   into remaining,spent
 from public.bb_bank_balance_snapshot b
 where b.transaction_id=reg.transaction_id and b.customer_id=p_customer_id;
 if remaining is null then return false; end if;
 tol:=case when reg.currency='KHR' then 0.5 else 0.005 end;
 return remaining>0 and debit>0 and debit<=remaining+tol and
  (abs(p_actual_amount-reg.amount)<=tol or abs(p_actual_amount-spent)<=tol
   or abs(p_actual_amount-debit)<=tol or abs(p_actual_amount-remaining)<=tol);
end $function$;


-- Fail before COMMIT if any object is still missing.
DO $bb_validate$
BEGIN
 IF to_regclass('public.bb_bank_outlet_shares') IS NULL
    OR to_regprocedure('public.bb_bank_outlet_share_save_v1(text,jsonb)') IS NULL
    OR to_regprocedure('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)') IS NULL
 THEN RAISE EXCEPTION 'BB_MULTI_OUTLET_LOCAL_SCHEMA_INCOMPLETE';END IF;
END $bb_validate$;
COMMIT;

-- Verify manually after install:
-- SELECT to_regclass('public.bb_bank_outlet_shares');
-- SELECT count(*) FROM public.bb_bank_outlet_shares;
