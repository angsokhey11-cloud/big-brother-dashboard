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
 t.received_date,e.share_amount AS original_amount,
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
  'customerName',c.customer_name,'location',c.location_code,'amount',s.allocated_amount,
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
