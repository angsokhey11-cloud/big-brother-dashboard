-- BIG BROTHER Local Brain V5/V6 — observed dual legacy UNIQUE payment refs.
-- Versioned Code Sync only. NEVER run as ad hoc Cloud→Local repair.
-- Exact Local read-only diagnosis captured 2026-10-26 00:20:06:
-- public.payments unique normalized txn indexes:
--   uq_payments_transaction_id_normalized
--   ux_payments_transaction_id_ci
-- Temporary bb_cloud_stage.payments clones them to payments_lower_idx{,1}.
-- On Cloud, one verified bank transaction may pay multiple invoices,
-- payment_id stays PRIMARY KEY; Bank Register IDs remain separately UNIQUE.
-- This migration modifies INDEX SCHEMA ONLY; no payment, bank or expense rows.

DO $bb_dual_payment_index_preflight$
DECLARE
  t regclass:=to_regclass('public.payments');
  row_ record;
  name_ text;
  fp_expr text;
  fp_pred text;
  matched integer:=0;
BEGIN
  IF t IS NULL THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: public.payments missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid=t
      AND i.indisprimary AND i.indisunique AND i.indisvalid) THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: payment_id primary key not verified';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public'
    AND tablename='bb_verified_bank_transactions'
    AND indexname='bb_verified_bank_tx_normalized'
    AND indexdef ILIKE 'CREATE UNIQUE INDEX%') THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: Bank Register UNIQUE transaction guard not verified';
  END IF;

  -- Safety: every UNIQUE expression index referencing transaction_id must
  -- be one of the two signatures measured on the user's actual Local DB.
  -- Unknown definitions are NOT dropped.
  FOR row_ IN
    SELECT c.relname AS idx_name,
           n.nspname AS idx_schema,
           i.indexrelid,
           i.indisunique,i.indisprimary,i.indisvalid,i.indisready,
           i.indnkeyatts,am.amname AS method,
           pg_get_expr(i.indexprs,i.indrelid) AS expression,
           pg_get_expr(i.indpred,i.indrelid) AS predicate,
           EXISTS(SELECT 1 FROM pg_constraint co
                  WHERE co.conindid=i.indexrelid) AS bound_constraint
    FROM pg_index i
    JOIN pg_class c ON c.oid=i.indexrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_am am ON am.oid=c.relam
    WHERE i.indrelid=t AND i.indisunique AND i.indexprs IS NOT NULL
      AND pg_get_expr(i.indexprs,i.indrelid) ILIKE '%transaction_id%'
    ORDER BY c.relname
  LOOP
    fp_expr:=regexp_replace(lower(coalesce(row_.expression,'')),'[^a-z0-9_]','','g');
    fp_pred:=regexp_replace(lower(coalesce(row_.predicate,'')),'[^a-z0-9_]','','g');
    IF row_.idx_schema<>'public' OR row_.idx_name NOT IN
       ('uq_payments_transaction_id_normalized','ux_payments_transaction_id_ci')
       OR NOT row_.indisunique OR row_.indisprimary
       OR NOT row_.indisvalid OR NOT row_.indisready
       OR row_.indnkeyatts<>1 OR row_.method<>'btree'
       OR row_.bound_constraint
       OR fp_expr<>'lowertrimbothfromtransaction_id'
       OR (row_.idx_name='uq_payments_transaction_id_normalized'
           AND fp_pred<>'nulliftrimbothfromtransaction_idtextisnotnull')
       OR (row_.idx_name='ux_payments_transaction_id_ci'
           AND fp_pred<>'nulliftrimbothfromcoalescetransaction_idtexttextisnotnull')
    THEN
      RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: unrecognized index % expression % / predicate %',
        row_.idx_name,row_.expression,row_.predicate;
    END IF;
    matched:=matched+1;
  END LOOP;

  -- Code Sync may already have removed the legacy indexes. That is safe.
  IF matched>2 THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: unexpected multiple UNIQUE reference indexes';
  END IF;

  IF to_regclass('public.idx_payments_normalized_transaction_lookup') IS NOT NULL
     AND NOT EXISTS(SELECT 1 FROM pg_index i WHERE
         i.indexrelid='public.idx_payments_normalized_transaction_lookup'::regclass
         AND i.indrelid=t AND NOT i.indisunique AND i.indisvalid
         AND i.indisready AND i.indexprs IS NOT NULL
         AND pg_get_expr(i.indexprs,i.indrelid) ILIKE '%transaction_id%') THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: existing lookup index definition incompatible';
  END IF;

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_payments_normalized_transaction_lookup
    ON public.payments USING btree (lower(trim(transaction_id)))
    WHERE nullif(trim(coalesce(transaction_id, '''')), '''') IS NOT NULL';

  IF NOT EXISTS(SELECT 1 FROM pg_index i WHERE
      i.indexrelid='public.idx_payments_normalized_transaction_lookup'::regclass
      AND i.indrelid=t AND NOT i.indisunique AND i.indisvalid) THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: non-unique lookup not available';
  END IF;

  -- All checks complete: remove ONLY indexes with the two vetted Local names.
  FOR name_ IN SELECT c.relname FROM pg_index i
    JOIN pg_class c ON c.oid=i.indexrelid
    WHERE i.indrelid=t AND i.indisunique
      AND c.relname IN ('uq_payments_transaction_id_normalized','ux_payments_transaction_id_ci')
    ORDER BY c.relname
  LOOP
    EXECUTE format('DROP INDEX public.%I',name_);
    RAISE NOTICE 'DUAL_BANK_INDEX_OK: removed obsolete public.% index',name_;
  END LOOP;

  IF EXISTS(SELECT 1 FROM pg_index i
    WHERE i.indrelid=t AND i.indisunique AND i.indexprs IS NOT NULL
      AND pg_get_expr(i.indexprs,i.indrelid) ILIKE '%transaction_id%') THEN
    RAISE EXCEPTION 'DUAL_BANK_INDEX_STOP: UNIQUE payment reference index remains';
  END IF;
  RAISE NOTICE 'DUAL_BANK_INDEX_OK: payment_id PK and Bank Register UNIQUE kept; partial multi-invoice payments now allowed by index schema';
END $bb_dual_payment_index_preflight$;
