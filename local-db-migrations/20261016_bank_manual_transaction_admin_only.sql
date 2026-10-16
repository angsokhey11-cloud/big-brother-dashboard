-- BIG BROTHER V3.4 | Approved Local Bank Security Migration | 2026-10-16
-- Keep registered customer bank balances OPTIONAL: staff chooses Use, never auto-apply.
-- Admin alone can enter a NEW/unregistered bank Transaction ID.
-- Existing registered transactions remain usable by authorized staff through selection.
-- Alter ONLY two existing function bodies. No transaction, invoice, or customer row updates.
-- Local controller must make a backup and use psql --single-transaction.
DO $bb_bank_migration$
DECLARE
  v_validation text;
  v_guard text;
  v_validation_old text := $valid_old$select * into reg from public.bb_verified_bank_transactions where upper(trim(transaction_id))=upper(trim(coalesce(p_transaction_id,''))) and status='AVAILABLE';
 if not found then return public.bb_is_admin();end if;$valid_old$;
  v_validation_optional text := $valid_opt$select * into reg from public.bb_verified_bank_transactions where upper(trim(transaction_id))=upper(trim(coalesce(p_transaction_id,'')));
 if not found then
   -- Manually entered new transfers do not consume a registered customer balance.
   return nullif(trim(coalesce(p_transaction_id,'')),'') is not null
     and coalesce(p_equivalent_amount,0)>0;
 end if;$valid_opt$;
  v_validation_locked text := $valid_locked$select * into reg from public.bb_verified_bank_transactions where upper(trim(transaction_id))=upper(trim(coalesce(p_transaction_id,'')));
 if not found then
   -- Manually entered new transfers do not consume a registered customer balance.
   return public.bb_is_admin()
     and nullif(trim(coalesce(p_transaction_id,'')),'') is not null
     and coalesce(p_equivalent_amount,0)>0;
 end if;
 if reg.status<>'AVAILABLE' then return false;end if;$valid_locked$;
  v_guard_old text := $guard_old$ if not found then
  if source='INVOICE' and not public.bb_is_admin() then
   raise exception 'Bank Transaction ID not verified. Ask Admin to register this payment.';
  end if;
  return new;
 end if;$guard_old$;
  v_guard_optional text := $guard_opt$ if not found then
  -- A new manual transfer is separate from all registered customer wallet balances.
  -- The duplicate ID and company-deposit safeguards above remain active.
  return new;
 end if;$guard_opt$;
  v_guard_locked text := $guard_locked$ if not found then
  -- New (unregistered) bank Transaction IDs may only be entered by Admin.
  -- Registered transactions remain optional and are never applied implicitly.
  if not public.bb_is_admin() then
   raise exception 'Manual Bank Transaction ID is Admin-only. Staff must choose an Admin-registered bank payment.';
  end if;
  return new;
 end if;$guard_locked$;
  v_val_changed boolean := false;
  v_guard_changed boolean := false;
BEGIN
  IF to_regprocedure('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)') IS NULL
     OR to_regprocedure('private.bb_bank_guard_payment()') IS NULL
     OR to_regprocedure('public.bb_is_admin()') IS NULL
     OR to_regclass('public.bb_verified_bank_transactions') IS NULL
     OR to_regclass('public.bb_bank_balance_allocations') IS NULL THEN
    RAISE EXCEPTION 'LOCAL BANK LOCK STOPPED: required functions or bank balance tables are missing';
  END IF;
  SELECT pg_get_functiondef('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)'::regprocedure)
    INTO v_validation;
  SELECT pg_get_functiondef('private.bb_bank_guard_payment()'::regprocedure)
    INTO v_guard;
  IF position('bb_bank_balance_allocations' IN v_validation)=0
    OR position('p_customer_id' IN v_validation)=0
    OR position('bb_bank_balance_allocations' IN v_guard)=0
    OR position('pg_advisory_xact_lock' IN v_guard)=0
    OR position('reg.customer_id' IN v_guard)=0
    OR position('reg.status' IN v_guard)=0 THEN
    RAISE EXCEPTION 'LOCAL BANK LOCK STOPPED: existing bank safeguards differ from audited version';
  END IF;
  IF position(v_validation_locked IN v_validation)>0 THEN
    NULL; -- Already correctly locked; safe to skip.
  ELSIF position(v_validation_old IN v_validation)>0 THEN
    v_validation := replace(v_validation,v_validation_old,v_validation_locked);
    v_val_changed := true;
  ELSIF position(v_validation_optional IN v_validation)>0 THEN
    v_validation := replace(v_validation,v_validation_optional,v_validation_locked);
    v_val_changed := true;
  ELSE
    RAISE EXCEPTION 'LOCAL BANK LOCK STOPPED: validator function changed; review before applying';
  END IF;
  IF position(v_guard_locked IN v_guard)>0 THEN
    NULL; -- Already correctly locked; safe to skip.
  ELSIF position(v_guard_old IN v_guard)>0 THEN
    v_guard := replace(v_guard,v_guard_old,v_guard_locked);
    v_guard_changed := true;
  ELSIF position(v_guard_optional IN v_guard)>0 THEN
    v_guard := replace(v_guard,v_guard_optional,v_guard_locked);
    v_guard_changed := true;
  ELSE
    RAISE EXCEPTION 'LOCAL BANK LOCK STOPPED: payment trigger function changed; review before applying';
  END IF;
  IF v_val_changed THEN EXECUTE v_validation; END IF;
  IF v_guard_changed THEN EXECUTE v_guard; END IF;
  SELECT pg_get_functiondef('public.bb_bank_validate_invoice_input(text,text,numeric,text,text,numeric,numeric)'::regprocedure)
    INTO v_validation;
  SELECT pg_get_functiondef('private.bb_bank_guard_payment()'::regprocedure)
    INTO v_guard;
  IF position(v_validation_locked IN v_validation)=0
    OR position(v_guard_locked IN v_guard)=0 THEN
    RAISE EXCEPTION 'LOCAL BANK LOCK STOPPED: post-install verification failed';
  END IF;
  RAISE NOTICE 'LOCAL_BANK_ADMIN_ONLY_LOCK_OK: validator_updated=%, trigger_updated=%',v_val_changed,v_guard_changed;
END
$bb_bank_migration$;
