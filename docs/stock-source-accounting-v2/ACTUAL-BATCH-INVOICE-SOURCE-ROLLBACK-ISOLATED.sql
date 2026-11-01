-- BIG BROTHER Stock Source V2: ACTUAL invoice_lines AFTER INSERT trigger integration
-- ISOLATED DATABASE ONLY. Real function + live-style tables, not mock arithmetic.
-- Requires three staged source-aware SQL definitions already applied inside clone.
-- A single transaction, with forced ROLLBACK. Refuse any database except sandbox.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $bb_v2_test$
DECLARE
  v_invoice_id text;
  v_invoice_no text;
  v_batch_id text;
  v_product text;
  v_p_before numeric;
  v_z_before numeric;
  v_p_now numeric;
  v_z_now numeric;
  v_cost numeric;
  v_prefix text := 'BB-V2-ISOLATED-'||substr(md5(clock_timestamp()::text),1,12);
  v_line text;
  v_line_no integer;
  v_p_ledger numeric;
  v_z_ledger numeric;
  v_rows bigint;
  v_bad_value numeric;
  v_purchase_value numeric;
  v_purchase_cost numeric;
  v_error text;
  v_rejected boolean;
  v_qty_before numeric;
  v_p_before_invalid numeric;
  v_z_before_invalid numeric;
BEGIN
  IF current_database()<>'bb_stock_v2_sandbox' THEN
    RAISE EXCEPTION 'V2 TEST REFUSED: not isolated sandbox database';
  END IF;
  -- Existing approved OPEN Batch and invoice header are used only as a test
  -- parent; inserts here are temporary and undone by outer ROLLBACK.
  SELECT i.invoice_id,i.invoice_no,b.batch_id,bi.product_code,
         bi.purchased_pending_qty_snapshot,bi.zero_cost_pending_qty_snapshot
  INTO v_invoice_id,v_invoice_no,v_batch_id,v_product,v_p_before,v_z_before
  FROM public.invoices i
  JOIN public.stock_batches b ON b.batch_id=i.batch_id
  JOIN public.stock_batch_items bi ON bi.batch_id=b.batch_id
  WHERE upper(b.status)='OPEN'
    AND i.location_code=b.location_code
    AND bi.purchased_pending_qty_snapshot>=10
    AND bi.zero_cost_pending_qty_snapshot>=10
  ORDER BY (bi.purchased_pending_qty_snapshot+bi.zero_cost_pending_qty_snapshot) DESC,
           i.invoice_date DESC,i.invoice_id,bi.product_code
  LIMIT 1;
  IF v_invoice_id IS NULL THEN
    RAISE EXCEPTION 'V2 TEST FIXTURE MISSING: no OPEN mixed-source Batch with existing invoice and 10+ units/source. Do not invent fixture.';
  END IF;
  IF NOT public.bb_stock_ready_internal() THEN
    RAISE EXCEPTION 'V2 TEST BLOCKED: stock module not ready in sandbox';
  END IF;
  IF EXISTS(SELECT 1 FROM public.invoice_lines WHERE line_id LIKE 'BB-V2-ISOLATED-%') THEN
    RAISE EXCEPTION 'V2 TEST REFUSED: preexisting test lines detected in snapshot';
  END IF;
  v_cost:=public.bb_stock_average_cost_internal(v_product);
  IF v_cost IS NULL OR v_cost<=0 THEN
    RAISE EXCEPTION 'V2 TEST FIXTURE INVALID: purchased cost missing or nonpositive';
  END IF;
  SELECT coalesce(max(line_no),0)+1000 INTO v_line_no FROM public.invoice_lines WHERE invoice_id=v_invoice_id;
  RAISE NOTICE 'V2 TEST FIXTURE: existing open batch %, product %, invoice header %, P %, Z %, avg cost %',
    v_batch_id,v_product,v_invoice_id,v_p_before,v_z_before,v_cost;

  -- CASE 1: Real mixed-source invoice line, Purchased=3, Zero=2.
  v_line:=v_prefix||'-M';
  INSERT INTO public.invoice_lines(
    line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,
    product_code,display_product_code,product_name_snapshot,
    qty,unit_price,line_total,stock_allocation_json
  ) VALUES(
    v_line,v_invoice_id,v_invoice_no,v_line_no,'EXACT',
    v_product,v_product,v_product,
    5,1,5,jsonb_build_array(jsonb_build_object(
      'productCode',v_product,'qty',5,'purchasedQty',3,'zeroCostQty',2))
  );
  SELECT coalesce(sum(qty) FILTER(WHERE from_bucket='BATCH_PENDING'),0),
         coalesce(sum(qty) FILTER(WHERE from_bucket='BATCH_ZERO_COST'),0),
         count(*),
         coalesce(sum(line_value) FILTER(WHERE from_bucket='BATCH_ZERO_COST'),0),
         coalesce(sum(line_value) FILTER(WHERE from_bucket='BATCH_PENDING'),0),
         coalesce(max(unit_cost) FILTER(WHERE from_bucket='BATCH_PENDING'),0)
    INTO v_p_ledger,v_z_ledger,v_rows,v_bad_value,v_purchase_value,v_purchase_cost
  FROM public.stock_activity
  WHERE client_request_id IN (
    'BATCH-INVOICE:'||v_line||':'||v_product||':PURCHASED',
    'BATCH-INVOICE:'||v_line||':'||v_product||':ZERO'
  ) AND batch_id=v_batch_id AND movement_type='BATCH_SALE' AND to_bucket='EXTERNAL';
  IF v_rows<>2 OR v_p_ledger<>3 OR v_z_ledger<>2 OR v_bad_value<>0 OR
     abs(v_purchase_cost-v_cost)>0.000001 OR abs(v_purchase_value-round(3*v_cost,6))>0.000002 THEN
    RAISE EXCEPTION 'V2 CASE 1 FAILED: purchased %, zero %, movements %, zero value %, purchased value %, cost %',
      v_p_ledger,v_z_ledger,v_rows,v_bad_value,v_purchase_value,v_purchase_cost;
  END IF;
  SELECT purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
    INTO v_p_now,v_z_now FROM public.stock_batch_items
   WHERE batch_id=v_batch_id AND product_code=v_product;
  IF v_p_now<>v_p_before-3 OR v_z_now<>v_z_before-2 THEN
    RAISE EXCEPTION 'V2 CASE 1 FAILED: batch P/Z snapshots changed unexpectedly';
  END IF;
  RAISE NOTICE 'PASS CASE 1/6: MIXED invoice triggers Purchased 3 + Zero 2; exact source ledger + original current purchase cost';

  -- CASE 2: Real Purchased-only stock movement.
  v_line:=v_prefix||'-P';
  INSERT INTO public.invoice_lines(
    line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,
    product_code,display_product_code,product_name_snapshot,
    qty,unit_price,line_total,stock_allocation_json
  ) VALUES(
    v_line,v_invoice_id,v_invoice_no,v_line_no+1,'EXACT',v_product,v_product,v_product,
    2,1,2,jsonb_build_array(jsonb_build_object(
      'productCode',v_product,'qty',2,'purchasedQty',2,'zeroCostQty',0))
  );
  SELECT count(*),coalesce(sum(qty),0) INTO v_rows,v_p_ledger
  FROM public.stock_activity
  WHERE client_request_id='BATCH-INVOICE:'||v_line||':'||v_product||':PURCHASED'
    AND from_bucket='BATCH_PENDING' AND to_bucket='EXTERNAL';
  IF v_rows<>1 OR v_p_ledger<>2 THEN RAISE EXCEPTION 'V2 CASE 2 FAILED: Purchased-only actual trigger ledger'; END IF;
  RAISE NOTICE 'PASS CASE 2/6: PURCHASED-only invoice movement';

  -- CASE 3: Real Zero-Cost-only stock movement.
  v_line:=v_prefix||'-Z';
  INSERT INTO public.invoice_lines(
    line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,
    product_code,display_product_code,product_name_snapshot,
    qty,unit_price,line_total,stock_allocation_json
  ) VALUES(
    v_line,v_invoice_id,v_invoice_no,v_line_no+2,'EXACT',v_product,v_product,v_product,
    2,1,2,jsonb_build_array(jsonb_build_object(
      'productCode',v_product,'qty',2,'purchasedQty',0,'zeroCostQty',2))
  );
  SELECT count(*),coalesce(sum(qty),0),coalesce(sum(line_value),0)
    INTO v_rows,v_z_ledger,v_bad_value FROM public.stock_activity
  WHERE client_request_id='BATCH-INVOICE:'||v_line||':'||v_product||':ZERO'
    AND from_bucket='BATCH_ZERO_COST' AND to_bucket='EXTERNAL';
  IF v_rows<>1 OR v_z_ledger<>2 OR v_bad_value<>0 THEN
    RAISE EXCEPTION 'V2 CASE 3 FAILED: Zero-Cost-only movement with value 0';
  END IF;
  SELECT purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
    INTO v_p_now,v_z_now FROM public.stock_batch_items
   WHERE batch_id=v_batch_id AND product_code=v_product;
  IF v_p_now<>v_p_before-5 OR v_z_now<>v_z_before-4 THEN
    RAISE EXCEPTION 'V2 CASE 3 FAILED: cumulative batch P/Z balance';
  END IF;
  RAISE NOTICE 'PASS CASE 3/6: ZERO-COST-only invoice, $0 COGS; cumulative P-5/Z-4';

  -- Negative fixtures use PL/pgSQL subtransactions. Expected rejections
  -- undo all nested insert/stock writes, while retaining the earlier cases.
  SELECT count(*) INTO v_rows FROM public.stock_activity;
  v_p_before_invalid:=v_p_now; v_z_before_invalid:=v_z_now;

  -- CASE 4: invalid split (3+1 != 5).
  v_rejected:=false; v_error:='';
  BEGIN
    INSERT INTO public.invoice_lines(
      line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,
      product_code,display_product_code,qty,unit_price,line_total,stock_allocation_json
    ) VALUES(v_prefix||'-BAD-SPLIT',v_invoice_id,v_invoice_no,v_line_no+3,
      'EXACT',v_product,v_product,5,1,5,
      jsonb_build_array(jsonb_build_object('productCode',v_product,'qty',5,'purchasedQty',3,'zeroCostQty',1)));
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF position('Source quantities must total Invoice Qty' in v_error)=0 THEN
      RAISE EXCEPTION 'V2 CASE 4 unexpected error: %',v_error;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'V2 CASE 4 FAILED: invalid source split accepted'; END IF;
  RAISE NOTICE 'PASS CASE 4/6: invalid source split rejected';

  -- CASE 5: Purchased oversell in an otherwise valid split.
  v_rejected:=false; v_error:='';
  BEGIN
    INSERT INTO public.invoice_lines(
      line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,
      product_code,display_product_code,qty,unit_price,line_total,stock_allocation_json
    ) VALUES(v_prefix||'-BAD-P',v_invoice_id,v_invoice_no,v_line_no+4,'EXACT',
      v_product,v_product,v_p_before+100,1,v_p_before+100,
      jsonb_build_array(jsonb_build_object(
        'productCode',v_product,'qty',v_p_before+100,'purchasedQty',v_p_before+100,'zeroCostQty',0)));
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF position('greater than Batch' in v_error)=0 AND
       position('Purchased Batch source balance is insufficient' in v_error)=0 THEN
      RAISE EXCEPTION 'V2 CASE 5 unexpected error: %',v_error;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'V2 CASE 5 FAILED: Purchased oversell accepted'; END IF;
  RAISE NOTICE 'PASS CASE 5/6: Purchased-source oversell rejected';

  -- CASE 6: Omitted explicit source in legacy-style exact Batch line.
  v_rejected:=false; v_error:='';
  BEGIN
    INSERT INTO public.invoice_lines(
      line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,
      product_code,display_product_code,qty,unit_price,line_total,stock_allocation_json
    ) VALUES(v_prefix||'-BAD-OLD',v_invoice_id,v_invoice_no,v_line_no+5,'EXACT',
      v_product,v_product,1,1,1,'[]'::jsonb);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF position('explicit Purchased/Zero-Cost source is required' in v_error)=0 THEN
      RAISE EXCEPTION 'V2 CASE 6 unexpected error: %',v_error;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'V2 CASE 6 FAILED: missing source accepted'; END IF;
  RAISE NOTICE 'PASS CASE 6/6: legacy missing source rejected';

  -- Ensure rejected inserts left NO lines, movements, or batch changes.
  IF EXISTS(
    SELECT 1 FROM public.invoice_lines il
    WHERE il.line_id IN(v_prefix||'-BAD-SPLIT',v_prefix||'-BAD-P',v_prefix||'-BAD-OLD')
  ) THEN RAISE EXCEPTION 'V2 safety failed: rejected invoice line survived'; END IF;
  IF (SELECT count(*) FROM public.stock_activity)<>v_rows THEN
    RAISE EXCEPTION 'V2 safety failed: rejected invoice changed stock ledger';
  END IF;
  SELECT purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
    INTO v_p_now,v_z_now FROM public.stock_batch_items
   WHERE batch_id=v_batch_id AND product_code=v_product;
  IF v_p_now<>v_p_before_invalid OR v_z_now<>v_z_before_invalid THEN
    RAISE EXCEPTION 'V2 safety failed: rejected invoice changed stock balance';
  END IF;
  RAISE NOTICE 'PASS: 6/6 real Invoice Line / Batch Stock trigger tests (sandbox only). Outer transaction now ROLLBACK.';
END;
$bb_v2_test$;
ROLLBACK;
-- Verify that the forced rollback removed every synthetic invoice line and ledger
-- movement. This check runs after the test transaction has ended.
DO $bb_v2_after$
BEGIN
  IF current_database()<>'bb_stock_v2_sandbox' THEN
    RAISE EXCEPTION 'V2 rollback verification refused outside sandbox';
  END IF;
  IF EXISTS(SELECT 1 FROM public.invoice_lines WHERE line_id LIKE 'BB-V2-ISOLATED-%') OR
     EXISTS(SELECT 1 FROM public.stock_activity WHERE client_request_id LIKE 'BATCH-INVOICE:BB-V2-ISOLATED-%') THEN
    RAISE EXCEPTION 'V2 rollback verification failed: synthetic stock or invoice line survived';
  END IF;
  RAISE NOTICE 'PASS: post-ROLLBACK invoice-line and stock-ledger fixtures absent';
END;
$bb_v2_after$;
\echo 'V2 STEP2 INVOICE REAL-TRIGGER TEST ROLLED BACK + VERIFIED; 6/6 cases if all PASS notices above.'
