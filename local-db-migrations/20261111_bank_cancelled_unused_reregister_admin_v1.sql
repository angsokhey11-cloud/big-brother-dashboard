-- Protect original bank IDs. Only an authenticated Admin may revive a cancelled, never-used ID.
-- Consumes the cancelled-ID reservation ONLY inside the caller's transaction.
CREATE OR REPLACE FUNCTION public.bb_bank_reactivate_cancelled_unused_id_v1(
 p_transaction_id text,p_customer_id text,p_amount numeric,
 p_currency text,p_received_date date,p_payer_name text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
 v_tid text:=upper(btrim(coalesce(p_transaction_id,'')));
 v_cancelled_at timestamptz;
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_admin()
 THEN RAISE EXCEPTION 'Admin required to reactivate a cancelled bank ID';END IF;
 IF length(v_tid)<4 OR length(v_tid)>160
 THEN RAISE EXCEPTION 'Invalid bank transaction reference'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tid));
 SELECT c.cancelled_at INTO v_cancelled_at
 FROM public.bb_cancelled_bank_transaction_ids c
 WHERE upper(btrim(c.transaction_id))=v_tid FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;

 -- "Never used" includes reversed payments; an ID that has EVER posted remains reserved.
 IF EXISTS(SELECT 1 FROM public.bb_verified_bank_transactions t WHERE upper(btrim(t.transaction_id))=v_tid)
 OR EXISTS(SELECT 1 FROM public.payments p WHERE upper(btrim(coalesce(p.transaction_id,'')))=v_tid)
 OR EXISTS(SELECT 1 FROM public.company_deposits d WHERE upper(btrim(coalesce(d.collection_transaction_id,'')))=v_tid)
 OR EXISTS(SELECT 1 FROM public.purchase_payments p WHERE upper(btrim(coalesce(p.transaction_id,'')))=v_tid)
 OR EXISTS(SELECT 1 FROM public.bb_bank_balance_allocations a WHERE upper(btrim(a.transaction_id))=v_tid)
 OR EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE upper(btrim(s.transaction_id))=v_tid)
 THEN RAISE EXCEPTION 'Cancelled bank ID has real financial history and cannot be reused';END IF;

 INSERT INTO public.bb_audit_log(actor_user_id,actor_staff_id,actor_name,module,action,
   record_type,record_id,reference_no,reason,before_state,after_state,metadata)
 VALUES(auth.uid(),public.bb_actor_staff_id(),coalesce(nullif(public.bb_actor_name(),''),'Admin'),
 'bank_register','RE_REGISTER_CANCELLED_UNUSED',
 'bb_verified_bank_transactions',v_tid,v_tid,
 'Admin approved re-registration of cancelled ID with no payment, allocation or deposit history',
 jsonb_build_object('status','CANCELLED','cancelled_at',v_cancelled_at),
 jsonb_build_object('status','AVAILABLE','customer_id',p_customer_id,
    'bank_amount',p_amount,'bank_currency',p_currency,'received_date',p_received_date,
    'payer',p_payer_name),
 jsonb_build_object('unused_guard_passed',true,'audit_preserved',true));
 DELETE FROM public.bb_cancelled_bank_transaction_ids c
 WHERE upper(btrim(c.transaction_id))=v_tid;
 IF NOT FOUND THEN RAISE EXCEPTION 'Cancelled bank reservation changed during re-registration';END IF;
 RETURN true;
END $fn$;
REVOKE ALL ON FUNCTION public.bb_bank_reactivate_cancelled_unused_id_v1(text,text,numeric,text,date,text) FROM PUBLIC,anon,authenticated;



-- Read-only preview for Bank Register UI. Final authorization is RECHECKED at insert time.
CREATE OR REPLACE FUNCTION public.bb_bank_reregistration_status_v1(p_transaction_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_tid text:=upper(btrim(coalesce(p_transaction_id,'')));
 v_c timestamp with time zone;
 v_used boolean;
 v_active boolean;
 v_prev jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_admin() THEN RAISE EXCEPTION 'Admin required'; END IF;
 IF length(v_tid)<4 OR length(v_tid)>160 THEN
  RETURN jsonb_build_object('status','INVALID','reusable',false);END IF;
 SELECT EXISTS(SELECT 1 FROM public.bb_verified_bank_transactions t
   WHERE upper(btrim(t.transaction_id))=v_tid) INTO v_active;
 SELECT c.cancelled_at INTO v_c FROM public.bb_cancelled_bank_transaction_ids c
  WHERE upper(btrim(c.transaction_id))=v_tid;
 SELECT (
 EXISTS(SELECT 1 FROM public.payments p WHERE upper(btrim(coalesce(p.transaction_id,'')))=v_tid)
 OR EXISTS(SELECT 1 FROM public.company_deposits d WHERE upper(btrim(coalesce(d.collection_transaction_id,'')))=v_tid)
 OR EXISTS(SELECT 1 FROM public.purchase_payments p WHERE upper(btrim(coalesce(p.transaction_id,'')))=v_tid)
 OR EXISTS(SELECT 1 FROM public.bb_bank_balance_allocations a WHERE upper(btrim(a.transaction_id))=v_tid)
 OR EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE upper(btrim(s.transaction_id))=v_tid)
 ) INTO v_used;
 IF v_c IS NOT NULL THEN
  SELECT a.before_state INTO v_prev
  FROM public.bb_audit_log a
  WHERE upper(btrim(coalesce(a.reference_no,'')))=v_tid
   AND a.action='BANK_CANCELLED_UNUSED'
  ORDER BY a.occurred_at DESC LIMIT 1;
 END IF;
 RETURN jsonb_build_object(
 'transactionId',v_tid,
 'status',case when v_active then 'ACTIVE' when v_used then 'USED'
    when v_c IS NOT NULL then 'CANCELLED_UNUSED' else 'NEW' end,
 'reusable',NOT v_active AND NOT v_used,
 'cancelledAt',v_c,
 'previousBankAmount',v_prev->'amount','previousBankCurrency',v_prev->'currency',
 'previousCustomer',v_prev->'customer_id');
END $fn$;
REVOKE ALL ON FUNCTION public.bb_bank_reregistration_status_v1(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_bank_reregistration_status_v1(text) TO authenticated;


CREATE OR REPLACE FUNCTION public.bb_bank_register_invoice_tx_v4(p_customer_id text, p_transaction_id text, p_amount numeric, p_currency text, p_invoice_currency text, p_exchange_rate numeric, p_received_date date, p_payer_identity_id bigint, p_bank_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tid text:=upper(trim(coalesce(p_transaction_id,'')));
  cur text:=upper(trim(coalesce(p_currency,'')));
  inv text:=upper(trim(coalesce(p_invoice_currency,'')));
  rate numeric:=case when cur=inv then 1 else p_exchange_rate end;
  local_today date:=(now() at time zone 'Asia/Phnom_Penh')::date;
  rdate date:=coalesce(p_received_date,(now() at time zone 'Asia/Phnom_Penh')::date);
  payer_name text;
  was_reactivated boolean:=false;
begin
  if not public.bb_is_admin() then raise exception 'Admin verification required'; end if;
  if tid='' or length(tid)>160 or p_amount is null or p_amount<=0
     or cur not in ('USD','KHR') or inv not in ('USD','KHR')
  then raise exception 'Invalid bank transaction information'; end if;
  if rate is null or rate<=0 or (cur<>inv and rate<=1)
  then raise exception 'Valid KHR per USD exchange rate required'; end if;
  if rdate>local_today then raise exception 'Received date cannot be in the future'; end if;

  select b.account_holder_name
  into payer_name
  from public.bb_customer_bank_identities b
  where b.identity_id=p_payer_identity_id
    and b.customer_id=p_customer_id
    and b.active=true;

  if payer_name is null then
    raise exception 'Select an active payer identity for this customer';
  end if;

  perform pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||tid));

  if exists(select 1 from public.payments where upper(trim(coalesce(transaction_id,'')))=tid)
     or exists(select 1 from public.company_deposits where upper(trim(coalesce(collection_transaction_id,'')))=tid)
     or exists(select 1 from public.bb_verified_bank_transactions where upper(trim(transaction_id))=tid)
     or exists(select 1 from public.purchase_payments where upper(trim(coalesce(transaction_id,'')))=tid)
  then raise exception 'Transaction ID already exists'; end if;
  was_reactivated:=public.bb_bank_reactivate_cancelled_unused_id_v1(
     tid,p_customer_id,p_amount,cur,rdate,payer_name);

  insert into public.bb_verified_bank_transactions(
    transaction_id,customer_id,amount,currency,invoice_currency,
    approved_exchange_rate,bank_name,received_date,created_by,
    payer_identity_id,payer_name
  )
  values(
    tid,p_customer_id,p_amount,cur,inv,rate,
    nullif(trim(coalesce(p_bank_name,'')),''),rdate,auth.uid(),
    p_payer_identity_id,payer_name
  );

  return jsonb_build_object(
    'success',true,
    'transactionId',tid,
    'status','AVAILABLE',
    'receivedDate',rdate,
    'payerIdentityId',p_payer_identity_id,
    'payerName',payer_name,
    'reRegistered',was_reactivated
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.bb_bank_register_invoice_tx_no_directory(p_customer_id text, p_transaction_id text, p_amount numeric, p_currency text, p_invoice_currency text, p_exchange_rate numeric, p_received_date date, p_payer_name text, p_bank_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare tid text:=upper(trim(coalesce(p_transaction_id,''))); cur text:=upper(trim(coalesce(p_currency,''))); inv text:=upper(trim(coalesce(p_invoice_currency,''))); sender text:=trim(coalesce(p_payer_name,'')); rate numeric:=case when cur=inv then 1 else p_exchange_rate end; was_reactivated boolean:=false;
begin
 if not public.bb_is_admin() then raise exception 'Admin verification required'; end if;
 if not exists(select 1 from public.customers where customer_id=p_customer_id and active=true) then raise exception 'Active customer required';end if;
 if tid='' or length(tid)>160 or p_amount is null or p_amount<=0 or cur not in ('USD','KHR') or inv not in ('USD','KHR') or length(sender)<2 or length(sender)>140 or p_received_date is null or p_received_date>(now() at time zone 'Asia/Phnom_Penh')::date or rate is null or rate<=0 or (cur<>inv and rate<=1) then raise exception 'Invalid bank registration details';end if;
 perform pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||tid));
 if exists(select 1 from public.payments where upper(trim(coalesce(transaction_id,'')))=tid) or exists(select 1 from public.company_deposits where upper(trim(coalesce(collection_transaction_id,'')))=tid) or exists(select 1 from public.bb_verified_bank_transactions where upper(trim(transaction_id))=tid) or exists(select 1 from public.purchase_payments where upper(trim(coalesce(transaction_id,'')))=tid) then raise exception 'Transaction ID already exists';end if;
 was_reactivated:=public.bb_bank_reactivate_cancelled_unused_id_v1(
   tid,p_customer_id,p_amount,cur,p_received_date,sender);
 insert into public.bb_verified_bank_transactions(transaction_id,customer_id,amount,currency,invoice_currency,approved_exchange_rate,bank_name,received_date,created_by,payer_identity_id,payer_name)
 values(tid,p_customer_id,p_amount,cur,inv,rate,nullif(trim(coalesce(p_bank_name,'')),''),p_received_date,auth.uid(),null,sender);
 return jsonb_build_object('success',true,'transactionId',tid,'status','AVAILABLE','payerName',sender,'reRegistered',was_reactivated);
end $function$;

CREATE OR REPLACE FUNCTION public.bb_bank_cancel_invoice_tx(p_transaction_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_id text:=upper(trim(coalesce(p_transaction_id,'')));
 v_tx public.bb_verified_bank_transactions%ROWTYPE;
 v_split jsonb;
begin
 if not public.bb_is_admin() then raise exception 'Admin verification required'; end if;
 perform pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_id));
 SELECT * INTO v_tx FROM public.bb_verified_bank_transactions t
 WHERE t.transaction_id=v_id FOR UPDATE;
 IF NOT FOUND OR v_tx.status<>'AVAILABLE' OR v_tx.used_payment_id IS NOT NULL
 OR v_tx.used_at IS NOT NULL THEN
  RAISE EXCEPTION 'Only never-used registered bank transfers can be cancelled'; END IF;
 IF EXISTS(SELECT 1 FROM public.payments p WHERE upper(trim(coalesce(p.transaction_id,'')))=v_id)
 OR EXISTS(SELECT 1 FROM public.company_deposits d WHERE upper(trim(coalesce(d.collection_transaction_id,'')))=v_id)
 OR EXISTS(SELECT 1 FROM public.purchase_payments p WHERE upper(trim(coalesce(p.transaction_id,'')))=v_id)
 OR EXISTS(SELECT 1 FROM public.bb_bank_balance_allocations a WHERE upper(trim(a.transaction_id))=v_id)
 THEN RAISE EXCEPTION 'Bank transaction has payment or allocation history; cancellation is prohibited';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(s)),'[]'::jsonb) INTO v_split
 FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=v_id;
 -- Move a still-unused verification to the restricted transaction-ID reservation list.
 insert into public.bb_cancelled_bank_transaction_ids(transaction_id,cancelled_at)
 select upper(trim(t.transaction_id)),now()
 from public.bb_verified_bank_transactions t
 where t.transaction_id=v_id and t.status='AVAILABLE'
 on conflict(transaction_id) do nothing;
 if not found then
   if not exists(select 1 from public.bb_verified_bank_transactions t where t.transaction_id=v_id and t.status='AVAILABLE')
   then raise exception 'Only unused registered transactions can be cancelled'; end if;
 end if;
 delete from public.bb_verified_bank_transactions
 where transaction_id=v_id and status='AVAILABLE';
 if not found then raise exception 'Only unused registered transactions can be cancelled'; end if;
 INSERT INTO public.bb_audit_log(actor_user_id,actor_staff_id,actor_name,module,action,
  record_type,record_id,reference_no,reason,before_state,after_state,metadata)
 VALUES(auth.uid(),public.bb_actor_staff_id(),coalesce(nullif(public.bb_actor_name(),''),'Admin'),
   'bank_register','BANK_CANCELLED_UNUSED','bb_verified_bank_transactions',v_id,v_id,
   'Unused registered bank transfer cancelled before any financial posting',
   jsonb_build_object('customer_id',v_tx.customer_id,'amount',v_tx.amount,'currency',v_tx.currency,
      'received_date',v_tx.received_date,'payer',v_tx.payer_name,'bank',v_tx.bank_name,
      'status',v_tx.status,'outlet_shares',v_split),
   jsonb_build_object('status','CANCELLED','reserved_id',true),
   jsonb_build_object('no_payments',true,'no_allocations',true));
 return jsonb_build_object('success',true);
end $function$;

CREATE OR REPLACE FUNCTION public.bb_bank_review_inspect_v2(p_transaction_ids text[], p_customer_ids text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_duplicates jsonb;v_balances jsonb;v_ar jsonb;
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN
  RAISE EXCEPTION 'Bank analysis is server-only';
 END IF;
 IF coalesce(array_length(p_transaction_ids,1),0)>100 OR coalesce(array_length(p_customer_ids,1),0)>100
 THEN RAISE EXCEPTION 'Bank review analysis request too large';END IF;
 WITH all_ref AS(
  SELECT upper(trim(transaction_id)) tid,'Bank Register' source FROM public.bb_verified_bank_transactions
  UNION ALL SELECT upper(trim(coalesce(transaction_id,''))),'Payment History' FROM public.payments
  UNION ALL SELECT upper(trim(coalesce(collection_transaction_id,''))),'Company Deposit' FROM public.company_deposits
  UNION ALL SELECT upper(trim(x.transaction_id)),'Cancelled ID (financial history)' FROM public.bb_cancelled_bank_transaction_ids x
  WHERE EXISTS(SELECT 1 FROM public.payments p WHERE upper(trim(coalesce(p.transaction_id,'')))=upper(trim(x.transaction_id)))
    OR EXISTS(SELECT 1 FROM public.company_deposits d WHERE upper(trim(coalesce(d.collection_transaction_id,'')))=upper(trim(x.transaction_id)))
    OR EXISTS(SELECT 1 FROM public.purchase_payments p WHERE upper(trim(coalesce(p.transaction_id,'')))=upper(trim(x.transaction_id)))
    OR EXISTS(SELECT 1 FROM public.bb_bank_balance_allocations a WHERE upper(trim(a.transaction_id))=upper(trim(x.transaction_id)))
    OR EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE upper(trim(s.transaction_id))=upper(trim(x.transaction_id)))
  UNION ALL SELECT upper(trim(coalesce(transaction_id,''))),'Purchase Payment' FROM public.purchase_payments
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('transaction_id',tid,'source',source)),'[]'::jsonb)
 INTO v_duplicates FROM all_ref
 WHERE tid<>'' AND tid=ANY(p_transaction_ids);
 SELECT coalesce(jsonb_agg(jsonb_build_object('customer_id',customer_id,'currency',currency,
        'available',amount)),'[]'::jsonb)
 INTO v_balances FROM (
  SELECT customer_id,upper(currency) currency,sum(remaining_amount) amount
  FROM public.bb_bank_balance_snapshot
  WHERE customer_id=ANY(p_customer_ids) AND remaining_amount>0
  GROUP BY customer_id,upper(currency)
 ) b;
 SELECT coalesce(jsonb_agg(jsonb_build_object('customer_id',customer_id,'currency',currency,
        'outstanding',amount)),'[]'::jsonb)
 INTO v_ar FROM (
  SELECT customer_id,upper(currency) currency,sum(outstanding) amount
  FROM public.invoices
  WHERE customer_id=ANY(p_customer_ids) AND outstanding>0
  GROUP BY customer_id,upper(currency)
 ) i;
 RETURN jsonb_build_object('duplicates',v_duplicates,
   'available_bank_balances',v_balances,'outstanding_receivables',v_ar);
END
$function$;

CREATE OR REPLACE FUNCTION public.bb_bank_review_bulk_prepare_v2(p_batch_id uuid, p_reviewer text, p_admin_user uuid, p_choices jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_batch public.bb_bank_transaction_review_batches%ROWTYPE;
 v_entry jsonb;
 v_draft public.bb_bank_new_invoice_review_drafts%ROWTYPE;
 v_id uuid;
 v_selected boolean;
 v_customer text;
 v_tid text;
 v_sender text;
 v_cur text;
 v_date date;
 v_amt numeric;
 v_bank text;
 v_payer bigint;
 v_payer_name text;
 v_seen_ids uuid[] := '{}'::uuid[];
 v_seen_tx text[] := '{}'::text[];
 v_selected_count integer := 0;
 v_ignored integer := 0;
 v_usd numeric := 0;
 v_khr numeric := 0;
 v_n integer;
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN
  RAISE EXCEPTION 'Bank bulk preparation is server-only';
 END IF;
 IF p_batch_id IS NULL OR p_admin_user IS NULL OR p_reviewer !~ '^[0-9]{5,20}$'
   OR jsonb_typeof(p_choices) IS DISTINCT FROM 'array'
   OR jsonb_array_length(p_choices) NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION 'Invalid Bank Review batch or selection';
 END IF;
 IF NOT EXISTS(
  SELECT 1 FROM public.app_users u WHERE u.user_id=p_admin_user
   AND u.active=true AND lower(u.role)='admin'
 ) OR NOT EXISTS(
  SELECT 1 FROM public.bb_telegram_assistant_admins a WHERE a.telegram_user_id=p_reviewer
 ) THEN RAISE EXCEPTION 'Admin and reviewer authorization required'; END IF;
 SELECT * INTO v_batch
 FROM public.bb_bank_transaction_review_batches b
 WHERE b.batch_id=p_batch_id AND b.reviewer_telegram_user_id=p_reviewer
 FOR UPDATE;
 IF NOT FOUND OR v_batch.status<>'reviewing' OR v_batch.expires_at<=now()
    OR v_batch.review_session_id IS NULL THEN
  RAISE EXCEPTION 'An active explicit-session bank review is required';
 END IF;
 SELECT count(*) INTO v_n FROM public.bb_bank_new_invoice_review_drafts d
 WHERE d.review_batch_id=p_batch_id
 AND d.reviewer_telegram_user_id=p_reviewer AND d.status='reviewing';
 IF v_n<>jsonb_array_length(p_choices) THEN
  RAISE EXCEPTION 'Review selection is incomplete: expected % rows',v_n;
 END IF;
 FOR v_entry IN SELECT value FROM jsonb_array_elements(p_choices) LOOP
  IF (v_entry->>'draft_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     OR jsonb_typeof(v_entry->'selected') IS DISTINCT FROM 'boolean'
  THEN RAISE EXCEPTION 'Invalid transaction selection'; END IF;
  v_id:=(v_entry->>'draft_id')::uuid;
  IF v_id=ANY(v_seen_ids) THEN RAISE EXCEPTION 'Same draft selected twice'; END IF;
  v_seen_ids:=array_append(v_seen_ids,v_id);
  SELECT * INTO v_draft FROM public.bb_bank_new_invoice_review_drafts d
  WHERE d.draft_id=v_id AND d.review_batch_id=p_batch_id
   AND d.reviewer_telegram_user_id=p_reviewer AND d.status='reviewing'
  FOR UPDATE;
  IF NOT FOUND OR v_draft.registered_transaction_id IS NOT NULL THEN
   RAISE EXCEPTION 'Draft not available for review';
  END IF;
  v_selected:=(v_entry->>'selected')::boolean;
  IF NOT v_selected THEN
   UPDATE public.bb_bank_new_invoice_review_drafts SET
     review_decision='ignore',review_payload=NULL,
     reviewed_by_admin_user_id=p_admin_user,reviewed_at=now(),updated_at=now()
   WHERE draft_id=v_id;
   v_ignored:=v_ignored+1;
   CONTINUE;
  END IF;
  v_customer:=btrim(coalesce(v_entry->>'customer_id',''));
  v_tid:=upper(btrim(coalesce(v_entry->>'transaction_id','')));
  v_sender:=btrim(coalesce(v_entry->>'payer_name',''));
  v_cur:=upper(btrim(coalesce(v_entry->>'currency','')));
  v_bank:=left(btrim(coalesce(v_entry->>'bank_name','')),120);
  IF v_customer='' OR length(v_customer)>150 OR v_tid !~ '^[A-Z0-9_/-]{4,160}$'
    OR v_cur NOT IN('USD','KHR') OR v_tid=ANY(v_seen_tx)
  THEN RAISE EXCEPTION 'Customer, reference or currency missing/invalid on selected notice'; END IF;
  IF nullif(v_entry->>'amount','') IS NULL THEN RAISE EXCEPTION 'Amount required'; END IF;
  v_amt:=(v_entry->>'amount')::numeric;
  IF v_amt<=0 OR v_amt>999999999 OR v_amt<>round(v_amt,4)
  THEN RAISE EXCEPTION 'Invalid selected bank amount'; END IF;
  IF coalesce(v_entry->>'received_date','') !~ '^\d{4}-\d{2}-\d{2}$'
  THEN RAISE EXCEPTION 'Received date required'; END IF;
  v_date:=(v_entry->>'received_date')::date;
  IF v_date<DATE '2000-01-01'
    OR v_date>(now() AT TIME ZONE 'Asia/Phnom_Penh')::date
  THEN RAISE EXCEPTION 'Received date outside allowed range'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.customer_id=v_customer AND c.active)
  THEN RAISE EXCEPTION 'Select an active customer'; END IF;
  v_payer:=NULL;
  IF nullif(v_entry->>'payer_identity_id','') IS NOT NULL THEN
   v_payer:=(v_entry->>'payer_identity_id')::bigint;
   IF NOT EXISTS(
     SELECT 1 FROM public.bb_customer_bank_identities p
     WHERE p.identity_id=v_payer AND p.customer_id=v_customer AND p.active
   ) THEN RAISE EXCEPTION 'Saved payer is not active for chosen customer'; END IF;
   v_payer_name:=NULL;
  ELSE
   IF length(v_sender) NOT BETWEEN 2 AND 140
   THEN RAISE EXCEPTION 'Payer name required for one-time registration'; END IF;
   v_payer_name:=v_sender;
  END IF;
  -- Reject already-used references before the operator proceeds to final approval.
  -- The protected Bank Register RPC repeats these checks atomically during registration.
  IF EXISTS(SELECT 1 FROM public.bb_verified_bank_transactions x
      WHERE upper(btrim(x.transaction_id))=v_tid)
    OR EXISTS(SELECT 1 FROM public.payments x
      WHERE upper(btrim(coalesce(x.transaction_id,'')))=v_tid)
    OR EXISTS(SELECT 1 FROM public.company_deposits x
      WHERE upper(btrim(coalesce(x.collection_transaction_id,'')))=v_tid)
    OR EXISTS(SELECT 1 FROM public.bb_cancelled_bank_transaction_ids x
      WHERE upper(btrim(x.transaction_id))=v_tid AND
        (EXISTS(SELECT 1 FROM public.payments p WHERE upper(btrim(coalesce(p.transaction_id,'')))=v_tid)
         OR EXISTS(SELECT 1 FROM public.company_deposits d WHERE upper(btrim(coalesce(d.collection_transaction_id,'')))=v_tid)
         OR EXISTS(SELECT 1 FROM public.purchase_payments k WHERE upper(btrim(coalesce(k.transaction_id,'')))=v_tid)
         OR EXISTS(SELECT 1 FROM public.bb_bank_balance_allocations a WHERE upper(btrim(a.transaction_id))=v_tid)
         OR EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE upper(btrim(s.transaction_id))=v_tid)))
    OR EXISTS(SELECT 1 FROM public.purchase_payments x
      WHERE upper(btrim(coalesce(x.transaction_id,'')))=v_tid)
  THEN RAISE EXCEPTION 'Transaction ID % is already registered; unselect it',v_tid; END IF;
  v_seen_tx:=array_append(v_seen_tx,v_tid);
  UPDATE public.bb_bank_new_invoice_review_drafts
  SET review_decision='new_invoice',
    review_payload=jsonb_build_object(
      'customer_id',v_customer,'transaction_id',v_tid,'payer_identity_id',v_payer,
      'payer_name',v_payer_name,'amount',v_amt,'currency',v_cur,
      'invoice_currency',v_cur,'exchange_rate',1,'received_date',v_date,
      'bank_name',NULLIF(v_bank,'')
    ),
    reviewed_by_admin_user_id=p_admin_user,reviewed_at=now(),updated_at=now()
  WHERE draft_id=v_id;
  v_selected_count:=v_selected_count+1;
  IF v_cur='USD' THEN v_usd:=v_usd+v_amt;ELSE v_khr:=v_khr+v_amt;END IF;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'selected',v_selected_count,'ignored',v_ignored,
   'usd',v_usd,'khr',v_khr,'mode','manual_bulk_review');
END
$function$;
