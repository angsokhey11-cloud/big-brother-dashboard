-- BIG BROTHER V3.4 | Approved Local-only routine migration 2026-10-15.
-- Batch Edit Driver 1/2: any ACTIVE staff member may be selected.
-- Salesman chooser remains restricted to active Salesman staff.
-- Changes only TWO existing PostgreSQL function bodies; no table/data writes.
-- This code runs ONLY on Local PostgreSQL, AFTER a Local safety backup.
-- All checks and replacements are atomic in the caller's psql --single-transaction.
DO $migration$
DECLARE
  v_options text;
  v_save text;
  v_filter text := $needle$and lower(coalesce(s.position,''))='driver'$needle$;
  v_options_count integer;
  v_save_count integer;
BEGIN
  IF to_regprocedure('public.bb_stock_batch_edit_header_options(text)') IS NULL
     OR to_regprocedure('public.bb_stock_edit_batch_header(jsonb)') IS NULL THEN
    RAISE EXCEPTION 'APPROVED SQL MIGRATION STOPPED: expected batch edit function missing in Local';
  END IF;
  SELECT pg_get_functiondef('public.bb_stock_batch_edit_header_options(text)'::regprocedure)
  INTO v_options;
  SELECT pg_get_functiondef('public.bb_stock_edit_batch_header(jsonb)'::regprocedure)
  INTO v_save;

  v_options_count := (length(v_options)-length(replace(v_options,v_filter,''))) / length(v_filter);
  v_save_count := (length(v_save)-length(replace(v_save,v_filter,''))) / length(v_filter);
  IF v_options_count NOT IN (0,1) OR v_save_count NOT IN (0,2) THEN
    RAISE EXCEPTION 'APPROVED SQL MIGRATION STOPPED: unexpected driver-role checks: %, %',v_options_count,v_save_count;
  END IF;
  IF position('v_drivers' in v_options)=0
      OR position('v_driver_id' in v_save)=0
      OR position('v_driver2_id' in v_save)=0
      OR position('Driver 1 is required' in v_save)=0
      OR position('Driver 2 must be different from Driver 1' in v_save)=0
      OR position('Batch Location access denied' in v_save)=0 THEN
    RAISE EXCEPTION 'APPROVED SQL MIGRATION STOPPED: function safety markers changed';
  END IF;
  -- Validate that the current-role restriction appears exactly as audited.
  -- Replace ONLY the role predicate, preserving all other Local function code.
  IF v_options_count=1 THEN
    IF position(E'\n    '||v_filter in v_options)=0 THEN
      RAISE EXCEPTION 'APPROVED SQL MIGRATION STOPPED: option function format drifted';
    END IF;
    v_options := replace(v_options,E'\n    '||v_filter,'');
  END IF;
  IF v_save_count=2 THEN
    IF position(E'\n    '||v_filter in v_save)=0 OR position(E'\n      '||v_filter in v_save)=0 THEN
      RAISE EXCEPTION 'APPROVED SQL MIGRATION STOPPED: save function format drifted';
    END IF;
    v_save := replace(v_save,E'\n    '||v_filter,'');
    v_save := replace(v_save,E'\n      '||v_filter,'');
  END IF;
  IF v_options_count=1 THEN
    EXECUTE v_options;
  END IF;
  IF v_save_count=2 THEN
    EXECUTE v_save;
  END IF;
  RAISE NOTICE 'V34_APPROVED_SQL_APPLIED: options_filters_removed=%, save_filters_removed=%',v_options_count,v_save_count;
END
$migration$;
