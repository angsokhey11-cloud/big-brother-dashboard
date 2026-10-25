-- BIG BROTHER Local Brain V5/V6 — Registered Bank Partial-Use Parity.
-- CODE SYNC ONLY; Cloud -> Local exclusively migrates BUSINESS DATA.
-- PRECONDITION: earlier 20261016 bank migration + payment index parity migration.
-- No changes to public.payments, verified transaction or allocation BUSINESS ROWS.
--
-- Supports: same verified transaction across multiple partial applications,
-- Invoice Generator and A/R, verified amount/remaining balance checks,
-- manual Sync Bank, and USD/KHR exchange conversion.
DO $bb_local_wallet_preflight$
DECLARE
  obj text;
  v_col_name text;
  target text;
  def text;
  viewdef text;
BEGIN
  FOREACH obj IN ARRAY ARRAY[
    'public.payments','public.bb_verified_bank_transactions',
    'public.bb_bank_balance_allocations','public.bb_bank_balance_snapshot',
    'public.customers'
  ] LOOP
    IF to_regclass(obj) IS NULL THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: required relation % missing',obj;
    END IF;
  END LOOP;
  IF to_regprocedure('private.bb_bank_guard_payment()') IS NULL OR
     to_regprocedure('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)') IS NULL OR
     to_regprocedure('public.bb_has_module_access(text,text)') IS NULL OR
     to_regprocedure('public.bb_is_admin()') IS NULL OR
     to_regprocedure('public.bb_has_location_access(text)') IS NULL THEN
     RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: required bank/auth functions missing';
  END IF;

  FOREACH target IN ARRAY ARRAY['public.payments','public.bb_verified_bank_transactions','public.bb_bank_balance_allocations'] LOOP
    IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=split_part(target,'.',2) AND c.relkind='r') THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: expected base table % missing',target;
    END IF;
  END LOOP;

  FOR target,v_col_name IN SELECT v.tab,v.col FROM (VALUES
     ('payments','payment_id'),('payments','payment_source'),
     ('payments','actual_bank_amount'),('payments','actual_bank_currency'),
     ('payments','approved_bank_rate'),('payments','transaction_id'),
     ('payments','bank_payment'),('payments','exchange_rate'),
     ('bb_verified_bank_transactions','transaction_id'),
     ('bb_verified_bank_transactions','status'),
     ('bb_verified_bank_transactions','customer_id'),
     ('bb_verified_bank_transactions','used_payment_id'),
     ('bb_verified_bank_transactions','invoice_currency'),
     ('bb_verified_bank_transactions','approved_exchange_rate'),
     ('bb_bank_balance_allocations','transaction_id'),
     ('bb_bank_balance_allocations','allocation_id'),
     ('bb_bank_balance_allocations','payment_id'),
     ('bb_bank_balance_allocations','payment_source'),
     ('bb_bank_balance_allocations','applied_bank_amount'),
     ('bb_bank_balance_allocations','applied_invoice_amount'),
     ('bb_bank_balance_allocations','invoice_currency'),
     ('bb_bank_balance_allocations','reversed_at')
   ) AS v(tab,col) LOOP
    IF NOT EXISTS(
       SELECT 1 FROM information_schema.columns c
       WHERE c.table_schema='public' AND c.table_name=target
         AND c.column_name=v_col_name
    ) THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: missing column %.%',target,v_col_name;
    END IF;
  END LOOP;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger t
    WHERE t.tgrelid='public.payments'::regclass
      AND t.tgname='bb_bank_guard_payment_insert'
      AND t.tgfoid='private.bb_bank_guard_payment()'::regprocedure
      AND t.tgenabled IN ('O','A')) THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: payment insert guard missing, disabled, or redirected';
  END IF;
  SELECT pg_get_viewdef('public.bb_bank_balance_snapshot'::regclass,true)
    INTO viewdef;
  IF viewdef IS NULL OR position('bb_bank_balance_allocations' IN viewdef)=0
      OR position('reversed_at' IN viewdef)=0
      OR position('remaining_amount' IN viewdef)=0 THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: expected partial balance snapshot view missing/mismatched';
  END IF;

  SELECT pg_get_functiondef('private.bb_bank_guard_payment()'::regprocedure)
    INTO def;
  IF NOT (position('pg_advisory_xact_lock' IN def)>0
      AND position('bb_verified_bank_transactions' IN def)>0
      AND position('bb_is_admin' IN def)>0) THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: unknown legacy payment guard — no automatic overwrite';
  END IF;
  IF position('bb_bank_balance_allocations' IN def)=0
      AND NOT (position('status=''USED''' IN def)>0
             AND position('Bank Transaction ID' IN def)>0) THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: legacy guard not the vetted full-use variant';
  END IF;
  SELECT pg_get_functiondef('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)'::regprocedure)
    INTO def;
  IF position('bb_verified_bank_transactions' IN def)=0
     OR position('bb_is_admin' IN def)=0
     OR position('Invoice Generator access required' IN def)=0 THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: invoice bank validator unexpectedly changed';
  END IF;
  -- List/bulk RPCs may already exist. Preserve the correct permission boundary
  -- and refuse to overwrite unfamiliar local customizations.
  IF to_regprocedure('public.bb_customer_bank_balance_list_v2(text)') IS NOT NULL THEN
    SELECT pg_get_functiondef('public.bb_customer_bank_balance_list_v2(text)'::regprocedure) INTO def;
    IF position('bb_bank_balance_snapshot' IN def)=0
      OR position('bb_has_location_access' IN def)=0
      OR position('Bank balance access denied' IN def)=0 THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: unexpected customer balance list RPC';
    END IF;
  END IF;
  IF to_regprocedure('public.bb_invoice_bank_bulk_sync()') IS NOT NULL THEN
    SELECT pg_get_functiondef('public.bb_invoice_bank_bulk_sync()'::regprocedure) INTO def;
    IF position('bb_bank_balance_snapshot' IN def)=0
       OR position('bb_has_module_access' IN def)=0
       OR position('Invoice Generator access required' IN def)=0 THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: unexpected bulk Sync Bank RPC';
    END IF;
  END IF;
  -- The verified Bank Register keeps unique transaction registration, whereas
  -- several PAYMENTS can consume one registered balance.
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname='public' AND tablename='bb_verified_bank_transactions'
      AND indexname='bb_bank_tx_normalized'
      AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
  ) AND NOT EXISTS(
    SELECT 1 FROM pg_indexes
    WHERE schemaname='public' AND tablename='bb_verified_bank_transactions'
      AND indexname='bb_verified_bank_tx_normalized'
      AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
  ) THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: verified bank registration duplicate guard missing';
  END IF;

  -- Existing protection functions may already be installed: never overwrite an
  -- unknown local customization without first reviewing it.
  IF to_regprocedure('private.bb_bank_guard_wallet_payment_changes()') IS NOT NULL THEN
    SELECT pg_get_functiondef('private.bb_bank_guard_wallet_payment_changes()'::regprocedure) INTO def;
    IF position('bb_bank_balance_allocations' IN def)=0
       OR position('cannot be deleted' IN def)=0 THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: unknown wallet edit/delete protection';
    END IF;
  END IF;
  IF to_regprocedure('private.bb_bank_protect_verified_payment_update()') IS NOT NULL THEN
    SELECT pg_get_functiondef('private.bb_bank_protect_verified_payment_update()'::regprocedure) INTO def;
    IF position('bb_verified_bank_transactions' IN def)=0
       OR position('used_payment_id' IN def)=0 THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: unknown verified payment edit protection';
    END IF;
  END IF;
  IF to_regprocedure('private.bb_bank_protect_payment_update()') IS NOT NULL THEN
    SELECT pg_get_functiondef('private.bb_bank_protect_payment_update()'::regprocedure) INTO def;
    IF position('Bank Transaction ID cannot be replaced' IN def)=0 THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: unexpected payment transaction ID update guard';
    END IF;
  END IF;

  -- Do not install multiple triggers that could debit the same wallet twice.
  IF EXISTS (SELECT 1 FROM pg_trigger t
    WHERE t.tgrelid='public.payments'::regclass AND NOT t.tgisinternal
      AND t.tgname IN ('bb_bank_guard_wallet_payment_changes',
         'bb_bank_protect_verified_payment_edit','bb_bank_protect_payment_tx_update')
      AND t.tgenabled NOT IN ('O','A')) THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: existing bank protection trigger disabled';
  END IF;
END $bb_local_wallet_preflight$;

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
 if nullif(new.customer_id,'') is null or new.customer_id<>reg.customer_id then
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
 if remains<=0 or debit>remains+tolerance then
   raise exception 'Bank balance insufficient: remaining % %',greatest(remains,0),reg.currency;
 end if;
 debit:=least(debit,remains);
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
 if reg.status<>'AVAILABLE' or reg.customer_id<>p_customer_id
   or reg.currency<>actual_cur or p_actual_amount is null or p_actual_amount<=0 then return false; end if;
 rate:=case when reg.currency=cur then 1
     when coalesce(reg.approved_exchange_rate,0)>1 then reg.approved_exchange_rate
     else p_exchange_rate end;
 if reg.currency<>cur and (rate is null or rate<=1 or p_exchange_rate is null
     or abs(rate-p_exchange_rate)>0.000001) then return false; end if;
 debit:=case when reg.currency=cur then p_equivalent_amount
   when reg.currency='KHR' then p_equivalent_amount*rate
   else p_equivalent_amount/rate end;
 select coalesce(sum(applied_bank_amount),0) into spent from public.bb_bank_balance_allocations
   where transaction_id=reg.transaction_id and reversed_at is null;
 remaining:=reg.amount-spent;
 tol:=case when reg.currency='KHR' then 0.5 else 0.005 end;
 return remaining>0 and debit>0 and debit<=remaining+tol and
  (abs(p_actual_amount-reg.amount)<=tol or abs(p_actual_amount-debit)<=tol
   or abs(p_actual_amount-remaining)<=tol);
end $function$;


CREATE OR REPLACE FUNCTION private.bb_bank_guard_wallet_payment_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if exists(select 1 from public.bb_bank_balance_allocations a where a.payment_id=old.payment_id and a.reversed_at is null) then
  if tg_op='UPDATE' then
   if old.customer_id is distinct from new.customer_id or old.amount is distinct from new.amount
   or old.currency is distinct from new.currency or old.exchange_rate is distinct from new.exchange_rate
   or old.transaction_id is distinct from new.transaction_id or old.payment_method is distinct from new.payment_method
   or old.bank_payment is distinct from new.bank_payment then
    raise exception 'Verified bank wallet usage cannot be edited; reverse and recreate the payment';end if;
   return new;
  end if;
  raise exception 'Verified bank wallet payment cannot be deleted without an audited reversal';
 end if;
 return case when tg_op='UPDATE' then new else old end;
end $function$;


CREATE OR REPLACE FUNCTION private.bb_bank_protect_verified_payment_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare reg public.bb_verified_bank_transactions%rowtype;
expected numeric;inv text;
begin
if exists(select 1 from public.bb_bank_balance_allocations a where a.payment_id=old.payment_id and a.reversed_at is null) then return new;end if;
if lower(trim(coalesce(old.payment_method,'')))<>'bank' then return new;end if;
select * into reg from public.bb_verified_bank_transactions where used_payment_id=old.payment_id and status='USED';
if not found then return new;end if;
inv:=coalesce(reg.invoice_currency,reg.currency);
expected:=case when reg.currency=inv then reg.amount when reg.currency='KHR' then reg.amount/reg.approved_exchange_rate else reg.amount*reg.approved_exchange_rate end;
if coalesce(new.customer_id,'')<>reg.customer_id or upper(trim(coalesce(new.currency,'')))<>inv or
abs(coalesce(new.amount,0)-expected)>(case when inv='KHR' then 0.5 else 0.005 end) or
upper(trim(coalesce(new.transaction_id,'')))<>upper(trim(reg.transaction_id)) or
lower(trim(coalesce(new.payment_method,'')))<>'bank' or
(reg.currency<>inv and abs(coalesce(new.exchange_rate,0)-reg.approved_exchange_rate)>0.000001) or
(reg.bank_name is not null and lower(trim(coalesce(new.bank_payment,'')))<>lower(trim(reg.bank_name))) then
raise exception 'This bank payment has an applied verified transaction. Cancel/reconcile it through an authorized correction workflow.';
end if;
return new;
end $function$;


CREATE OR REPLACE FUNCTION private.bb_bank_protect_payment_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    declare
      v_history_correction boolean :=
        coalesce(current_setting('bb.invoice_history_correction', true),'') = 'on';
    begin
      if coalesce(lower(trim(old.transaction_id)),'') <>
         coalesce(lower(trim(new.transaction_id)),'')
         and nullif(trim(coalesce(old.transaction_id,'')),'') is not null then
        raise exception 'Bank Transaction ID cannot be replaced after payment creation. Use the audited reversal and new payment process.';
      end if;

      if nullif(trim(coalesce(new.transaction_id,'')),'') is not null
         and coalesce(lower(trim(old.transaction_id)),'') <>
             coalesce(lower(trim(new.transaction_id)),'')
         and not v_history_correction then
        raise exception 'Adding a bank Transaction ID to an existing payment is not permitted. Record a new payment.';
      end if;

      return new;
    end
    $function$;


CREATE OR REPLACE FUNCTION public.bb_customer_bank_balance_list_v2(p_customer_id text)
 RETURNS TABLE(transaction_id text, original_amount numeric, used_amount numeric, remaining_amount numeric, currency text, invoice_currency text, approved_exchange_rate numeric, received_date date, equivalent_remaining numeric, bank_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_location text;
begin
 if not (public.bb_has_module_access('invoice_generator','create') or public.bb_has_module_access('accounts_receivable','edit') or public.bb_is_admin()) then raise exception 'Bank balance access denied';end if;
 select location_code into v_location from public.customers where customer_id=p_customer_id and active=true;
 if not found then return;end if;
 if not public.bb_is_admin() and not public.bb_has_location_access(coalesce(v_location,'')) then raise exception 'Customer location access denied';end if;
 return query
 select b.transaction_id,b.original_amount,b.used_amount,b.remaining_amount,b.currency,coalesce(b.invoice_currency,b.currency),b.approved_exchange_rate,b.received_date,
 case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0) else b.remaining_amount*b.approved_exchange_rate end,t.bank_name
 from public.bb_bank_balance_snapshot b join public.bb_verified_bank_transactions t on t.transaction_id=b.transaction_id
 where b.customer_id=p_customer_id and b.status='AVAILABLE' and b.remaining_amount>0 order by b.received_date,b.transaction_id;
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
 left join public.bb_verified_bank_transactions t on t.transaction_id=b.transaction_id and t.customer_id=b.customer_id
 where b.status='AVAILABLE' and b.remaining_amount>0
 and (public.bb_is_admin() or public.bb_has_location_access(coalesce(c.location_code,'')));
 return v_data;
end $function$;


-- CREATE missing protection triggers only; never replace or disable unrelated
-- existing Local triggers (audit, updated_at, or permanent IDs).
DO $bb_wallet_triggers$
DECLARE
  trigger_name text;
  expected_function regprocedure;
  expected_def text;
  actual record;
BEGIN
  FOR trigger_name,expected_function,expected_def IN
    SELECT v.name,v.proc,v.ddl FROM (VALUES
     ('bb_bank_guard_wallet_payment_changes',
       'private.bb_bank_guard_wallet_payment_changes()'::regprocedure,
       'CREATE TRIGGER bb_bank_guard_wallet_payment_changes BEFORE DELETE OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION private.bb_bank_guard_wallet_payment_changes()'),
     ('bb_bank_protect_verified_payment_edit',
       'private.bb_bank_protect_verified_payment_update()'::regprocedure,
       'CREATE TRIGGER bb_bank_protect_verified_payment_edit BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION private.bb_bank_protect_verified_payment_update()'),
     ('bb_bank_protect_payment_tx_update',
       'private.bb_bank_protect_payment_update()'::regprocedure,
       'CREATE TRIGGER bb_bank_protect_payment_tx_update BEFORE UPDATE OF transaction_id ON public.payments FOR EACH ROW EXECUTE FUNCTION private.bb_bank_protect_payment_update()')
    ) v(name,proc,ddl)
  LOOP
    SELECT t.tgfoid,t.tgenabled,pg_get_triggerdef(t.oid) AS def INTO actual
    FROM pg_trigger t WHERE t.tgrelid='public.payments'::regclass
       AND t.tgname=trigger_name AND NOT t.tgisinternal;
    IF NOT FOUND THEN
      EXECUTE expected_def;
    ELSIF actual.tgfoid<>expected_function OR actual.tgenabled NOT IN ('O','A')
       OR position('ON public.payments' IN actual.def)=0 THEN
      RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: conflicting trigger %',trigger_name;
    END IF;
  END LOOP;
END $bb_wallet_triggers$;

-- Minimal API surface: authenticated users must pass the existing permission
-- checks inside each RPC. Never expose private trigger helpers.
REVOKE ALL ON FUNCTION private.bb_bank_guard_payment() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.bb_bank_guard_wallet_payment_changes() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.bb_bank_protect_payment_update() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.bb_bank_protect_verified_payment_update() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bb_customer_bank_balance_list_v2(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bb_invoice_bank_bulk_sync() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bb_customer_bank_balance_list_v2(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bb_invoice_bank_bulk_sync() TO authenticated;

DO $bb_wallet_verify$
DECLARE
  v_guard text;
  v_validator text;
  v_bulk text;
BEGIN
  SELECT pg_get_functiondef('private.bb_bank_guard_payment()'::regprocedure) INTO v_guard;
  SELECT pg_get_functiondef('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)'::regprocedure) INTO v_validator;
  SELECT pg_get_functiondef('public.bb_invoice_bank_bulk_sync()'::regprocedure) INTO v_bulk;
  IF position('insert into public.bb_bank_balance_allocations' IN v_guard)=0
    OR position('remaining % %' IN v_guard)=0
    OR position('Manual Bank Transaction ID is Admin-only' IN v_guard)=0
    OR position('reg.status' IN v_guard)=0
    OR position('insert into public.bb_bank_balance_allocations' IN v_validator)>0
    OR position('reversed_at is null' IN v_validator)=0
    OR position('remaining_amount' IN v_bulk)=0 THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: post-install function parity verification failed';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public'
      AND tablename='payments' AND indexname='idx_payments_normalized_transaction_lookup'
      AND indexdef NOT ILIKE 'CREATE UNIQUE INDEX%') THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: payment reference still uses incompatible unique index';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND tablename='bb_bank_balance_allocations'
      AND indexdef LIKE 'CREATE UNIQUE INDEX%payment_id%transaction_id%') THEN
    RAISE EXCEPTION 'CODE_SYNC_WALLET_STOP: one allocation per payment/transaction unique guard missing';
  END IF;
  RAISE NOTICE 'BANK_PARTIAL_USE_PARITY_OK: wallet consumption, remaining balances, invoice/A-R, and payment edit protection; NO BUSINESS ROWS ALTERED';
END $bb_wallet_verify$;
