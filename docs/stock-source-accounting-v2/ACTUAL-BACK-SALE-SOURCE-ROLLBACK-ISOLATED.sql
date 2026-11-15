-- BIG BROTHER V2: actual Back Sale save function integration, ISOLATED ONLY.
-- Calls staged bb_stock_save_batch_reference_internal, tests source-specific ledger,
-- stock snapshots, source validation, idempotency, and ROLLBACK.
-- Never execute against real Local V5/V6 or Cloud.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='90s';
DO $bb_back_test$
DECLARE
  v_batch text;
  v_product text;
  v_location text;
  v_wh text;
  v_actor uuid;
  v_p0 numeric;
  v_z0 numeric;
  v_p numeric;
  v_z numeric;
  v_cost numeric;
  v_prefix text:='BB-V2-BACK-ISOLATED-'||substr(md5(clock_timestamp()::text),1,12);
  v_request text;
  v_result jsonb;
  v_payload jsonb;
  v_qty numeric;
  v_p_qty numeric;
  v_z_qty numeric;
  v_n bigint;
  v_p_return numeric;
  v_z_return numeric;
  v_z_value numeric;
  v_p_value numeric;
  v_unit_cost numeric;
  v_count_before bigint;
  v_error text;
  v_rejected boolean;
  v_stored_count bigint;
BEGIN
  IF current_database()<>'bb_stock_v2_sandbox' THEN
    RAISE EXCEPTION 'Back Sale integration test REFUSED outside isolated sandbox';
  END IF;
  SELECT public.bb_stock_default_warehouse_internal() INTO v_wh;
  -- Select an existing OPEN batch with both source types and a valid ACTUAL
  -- active user having access to BOTH the batch location and warehouse.
  SELECT b.batch_id,bi.product_code,b.location_code,
         bi.purchased_pending_qty_snapshot,bi.zero_cost_pending_qty_snapshot,
         u.user_id
  INTO v_batch,v_product,v_location,v_p0,v_z0,v_actor
  FROM public.stock_batches b
  JOIN public.stock_batch_items bi ON bi.batch_id=b.batch_id
  JOIN public.products p ON p.product_code=bi.product_code AND p.active=true
  JOIN public.app_user_location_access ba ON lower(ba.location_code)=lower(b.location_code)
  JOIN public.app_users u ON u.user_id=ba.user_id AND u.active=true
  JOIN public.app_user_location_access wa ON wa.user_id=u.user_id
      AND lower(wa.location_code)=lower(v_wh)
  WHERE upper(b.status)='OPEN'
    AND bi.purchased_pending_qty_snapshot>=10
    AND bi.zero_cost_pending_qty_snapshot>=10
  ORDER BY (bi.purchased_pending_qty_snapshot+bi.zero_cost_pending_qty_snapshot) DESC,
           b.batch_id,bi.product_code
  LIMIT 1;
  IF v_actor IS NULL OR v_batch IS NULL THEN
    RAISE EXCEPTION 'Back Sale fixture unavailable: open mixed-stock batch + active authorized user not found';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  IF NOT public.bb_has_location_access(v_location) OR
     NOT public.bb_has_location_access(v_wh) THEN
    RAISE EXCEPTION 'Back Sale test actor not authorized for batch and warehouse';
  END IF;
  v_cost:=public.bb_stock_average_cost_internal(v_product);
  IF v_cost IS NULL OR v_cost<=0 THEN
    RAISE EXCEPTION 'Back Sale fixture missing positive purchased cost';
  END IF;
  RAISE NOTICE 'BACK SALE TEST fixture: batch %, product %, initial Purchased %, Zero %, warehouse %, average cost %',
    v_batch,v_product,v_p0,v_z0,v_wh,v_cost;

  -- CASE 1: Purchased 3 and Zero-Cost 2 in ONE Back Sale request.
  v_request:=v_prefix||'-M';
  v_payload:=jsonb_build_object('requestId',v_request,'batchId',v_batch,
      'activityDate',current_date::text,'items',jsonb_build_array(
        jsonb_build_object('productCode',v_product,'qty',5,'purchasedQty',3,'zeroCostQty',2)));
  v_result:=public.bb_stock_save_batch_reference_internal(v_payload,'BACK_SALE');
  IF v_result->>'success' IS DISTINCT FROM 'true' OR
     v_result->>'inventoryAllocationRule' IS DISTINCT FROM 'EXPLICIT_PURCHASED_ZERO_COST_SELECTION_V2' OR
     (v_result->'lines'->0->>'purchasedBackQty')::numeric IS DISTINCT FROM 3 OR
     (v_result->'lines'->0->>'zeroCostBackQty')::numeric IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'CASE 1 failed: response does not report explicit Purchased/Zero split';
  END IF;
  SELECT count(*),
     coalesce(sum(qty) FILTER(WHERE from_bucket='BATCH_PENDING'
         AND to_bucket='WAREHOUSE_GOOD'),0),
     coalesce(sum(qty) FILTER(WHERE from_bucket='BATCH_ZERO_COST'
         AND to_bucket='WAREHOUSE_ZERO_COST'),0),
     coalesce(sum(line_value) FILTER(WHERE from_bucket='BATCH_ZERO_COST'),0),
     coalesce(sum(line_value) FILTER(WHERE from_bucket='BATCH_PENDING'),0),
     coalesce(max(unit_cost) FILTER(WHERE from_bucket='BATCH_PENDING'),0)
  INTO v_n,v_p_return,v_z_return,v_z_value,v_p_value,v_unit_cost
  FROM public.stock_activity
  WHERE client_request_id=v_request AND movement_type='BACK_SALE'
    AND batch_id=v_batch AND product_code=v_product;
  IF v_n<>2 OR v_p_return<>3 OR v_z_return<>2 OR v_z_value<>0 OR
     v_unit_cost<>round(v_cost,4) OR v_p_value<>round(3*v_cost,2) THEN
    RAISE EXCEPTION 'CASE 1 failed: movements %, P %, Z %, Zero value %, Purchased value %, unit cost %',
      v_n,v_p_return,v_z_return,v_z_value,v_p_value,v_unit_cost;
  END IF;
  SELECT purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
    INTO v_p,v_z FROM public.stock_batch_items
   WHERE batch_id=v_batch AND product_code=v_product;
  IF v_p<>v_p0-3 OR v_z<>v_z0-2 THEN
    RAISE EXCEPTION 'CASE 1 failed: incorrect Purchased/Zero batch balances';
  END IF;
  RAISE NOTICE 'PASS CASE 1/7: mixed Back Sale P3/Z2, warehouse sources and original cost';

  -- CASE 2: Purchased only.
  v_request:=v_prefix||'-P';
  v_payload:=jsonb_build_object('requestId',v_request,'batchId',v_batch,
      'items',jsonb_build_array(
        jsonb_build_object('productCode',v_product,'qty',2,'purchasedQty',2,'zeroCostQty',0)));
  v_result:=public.bb_stock_save_batch_reference_internal(v_payload,'BACK_SALE');
  SELECT count(*),coalesce(sum(qty),0) INTO v_n,v_p_return
  FROM public.stock_activity
  WHERE client_request_id=v_request AND movement_type='BACK_SALE'
    AND from_bucket='BATCH_PENDING' AND to_bucket='WAREHOUSE_GOOD';
  IF v_n<>1 OR v_p_return<>2 THEN RAISE EXCEPTION 'CASE 2 failed: Purchased-only Back Sale'; END IF;
  RAISE NOTICE 'PASS CASE 2/7: purchased-only Back Sale';

  -- CASE 3: Zero-Cost only.
  v_request:=v_prefix||'-Z';
  v_payload:=jsonb_build_object('requestId',v_request,'batchId',v_batch,
      'items',jsonb_build_array(
        jsonb_build_object('productCode',v_product,'qty',2,'purchasedQty',0,'zeroCostQty',2)));
  v_result:=public.bb_stock_save_batch_reference_internal(v_payload,'BACK_SALE');
  SELECT count(*),coalesce(sum(qty),0),coalesce(sum(line_value),0)
   INTO v_n,v_z_return,v_z_value
  FROM public.stock_activity WHERE client_request_id=v_request
    AND movement_type='BACK_SALE' AND from_bucket='BATCH_ZERO_COST'
    AND to_bucket='WAREHOUSE_ZERO_COST';
  IF v_n<>1 OR v_z_return<>2 OR v_z_value<>0 THEN
    RAISE EXCEPTION 'CASE 3 failed: Zero-Cost-only Back Sale';
  END IF;
  SELECT purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
    INTO v_p,v_z FROM public.stock_batch_items
   WHERE batch_id=v_batch AND product_code=v_product;
  IF v_p<>v_p0-5 OR v_z<>v_z0-4 THEN
    RAISE EXCEPTION 'CASE 3 failed: cumulative batch Purchased/Zero balances';
  END IF;
  RAISE NOTICE 'PASS CASE 3/7: zero-cost-only Back Sale, $0 value and correct cumulative balances';

  -- CASE 4: idempotent retry of the same request must make NO second deduction.
  v_stored_count=(SELECT count(*) FROM public.stock_activity);
  v_result:=public.bb_stock_save_batch_reference_internal(v_payload,'BACK_SALE');
  IF v_result->>'duplicate' IS DISTINCT FROM 'true' OR
     (SELECT count(*) FROM public.stock_activity)<>v_stored_count THEN
    RAISE EXCEPTION 'CASE 4 failed: duplicate request saved another stock movement';
  END IF;
  RAISE NOTICE 'PASS CASE 4/7: duplicate request idempotent';

  -- CASES 5-7 must fail without leaving any stock, batch or request change.
  v_count_before=(SELECT count(*) FROM public.stock_activity);

  -- CASE 5: invalid source sum.
  v_rejected:=false;v_error:='';
  BEGIN
    PERFORM public.bb_stock_save_batch_reference_internal(
     jsonb_build_object('requestId',v_prefix||'-BAD-SPLIT','batchId',v_batch,
       'items',jsonb_build_array(jsonb_build_object(
        'productCode',v_product,'qty',5,'purchasedQty',3,'zeroCostQty',1))),
     'BACK_SALE');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF position('Back Sale source quantities must total return Qty' in v_error)=0 THEN
      RAISE EXCEPTION 'CASE 5 unexpected error: %',v_error;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'CASE 5 failed: invalid allocation accepted'; END IF;
  RAISE NOTICE 'PASS CASE 5/7: invalid split rejected';

  -- CASE 6: too much Purchased stock.
  v_rejected:=false;v_error:='';
  BEGIN
    PERFORM public.bb_stock_save_batch_reference_internal(
     jsonb_build_object('requestId',v_prefix||'-BAD-P','batchId',v_batch,
       'items',jsonb_build_array(jsonb_build_object(
        'productCode',v_product,'qty',v_p0+100,'purchasedQty',v_p0+100,'zeroCostQty',0))),
     'BACK_SALE');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF position('Batch Remaining is only' in v_error)=0 AND
       position('Purchased Back Sale Qty exceeds' in v_error)=0 THEN
      RAISE EXCEPTION 'CASE 6 unexpected error: %',v_error;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'CASE 6 failed: purchased oversell accepted'; END IF;
  RAISE NOTICE 'PASS CASE 6/7: Purchased oversell rejected';

  -- CASE 7: missing source fields.
  v_rejected:=false;v_error:='';
  BEGIN
    PERFORM public.bb_stock_save_batch_reference_internal(
     jsonb_build_object('requestId',v_prefix||'-BAD-OLD','batchId',v_batch,
       'items',jsonb_build_array(jsonb_build_object(
        'productCode',v_product,'qty',1))),
     'BACK_SALE');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT;
    IF position('Back Sale requires exact Purchased / Zero-Cost source quantities' in v_error)=0 THEN
      RAISE EXCEPTION 'CASE 7 unexpected error: %',v_error;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'CASE 7 failed: missing source accepted'; END IF;
  RAISE NOTICE 'PASS CASE 7/7: missing source allocation rejected';

  IF (SELECT count(*) FROM public.stock_activity)<>v_count_before OR
     EXISTS(SELECT 1 FROM public.stock_movement_requests
       WHERE request_id LIKE v_prefix||'-BAD-%') THEN
    RAISE EXCEPTION 'Rejected Back Sale altered ledger or request history';
  END IF;
  SELECT purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
    INTO v_p,v_z FROM public.stock_batch_items
   WHERE batch_id=v_batch AND product_code=v_product;
  IF v_p<>v_p0-5 OR v_z<>v_z0-4 THEN
    RAISE EXCEPTION 'Rejected Back Sale changed stock balances';
  END IF;
  RAISE NOTICE 'PASS: all seven Back Sale real-function tests and rejection rollback verified. Outer transaction ROLLBACK.';
END;
$bb_back_test$;
ROLLBACK;
DO $bb_back_after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Back Sale post-rollback check refused outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.stock_activity WHERE client_request_id LIKE 'BB-V2-BACK-ISOLATED-%') OR
    EXISTS(SELECT 1 FROM public.stock_movement_requests WHERE request_id LIKE 'BB-V2-BACK-ISOLATED-%') THEN
   RAISE EXCEPTION 'Back Sale rollback failure: synthetic ledger/request survived';
 END IF;
 RAISE NOTICE 'PASS: post-ROLLBACK Back Sale synthetic ledger/request absent';
END;
$bb_back_after$;
\echo 'V2 STEP2B BACK SALE REAL-FUNCTION TEST FINISHED: no synthetic rows remain if all PASS notices above.'
