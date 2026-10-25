-- BIG BROTHER Local Brain V5/V6: legacy Payment Transaction ID index parity.
-- CODE SYNC ONLY. NO BUSINESS DATA INSERTS, UPDATES OR DELETES.
--
-- Confirmed cloud: public.payments allows multiple payment_id rows to allocate
-- one bank transaction_id across invoices; only payment_id is globally unique.
-- The authoritative Cloud index is NON-UNIQUE
-- idx_payments_normalized_transaction_lookup(lower(trim(transaction_id))).
-- Old Local payments_lower_idx uniquely rejects those legitimate Cloud rows,
-- and 08B cloned its unique constraint into bb_cloud_stage.payments.
--
-- Only remove the exact obsolete normalized transaction expression UNIQUE index.
-- Keep payments_pkey, all foreign keys, and all Bank Register duplicate guards.
-- Run BEFORE Cloud -> Local via Code Sync manifest. Existing payments untouched.
DO $bb_payment_ref_parity$
DECLARE
  v_public_table regclass;
  v_old_index regclass;
  v_lookup_index regclass;
  v_old record;
  v_lookup record;
  v_expr text;
  v_compact text;
  v_rogue_index text;
BEGIN
  v_public_table:=to_regclass('public.payments');
  IF v_public_table IS NULL THEN
    RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: public.payments does not exist';
  END IF;

  -- A new ordinary lookup index remains available after removing the obsolete
  -- UNIQUE one. IF NOT EXISTS does not silently certify a wrong existing index:
  -- we verify its actual definition immediately below.
  CREATE INDEX IF NOT EXISTS idx_payments_normalized_transaction_lookup
    ON public.payments USING btree
      (lower(trim(transaction_id)))
    WHERE nullif(trim(coalesce(transaction_id,'')),'') IS NOT NULL;

  v_lookup_index:=to_regclass('public.idx_payments_normalized_transaction_lookup');
  SELECT i.indisunique,i.indisprimary,i.indisvalid,i.indisready,
         am.amname,pg_get_expr(i.indexprs,i.indrelid) AS expression,
         pg_get_expr(i.indpred,i.indrelid) AS predicate
    INTO v_lookup
  FROM pg_index i
  JOIN pg_class ic ON ic.oid=i.indexrelid
  JOIN pg_am am ON am.oid=ic.relam
  WHERE i.indexrelid=v_lookup_index AND i.indrelid=v_public_table;
  IF NOT FOUND OR v_lookup.indisunique OR v_lookup.indisprimary
     OR NOT v_lookup.indisvalid OR NOT v_lookup.indisready
     OR v_lookup.amname <> 'btree' OR v_lookup.predicate IS NULL THEN
    RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: normalized lookup index incompatible with Cloud';
  END IF;
  v_compact:=regexp_replace(lower(coalesce(v_lookup.expression,'')),'[^a-z0-9_]','','g');
  IF v_compact !~ '^lower(btrim|trimbothfrom|trim)transaction_id(text)?$' THEN
    RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: unexpected normalized lookup expression %',v_lookup.expression;
  END IF;

  v_old_index:=to_regclass('public.payments_lower_idx');
  IF v_old_index IS NOT NULL THEN
    SELECT i.indisunique,i.indisprimary,i.indisvalid,i.indisready,
           i.indnkeyatts,am.amname,
           pg_get_expr(i.indexprs,i.indrelid) AS expression
      INTO v_old
    FROM pg_index i
    JOIN pg_class ic ON ic.oid=i.indexrelid
    JOIN pg_am am ON am.oid=ic.relam
    WHERE i.indexrelid=v_old_index AND i.indrelid=v_public_table;
    IF NOT FOUND OR NOT v_old.indisunique OR v_old.indisprimary
       OR NOT v_old.indisvalid OR NOT v_old.indisready
       OR v_old.indnkeyatts <> 1 OR v_old.amname <> 'btree' THEN
      RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: payments_lower_idx is not the expected old UNIQUE index';
    END IF;
    v_compact:=regexp_replace(lower(coalesce(v_old.expression,'')),'[^a-z0-9_]','','g');
    IF v_compact !~ '^lower(btrim|trimbothfrom|trim)transaction_id(text)?$' THEN
      RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: refuse to drop unrelated index expression %',v_old.expression;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conindid=v_old_index) THEN
      RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: obsolete index is constraint-backed; manual schema review required';
    END IF;
    EXECUTE 'DROP INDEX public.payments_lower_idx';
    RAISE NOTICE 'LOCAL PAYMENT INDEX: removed legacy UNIQUE normalized transaction index only';
  ELSE
    RAISE NOTICE 'LOCAL PAYMENT INDEX: old payments_lower_idx already absent';
  END IF;

  -- No other accidentally UNIQUE expression index may still forbid multi-invoice
  -- bank allocations. Do not drop unknown indexes automatically.
  SELECT ic.relname INTO v_rogue_index
  FROM pg_index i
  JOIN pg_class ic ON ic.oid=i.indexrelid
  WHERE i.indrelid=v_public_table AND i.indisunique AND i.indexprs IS NOT NULL
    AND pg_get_expr(i.indexprs,i.indrelid) ILIKE '%transaction_id%'
  ORDER BY ic.relname LIMIT 1;
  IF v_rogue_index IS NOT NULL THEN
    RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: other UNIQUE transaction index % needs review',v_rogue_index;
  END IF;

  IF to_regclass('public.payments_pkey') IS NULL OR NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indexrelid='public.payments_pkey'::regclass
      AND i.indrelid=v_public_table AND i.indisprimary AND i.indisunique
  ) THEN
    RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: payment_id primary-key protection not verified';
  END IF;
  IF (SELECT count(*) FROM pg_constraint c
      WHERE c.conrelid=v_public_table AND c.contype='f') < 4 THEN
    RAISE EXCEPTION 'CODE_SYNC_PAYMENT_STOP: expected payment foreign keys not present';
  END IF;
  RAISE NOTICE 'LOCAL PAYMENT INDEX VERIFIED: unique payment_id preserved, normalized transaction reference is lookup-only, no payment rows changed.';
END $bb_payment_ref_parity$;
