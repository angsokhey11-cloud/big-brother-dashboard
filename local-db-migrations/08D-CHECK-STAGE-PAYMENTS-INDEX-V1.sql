-- BIG BROTHER Local Brain V5/V6 — Cloud -> Local STAGING ONLY.
-- Delivered through Code Sync source. Invoked at Step 6 after 08B creates
-- bb_cloud_stage and BEFORE COPY loads Cloud business records.
-- Safe scope: checks permanent public.* schema READ-ONLY, and removes ONLY an
-- obsolete UNIQUE lower(trim(transaction_id)) index on bb_cloud_stage.payments.
-- No INSERT, UPDATE, DELETE, TRUNCATE or ALTER on public business tables.
-- No weakening of the verified Bank Register's registration duplicate guard.
--
-- Requires earlier Code Sync migrations:
-- 20261025_payment_transaction_index_cloud_parity_v1
-- 20261025_bank_partial_use_cloud_parity_v1
BEGIN;

DO $bb_stage_bank_check$
DECLARE
  v_public regclass := to_regclass('public.payments');
  v_stage regclass := to_regclass('bb_cloud_stage.payments');
  v_row record;
  v_expr text;
  v_fingerprint text;
  v_removed integer := 0;
  v_lookup_count integer := 0;
BEGIN
  IF v_public IS NULL OR v_stage IS NULL THEN
    RAISE EXCEPTION 'BANK_STAGE_STOP: public.payments or bb_cloud_stage.payments missing. Check Code Sync and 08B before COPY.';
  END IF;

  -- Stage must carry invoice/payment identities, not just raw reference values.
  IF NOT EXISTS(
    SELECT 1 FROM pg_attribute a WHERE a.attrelid=v_stage
      AND a.attname='payment_id' AND a.attnum>0 AND NOT a.attisdropped
  ) OR NOT EXISTS(
    SELECT 1 FROM pg_attribute a WHERE a.attrelid=v_stage
      AND a.attname='transaction_id' AND a.attnum>0 AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION 'BANK_STAGE_STOP: stage payments key/reference columns missing';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM pg_index i
    WHERE i.indrelid=v_public AND i.indisprimary AND i.indisunique AND i.indisvalid
  ) THEN
    RAISE EXCEPTION 'BANK_STAGE_STOP: Local payments primary-key protection not verified';
  END IF;

  -- Permanent Local schema belongs to CODE SYNC. NEVER change it here.
  FOR v_row IN
    SELECT ic.relname AS indexname, i.indisunique, i.indisprimary,
      pg_get_expr(i.indexprs,i.indrelid) AS expr
    FROM pg_index i
    JOIN pg_class ic ON ic.oid=i.indexrelid
    WHERE i.indrelid=v_public AND i.indisunique AND i.indexprs IS NOT NULL
  LOOP
    IF v_row.expr ILIKE '%transaction_id%' THEN
      RAISE EXCEPTION 'BANK_STAGE_STOP: Local public payments still has UNIQUE transaction reference index %. Run Code Sync and check 20261025_payment_transaction_index_cloud_parity_v1 report.',v_row.indexname;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_lookup_count FROM pg_index i
  JOIN pg_class ic ON ic.oid=i.indexrelid
  WHERE i.indrelid=v_public
    AND ic.relname='idx_payments_normalized_transaction_lookup'
    AND NOT i.indisunique AND i.indisvalid AND i.indisready
    AND pg_get_expr(i.indexprs,i.indrelid) ILIKE '%transaction_id%';
  IF v_lookup_count<>1 THEN
    RAISE EXCEPTION 'BANK_STAGE_STOP: Local non-unique transaction lookup index missing. Run payment index Code Sync first.';
  END IF;

  IF to_regprocedure('private.bb_bank_guard_payment()') IS NULL OR
     position('bb_bank_balance_allocations' IN
       pg_get_functiondef('private.bb_bank_guard_payment()'::regprocedure))=0 THEN
    RAISE EXCEPTION 'BANK_STAGE_STOP: Local partial-use allocation payment guard not installed. Run bank partial-use Code Sync first.';
  END IF;

  -- 08B may have cloned an old UNIQUE index from Local or recreated it by name.
  -- Safely remove only the matching INDEX in the isolated staging schema.
  -- All other indexes, especially payment_id primary-key indexes, stay intact.
  FOR v_row IN
    SELECT ns.nspname AS schema_name, ic.relname AS indexname,
      i.indisunique, i.indisprimary, i.indnkeyatts, i.indisvalid,
      am.amname AS access_method,
      pg_get_expr(i.indexprs,i.indrelid) AS expr,
      EXISTS(SELECT 1 FROM pg_constraint c WHERE c.conindid=i.indexrelid) AS backed_by_constraint
    FROM pg_index i
    JOIN pg_class ic ON ic.oid=i.indexrelid
    JOIN pg_namespace ns ON ns.oid=ic.relnamespace
    JOIN pg_am am ON am.oid=ic.relam
    WHERE i.indrelid=v_stage
      AND i.indisunique
      AND i.indexprs IS NOT NULL
  LOOP
    IF v_row.expr ILIKE '%transaction_id%' THEN
      v_fingerprint:=regexp_replace(lower(v_row.expr),'[^a-z0-9_]','','g');
      IF v_row.schema_name<>'bb_cloud_stage'
        OR v_row.indisprimary OR v_row.indnkeyatts<>1
        OR v_row.access_method<>'btree' OR NOT v_row.indisvalid
        OR v_row.backed_by_constraint
        OR v_fingerprint !~ '^lower(btrim|trimbothfrom|trim)transaction_id(text)?$' THEN
        RAISE EXCEPTION 'BANK_STAGE_STOP: unknown UNIQUE index % expression %. No index removed.',v_row.indexname,v_row.expr;
      END IF;
      EXECUTE format('DROP INDEX %I.%I',v_row.schema_name,v_row.indexname);
      v_removed:=v_removed+1;
      RAISE NOTICE 'BANK_STAGE_PARITY: dropped obsolete UNIQUE index % from temporary bb_cloud_stage.payments ONLY',v_row.indexname;
    END IF;
  END LOOP;

  IF EXISTS(
    SELECT 1 FROM pg_index i
    WHERE i.indrelid=v_stage AND i.indisunique AND i.indexprs IS NOT NULL
      AND pg_get_expr(i.indexprs,i.indrelid) ILIKE '%transaction_id%'
  ) THEN
    RAISE EXCEPTION 'BANK_STAGE_STOP: incompatible UNIQUE transaction index remains in stage; COPY must not proceed';
  END IF;

  RAISE NOTICE 'BANK_STAGE_PARITY_OK: removed % obsolete stage index(es), Local permanent index and partial-use guard verified, business data unchanged',v_removed;
END $bb_stage_bank_check$;

COMMIT;
