-- BIG BROTHER V3.4 | 10-Nov-2026
-- PRE-MERGE GATE for the existing 08C Cloud -> Local merge.
-- Run INSIDE the existing 08C BEGIN transaction, after 08B has populated
-- bb_cloud_stage, and BEFORE any merge INSERT/UPDATE/DELETE.
-- CHECK ONLY: never creates/drops/modifies any table, data or constraint.
-- A missing staged Cloud table/column becomes a clear preflight error
-- instead of a partial merge, FK error, or opaque "relation does not exist".
DO $bb_stage_schema_guard_20261110$
DECLARE
  v_stage_tables int;
  v_missing_tables text;
  v_missing_columns text;
BEGIN
  SELECT count(*) INTO v_stage_tables
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='bb_cloud_stage'
    AND c.relkind IN ('r','p')
    AND c.relname NOT IN ('sync_plan','sync_audit','sync_metadata');
  IF v_stage_tables=0 THEN
    RAISE EXCEPTION USING
      MESSAGE='BB_PREMERGE_SCHEMA_BLOCKED: No business tables found in bb_cloud_stage.',
      HINT='Cloud stage must finish restoring before the 08C merge; do not continue sync.';
  END IF;

  WITH stage_tables AS (
    SELECT c.relname
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='bb_cloud_stage' AND c.relkind IN ('r','p')
      AND c.relname NOT IN ('sync_plan','sync_audit','sync_metadata')
  )
  SELECT string_agg(format('public.%I',st.relname),', ' ORDER BY st.relname)
  INTO v_missing_tables
  FROM stage_tables st
  LEFT JOIN pg_catalog.pg_namespace pn ON pn.nspname='public'
  LEFT JOIN pg_catalog.pg_class pc ON pc.relnamespace=pn.oid
    AND pc.relname=st.relname AND pc.relkind IN ('r','p')
  WHERE pc.oid IS NULL;
  IF v_missing_tables IS NOT NULL THEN
    RAISE EXCEPTION USING
      MESSAGE='BB_PREMERGE_SCHEMA_BLOCKED: Missing LOCAL business table(s): '||v_missing_tables,
      HINT='Do not merge until the safe schema migration creates these tables, with PK/FK, RLS and policies. Existing local data was not changed.';
  END IF;

  WITH stage_tables AS (
    SELECT c.oid, c.relname
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='bb_cloud_stage' AND c.relkind IN ('r','p')
      AND c.relname NOT IN ('sync_plan','sync_audit','sync_metadata')
  ),
  stage_columns AS (
    SELECT t.relname, a.attname
    FROM stage_tables t
    JOIN pg_catalog.pg_attribute a ON a.attrelid=t.oid
      AND a.attnum>0 AND NOT a.attisdropped
  )
  SELECT string_agg(format('public.%I.%I',sc.relname,sc.attname),', '
                    ORDER BY sc.relname,sc.attname)
  INTO v_missing_columns
  FROM stage_columns sc
  JOIN pg_catalog.pg_namespace pn ON pn.nspname='public'
  JOIN pg_catalog.pg_class pc ON pc.relnamespace=pn.oid
    AND pc.relname=sc.relname AND pc.relkind IN ('r','p')
  LEFT JOIN pg_catalog.pg_attribute pa ON pa.attrelid=pc.oid
    AND pa.attname=sc.attname AND pa.attnum>0 AND NOT pa.attisdropped
  WHERE pa.attname IS NULL;
  IF v_missing_columns IS NOT NULL THEN
    RAISE EXCEPTION USING
      MESSAGE='BB_PREMERGE_SCHEMA_BLOCKED: Missing LOCAL business column(s): '||v_missing_columns,
      HINT='Apply an approved additive column migration/Schema Guard before 08C; no merge data was written.';
  END IF;

  RAISE NOTICE 'BB_PREMERGE_SCHEMA_OK staged_business_tables=% (no missing public tables or columns)',v_stage_tables;
END
$bb_stage_schema_guard_20261110$;
