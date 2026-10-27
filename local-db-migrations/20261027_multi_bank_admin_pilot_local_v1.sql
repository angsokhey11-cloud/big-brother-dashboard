-- BIG BROTHER LOCAL BRAIN V5 / V6 — ADMIN MULTI-BANK PAYMENT PARITY
-- CODE SYNC ONLY, via V3.4 Controller migration registry.
-- Cloud pilot verified with real invoice INV-6293 on 2026-10-27.
-- This is a schema/RPC/permission migration only. NO INSERT/UPDATE/DELETE
-- of existing invoices, payments, stock or registered bank transactions.
-- Do NOT use Cloud-to-Local business-data sync for this migration.
-- Local-only records remain untouched. SQL stops if schema differs.
--
-- Exact multi-bank save function and request-ledger DDL sourced from verified
-- Cloud Invoice Generator: sql/multi-bank-atomic-invoice-save-v1.sql
-- Do not change other existing functions, guards, stock triggers, or views.

DO $bb_local_multi_bank_preflight$
DECLARE
  v_relation text;
  v_signature text;
  v_guard text;
  v_old text;
BEGIN
  FOREACH v_relation IN ARRAY ARRAY[
     'public.invoices','public.invoice_lines','public.payments',
     'public.customers','public.bb_verified_bank_transactions',
     'public.bb_bank_balance_allocations','public.bb_bank_balance_snapshot'
  ] LOOP
    IF to_regclass(v_relation) IS NULL THEN
      RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: missing %',v_relation;
    END IF;
  END LOOP;
  FOREACH v_signature IN ARRAY ARRAY[
    'private.bb_bank_guard_payment()',
    'public.bb_sales_save_invoice_bundle_core_access_v1(jsonb,jsonb)',
    'public.bb_is_admin()',
    'public.bb_has_module_access(text,text)',
    'public.bb_has_sales_write()',
    'public.bb_has_location_access(text)',
    'public.bb_next_prefixed_id(regclass,text,text,integer)'
  ] LOOP
    IF to_regprocedure(v_signature) IS NULL THEN
      RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: missing function %',v_signature;
    END IF;
  END LOOP;
  IF NOT EXISTS(
     SELECT 1 FROM pg_trigger t
     WHERE t.tgrelid='public.payments'::regclass
       AND t.tgname='bb_bank_guard_payment_insert'
       AND t.tgfoid='private.bb_bank_guard_payment()'::regprocedure
       AND t.tgenabled IN ('O','A')
  ) THEN
    RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: bank allocation trigger missing or inactive';
  END IF;
  SELECT pg_get_functiondef('private.bb_bank_guard_payment()'::regprocedure)
  INTO v_guard;
  IF position('bb_bank_balance_allocations' in v_guard)=0 OR
     position('pg_advisory_xact_lock' in v_guard)=0 OR
     position('bb_verified_bank_transactions' in v_guard)=0 THEN
    RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: bank guard is not the vetted partial-use version';
  END IF;
  IF position('bb_bank_balance_allocations' in
    pg_get_viewdef('public.bb_bank_balance_snapshot'::regclass,true))=0 THEN
    RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: partial-use balance view incompatible';
  END IF;
  IF EXISTS(
     SELECT 1 FROM pg_index i
     WHERE i.indrelid='public.payments'::regclass
       AND i.indisunique
       AND pg_get_indexdef(i.indexrelid) ILIKE '%transaction_id%'
  ) THEN
    RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: unique payment transaction index blocks partial bank reuse';
  END IF;
  IF to_regclass('public.bb_invoice_multi_bank_requests') IS NOT NULL THEN
    IF NOT EXISTS (
       SELECT 1 FROM pg_class c WHERE c.oid='public.bb_invoice_multi_bank_requests'::regclass
          AND c.relkind='r' AND c.relrowsecurity=true
    ) THEN
      RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: existing request ledger is not RLS-protected';
    END IF;
  END IF;
  IF to_regprocedure('public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)') IS NOT NULL THEN
    v_old:=pg_get_functiondef('public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)'::regprocedure);
    IF position('Multi-bank invoice pilot is Admin-only' in v_old)=0
      OR position('v_fallback_bank' in v_old)=0
      OR position('bb_bank_balance_allocations' in v_old)=0 THEN
      RAISE EXCEPTION 'LOCAL_MULTI_BANK_SAFE_STOP: unknown existing multi-bank RPC; no overwrite';
    END IF;
  END IF;
END $bb_local_multi_bank_preflight$;

create table if not exists public.bb_invoice_multi_bank_requests (
 request_id uuid primary key,
 actor_user_id uuid not null,
 payload_fingerprint text not null,
 invoice_id text not null unique references public.invoices(invoice_id),
 response jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.bb_invoice_multi_bank_requests enable row level security;
revoke all on public.bb_invoice_multi_bank_requests from public,anon,authenticated;

create or replace function public.bb_sales_save_invoice_multi_bank_v1(
 p_invoice jsonb,
 p_payment jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $fn$
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
      or v_source.customer_id<>v_customer or v_source.currency<>v_currency then
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
                       where s.transaction_id=v_source.transaction_id),0) then
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
end $fn$;

-- V5/V6 Local pilot: authenticated role MAY call RPC, but server-side
-- public.bb_is_admin() + invoice create + location checks restrict it to admin.
-- Anonymous roles must never be able to invoke the money/stock transaction.
REVOKE ALL ON FUNCTION public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)
  FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)
  TO authenticated;

DO $bb_local_multi_bank_verify$
DECLARE v_definition text;
BEGIN
 IF NOT EXISTS(
   SELECT 1 FROM pg_class c WHERE c.oid='public.bb_invoice_multi_bank_requests'::regclass
     AND c.relrowsecurity=true
 ) THEN RAISE EXCEPTION 'LOCAL_MULTI_BANK_VERIFY_FAIL: request ledger RLS missing'; END IF;
 IF has_table_privilege('authenticated','public.bb_invoice_multi_bank_requests','SELECT')
     OR has_function_privilege('anon','public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)','EXECUTE') THEN
   RAISE EXCEPTION 'LOCAL_MULTI_BANK_VERIFY_FAIL: unexpected table/RPC permissions';
 END IF;
 v_definition:=pg_get_functiondef('public.bb_sales_save_invoice_multi_bank_v1(jsonb,jsonb)'::regprocedure);
 IF position('Multi-bank invoice pilot is Admin-only' in v_definition)=0
     OR position('v_fallback_bank' in v_definition)=0
     OR position('bb_sales_save_invoice_bundle_core_access_v1' in v_definition)=0 THEN
   RAISE EXCEPTION 'LOCAL_MULTI_BANK_VERIFY_FAIL: expected cloud pilot function not installed';
 END IF;
 RAISE NOTICE 'LOCAL_MULTI_BANK_ADMIN_PILOT_READY (no business rows altered)';
END $bb_local_multi_bank_verify$;
