-- BIG BROTHER Local Brain V5/V6 — targeted prerequisite for 20261103_a
-- Fix only 2 missing/format-divergent invoice-line stock trigger early-exit guards.
-- No DML, no invoice data changes, no direct edits to stock quantities or costs.
-- Approved manifest applies this BEFORE 20261103_a, inside controller transaction.
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '90s';
DO $bb_guard_repair$
DECLARE
  v_main_def text;
  v_aware_def text;
  v_trig_main text;
  v_trig_aware text;
  v_main_anchor text := '  -- BATCH SALE';
  v_source_marker text;
  v_source_pos integer;
  v_source_matches text[];
  v_count integer;
BEGIN
  -- Reuse the actual mutually-exclusive trigger conditions recorded in
  -- LOCAL-STOCK-TRIGGER-CHECK-20261121-185736.txt. Never bypass stock guards.
  SELECT count(*) INTO v_count
  FROM pg_trigger t
  JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname='invoice_lines'
    AND t.tgname IN ('trg_invoice_lines_stock_direct_sale','trg_invoice_lines_stock_direct_sale_source_v1')
    AND t.tgenabled IN ('O','A') AND NOT t.tgisinternal;
  IF v_count<>2 THEN
    RAISE EXCEPTION 'Local stock guard repair blocked: expected 2 enabled invoice-stock triggers, found %',v_count;
  END IF;

  SELECT pg_get_triggerdef(t.oid) INTO v_trig_main
  FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname='invoice_lines'
    AND t.tgname='trg_invoice_lines_stock_direct_sale';
  SELECT pg_get_triggerdef(t.oid) INTO v_trig_aware
  FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname='invoice_lines'
    AND t.tgname='trg_invoice_lines_stock_direct_sale_source_v1';

  IF v_trig_main NOT LIKE '%WHEN ((NOT COALESCE(((new.stock_allocation_json -> 0) ? ''source''::text), false)))%'
     OR v_trig_main NOT LIKE '%EXECUTE FUNCTION bb_stock_invoice_line_after_insert()%'
     OR v_trig_aware NOT LIKE '%WHEN (COALESCE(((new.stock_allocation_json -> 0) ? ''source''::text), false))%'
     OR v_trig_aware NOT LIKE '%EXECUTE FUNCTION bb_stock_invoice_line_source_aware_after_insert()%' THEN
    RAISE EXCEPTION 'Local stock trigger routing differs from the verified mutually exclusive guards. No changes applied.';
  END IF;

  IF to_regprocedure('public.bb_stock_invoice_line_after_insert()') IS NULL OR
     to_regprocedure('public.bb_stock_invoice_line_source_aware_after_insert()') IS NULL THEN
    RAISE EXCEPTION 'Local stock guard repair missing one or both expected functions';
  END IF;

  SELECT pg_get_functiondef('public.bb_stock_invoice_line_after_insert()'::regprocedure)
    INTO v_main_def;
  SELECT pg_get_functiondef('public.bb_stock_invoice_line_source_aware_after_insert()'::regprocedure)
    INTO v_aware_def;

  IF position('v_invoice' IN v_main_def)=0
      OR position('new.stock_allocation_json' IN v_main_def)=0
      OR position('public.invoices' IN v_main_def)=0
      OR position(v_main_anchor IN v_main_def)=0 THEN
    RAISE EXCEPTION 'Local main stock function is not compatible with guarded repair';
  END IF;
  IF position('v_invoice' IN v_aware_def)=0
      OR position('new.stock_allocation_json' IN v_aware_def)=0
      OR position('public.invoices' IN v_aware_def)=0 THEN
    RAISE EXCEPTION 'Local source-aware stock function is not compatible with guarded repair';
  END IF;

  -- Main trigger: when an explicit direct-sale source is present, let the
  -- dedicated source-aware trigger handle the row; never deduct twice.
  IF v_main_def !~* 'v_invoice[.]batch_id[[:space:]]+is[[:space:]]+null[[:space:]]+and[[:space:]]+coalesce' THEN
    IF (length(v_main_def)-length(replace(v_main_def,v_main_anchor,''))) / length(v_main_anchor) <> 1 THEN
      RAISE EXCEPTION 'Local main stock function has ambiguous BATCH SALE anchor';
    END IF;
    v_main_def := replace(v_main_def,v_main_anchor,
       '  -- BB_LOCAL_DIRECT_SOURCE_SKIP_GUARD_20261121' || chr(10) ||
       '  IF v_invoice.batch_id IS NULL AND COALESCE((new.stock_allocation_json->0) ? ''source'',false) THEN' || chr(10) ||
       '    RETURN NEW;' || chr(10) ||
       '  END IF;' || chr(10) || chr(10) || v_main_anchor);
    EXECUTE v_main_def;
    RAISE NOTICE 'Restored main invoice-stock double-deduction skip';
  ELSE
    RAISE NOTICE 'Main invoice-stock skip already present';
  END IF;

  -- Source-aware trigger must exit immediately for a Batch invoice.
  -- Insert only after invoice record is confirmed present; retain all existing
  -- batch, warehouse, stock and COGS logic unmodified.
  IF v_aware_def !~* 'v_invoice[.]batch_id[[:space:]]+is[[:space:]]+not[[:space:]]+null[[:space:]]+then[[:space:]]+return[[:space:]]+new' THEN
    v_source_matches := regexp_match(v_aware_def,
      '(?is)(if[[:space:]]+not[[:space:]]+found[[:space:]]+then[[:space:]]+return[[:space:]]+new;[[:space:]]+end[[:space:]]+if;)');
    v_source_marker := v_source_matches[1];
    IF v_source_marker IS NULL THEN
      RAISE EXCEPTION 'Local source-aware stock function lacks verified post-invoice fetch anchor';
    END IF;
    v_source_pos := position(v_source_marker IN v_aware_def);
    IF v_source_pos<1 OR
       lower(substring(v_aware_def FROM 1 FOR v_source_pos)) !~ 'from[[:space:]]+public[.]invoices' THEN
      RAISE EXCEPTION 'Local source-aware invoice lookup shape differs; abort before function replacement';
    END IF;
    v_aware_def := substring(v_aware_def FROM 1 FOR v_source_pos+length(v_source_marker)-1) ||
      chr(10) || '  -- BB_LOCAL_SOURCE_AWARE_BATCH_SKIP_GUARD_20261121' || chr(10) ||
      '  IF v_invoice.batch_id IS NOT NULL THEN RETURN NEW; END IF;' || chr(10) ||
      substring(v_aware_def FROM v_source_pos+length(v_source_marker));
    EXECUTE v_aware_def;
    RAISE NOTICE 'Restored source-aware Batch invoice early-exit safeguard';
  ELSE
    RAISE NOTICE 'Source-aware Batch invoice skip already present';
  END IF;

  -- The exact failed migration's two checks must now pass.
  IF pg_get_functiondef('public.bb_stock_invoice_line_after_insert()'::regprocedure)
      !~* 'v_invoice[.]batch_id[[:space:]]+is[[:space:]]+null[[:space:]]+and[[:space:]]+coalesce'
    OR pg_get_functiondef('public.bb_stock_invoice_line_source_aware_after_insert()'::regprocedure)
      !~* 'v_invoice[.]batch_id[[:space:]]+is[[:space:]]+not[[:space:]]+null[[:space:]]+then[[:space:]]+return[[:space:]]+new' THEN
    RAISE EXCEPTION 'Local source routing protection verification failed. Roll back all changes.';
  END IF;
  RAISE NOTICE 'Local stock guard verification PASS. Original Nov-03 safety gate remains unchanged.';
END
$bb_guard_repair$;
