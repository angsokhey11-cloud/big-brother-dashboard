-- BIG BROTHER — V2 Local 08C Source Guard extracted for SYNTHETIC CI.
-- Mirrors the pre/post checks in staged standalone 08C V2 local merge file.
-- NEVER apply this standalone CI file to production or Local V5/V6.
-- The real 08C has SET LOCAL session_replication_role=replica and full
-- stage merge; this CI fixture tests only source-key collision safeguards.
\set ON_ERROR_STOP on
CREATE SCHEMA IF NOT EXISTS bb_cloud_stage;
CREATE TABLE bb_cloud_stage.stock_activity (LIKE public.stock_activity INCLUDING DEFAULTS);
CREATE FUNCTION public.bb_ci_stock_source_pre_v2()
RETURNS void LANGUAGE plpgsql AS $bb$
DECLARE
  v_stage_duplicate_keys bigint:=0;
  v_local_duplicate_keys bigint:=0;
  v_cross_id_conflicts bigint:=0;
  v_sample text;
BEGIN
  IF current_database()<>'bb_stock_v2_sandbox'
     OR to_regclass('bb_cloud_stage.stock_activity') IS NULL
     OR to_regclass('public.stock_activity') IS NULL THEN
    RAISE EXCEPTION 'BB_STOCK_SOURCE_GUARD_STOP: test environment invalid';
  END IF;
  SELECT count(*) INTO v_stage_duplicate_keys FROM (
    SELECT client_request_id FROM bb_cloud_stage.stock_activity
    WHERE movement_type='BATCH_SALE'
      AND from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
      AND to_bucket='EXTERNAL' AND client_request_id LIKE 'BATCH-INVOICE:%'
    GROUP BY client_request_id HAVING count(*)>1
  ) dup;
  IF v_stage_duplicate_keys>0 THEN
    RAISE EXCEPTION 'BB_STOCK_SOURCE_GUARD_STOP: % repeated Cloud invoice source keys in stock_activity',v_stage_duplicate_keys;
  END IF;
  SELECT count(*) INTO v_local_duplicate_keys FROM (
    SELECT client_request_id FROM public.stock_activity
    WHERE movement_type='BATCH_SALE'
      AND from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
      AND to_bucket='EXTERNAL' AND client_request_id LIKE 'BATCH-INVOICE:%'
    GROUP BY client_request_id HAVING count(*)>1
  ) dup;
  IF v_local_duplicate_keys>0 THEN
    RAISE EXCEPTION 'BB_STOCK_SOURCE_GUARD_STOP: % repeated Local invoice source keys in stock_activity',v_local_duplicate_keys;
  END IF;
  SELECT count(*),
         min(format('%s [Local %s / Cloud %s]',l.client_request_id,l.transaction_id,s.transaction_id))
    INTO v_cross_id_conflicts,v_sample
  FROM public.stock_activity l JOIN bb_cloud_stage.stock_activity s
    ON s.client_request_id=l.client_request_id
  WHERE s.movement_type='BATCH_SALE' AND l.movement_type='BATCH_SALE'
    AND s.from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
    AND l.from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
    AND s.to_bucket='EXTERNAL' AND l.to_bucket='EXTERNAL'
    AND s.client_request_id LIKE 'BATCH-INVOICE:%'
    AND (s.transaction_id IS DISTINCT FROM l.transaction_id
         OR s.from_bucket IS DISTINCT FROM l.from_bucket);
  IF v_cross_id_conflicts>0 THEN
    RAISE EXCEPTION 'BB_STOCK_SOURCE_GUARD_STOP: % Cloud/Local stock invoice source ID/bucket collisions. Example: %',v_cross_id_conflicts,v_sample;
  END IF;
END;
$bb$;
CREATE FUNCTION public.bb_ci_stock_source_post_v2()
RETURNS void LANGUAGE plpgsql AS $bb$
DECLARE v_duplicate_keys bigint;
BEGIN
  SELECT count(*) INTO v_duplicate_keys FROM (
    SELECT client_request_id FROM public.stock_activity
    WHERE movement_type='BATCH_SALE'
      AND from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
      AND to_bucket='EXTERNAL' AND client_request_id LIKE 'BATCH-INVOICE:%'
    GROUP BY client_request_id HAVING count(*)>1
  ) dup;
  IF v_duplicate_keys>0 THEN
    RAISE EXCEPTION 'BB_STOCK_SOURCE_GUARD_STOP: % duplicate invoice stock source keys after merge',v_duplicate_keys;
  END IF;
END;
$bb$;
