-- Real staged post-close Reversal trigger: synthetic fixture, never production.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $bb_ci_postclose$
DECLARE
  v_n bigint;v_p numeric;v_z numeric;v_val numeric;v_cost numeric;
  v_response jsonb;v_err text;v_rejected boolean;
  v_baseline bigint;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Postclose CI refused outside sandbox';
 END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 v_baseline:=(SELECT count(*) FROM public.stock_activity);

 -- CASE 1: closed Batch sale returns P1/Z1 to correct warehouse buckets.
 INSERT INTO public.bb_postclose_reversal_routes(
  return_id,invoice_id,original_batch_id,destinations
 ) VALUES('BB-CI-POST-WH','BB-CI-INV','BB-CI-BATCH',
  jsonb_build_array(jsonb_build_object(
   'productCode','BB-CI-PRODUCT','destinationType','WAREHOUSE')));
 INSERT INTO public.sales_returns(
  return_id,invoice_id,line_id,return_date,qty,stock_allocation_json
 ) VALUES('BB-CI-POST-WH','BB-CI-INV','BB-CI-LINE',current_date,2,
  jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','qty',2,'purchasedQty',1,'zeroCostQty',1)));
 SELECT count(*),
   coalesce(sum(qty) FILTER(WHERE to_bucket='WAREHOUSE_GOOD'),0),
   coalesce(sum(qty) FILTER(WHERE to_bucket='WAREHOUSE_ZERO_COST'),0),
   coalesce(sum(line_value) FILTER(WHERE to_bucket='WAREHOUSE_GOOD'),0),
   coalesce(max(unit_cost) FILTER(WHERE to_bucket='WAREHOUSE_GOOD'),0)
 INTO v_n,v_p,v_z,v_val,v_cost
 FROM public.stock_activity
 WHERE reference_no='BB-CI-POST-WH'
   AND movement_type='POSTCLOSE_SALE_RETURN' AND from_bucket='EXTERNAL';
 IF v_n<>2 OR v_p<>1 OR v_z<>1 OR v_val<>3.28 OR v_cost<>3.2833 THEN
   RAISE EXCEPTION 'Postclose CASE 1 failed: cnt %, P %, Z %, value %, unit %',v_n,v_p,v_z,v_val,v_cost;
 END IF;
 IF (SELECT count(*) FROM public.bb_postclose_reversal_allocations WHERE return_id='BB-CI-POST-WH')<>2 THEN
   RAISE EXCEPTION 'Postclose CASE 1 missing audited source/destination allocations';
 END IF;
 RAISE NOTICE 'PASS POSTCLOSE CASE 1/4: Closed Batch P1/Z1 -> Warehouse source buckets; original $3.28 cost';

 -- CASE 2: original Purchased source returns to SAME-LOCATION open Batch.
 INSERT INTO public.bb_postclose_reversal_routes(
  return_id,invoice_id,original_batch_id,destinations
 ) VALUES('BB-CI-POST-OPEN','BB-CI-INV','BB-CI-BATCH',
  jsonb_build_array(jsonb_build_object(
   'productCode','BB-CI-PRODUCT','destinationType','OPEN_BATCH','batchId','BB-CI-DEST')));
 INSERT INTO public.sales_returns(
  return_id,invoice_id,line_id,return_date,qty,stock_allocation_json
 ) VALUES('BB-CI-POST-OPEN','BB-CI-INV','BB-CI-LINE',current_date,1,
  jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',1,'zeroCostQty',0)));
 SELECT count(*),coalesce(sum(qty),0),coalesce(sum(line_value),0)
 INTO v_n,v_p,v_val
 FROM public.stock_activity WHERE reference_no='BB-CI-POST-OPEN'
  AND movement_type='POSTCLOSE_SALE_RETURN'
  AND batch_id='BB-CI-DEST' AND to_bucket='BATCH_PENDING';
 IF v_n<>1 OR v_p<>1 OR v_val<>3.28 THEN
   RAISE EXCEPTION 'Postclose CASE 2 failed to route Purchased Qty to open Batch';
 END IF;
 IF (SELECT purchased_pending_qty_snapshot FROM public.stock_batch_items
     WHERE batch_id='BB-CI-DEST' AND product_code='BB-CI-PRODUCT')<>1 OR
    (SELECT issued_qty FROM public.stock_batches WHERE batch_id='BB-CI-DEST')<>1 THEN
   RAISE EXCEPTION 'Postclose CASE 2 target Batch source balance not updated';
 END IF;
 IF (SELECT status FROM public.stock_batches WHERE batch_id='BB-CI-BATCH')<>'Closed' THEN
   RAISE EXCEPTION 'Postclose CASE 2 modified original Closed Batch status';
 END IF;
 RAISE NOTICE 'PASS POSTCLOSE CASE 2/4: original Purchased -> same-location OPEN Batch; closed original unchanged';

 -- CASE 3: all original eligible source exhausted; must not create more stock.
 v_rejected:=false;v_err:='';
 BEGIN
  INSERT INTO public.bb_postclose_reversal_routes(
   return_id,invoice_id,original_batch_id,destinations
  ) VALUES('BB-CI-POST-OVER','BB-CI-INV','BB-CI-BATCH',
   jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','destinationType','WAREHOUSE')));
  INSERT INTO public.sales_returns(
   return_id,invoice_id,line_id,return_date,qty,stock_allocation_json
  ) VALUES('BB-CI-POST-OVER','BB-CI-INV','BB-CI-LINE',current_date,1,
   jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',1,'zeroCostQty',0)));
 EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
  IF position('returned Purchased exceeds original eligible source balance' IN v_err)=0 THEN
    RAISE EXCEPTION 'Postclose CASE 3 unexpected rejection: %',v_err;
  END IF;
  v_rejected:=true;
 END;
 IF NOT v_rejected OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-POST-OVER') THEN
   RAISE EXCEPTION 'Postclose CASE 3 wrong duplicate return allowed';
 END IF;
 RAISE NOTICE 'PASS POSTCLOSE CASE 3/4: exhausted source denied with atomic rollback';

 -- CASE 4: chosen open Batch in different location must be denied.
 v_rejected:=false;v_err:='';
 BEGIN
  INSERT INTO public.bb_postclose_reversal_routes(
   return_id,invoice_id,original_batch_id,destinations
  ) VALUES('BB-CI-POST-BADLOC','BB-CI-INV','BB-CI-BATCH',
   jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','destinationType','OPEN_BATCH','batchId','BB-CI-WRONG-LOC')));
  INSERT INTO public.sales_returns(
   return_id,invoice_id,line_id,return_date,qty,stock_allocation_json
  ) VALUES('BB-CI-POST-BADLOC','BB-CI-INV','BB-CI-LINE',current_date,1,
   jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',0,'zeroCostQty',1)));
 EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
  IF position('Target Batch must be Open in the same location' IN v_err)=0 THEN
    RAISE EXCEPTION 'Postclose CASE 4 unexpected rejection: %',v_err;
  END IF;
  v_rejected:=true;
 END;
 IF NOT v_rejected OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-POST-BADLOC') THEN
   RAISE EXCEPTION 'Postclose CASE 4 wrong-location target accepted';
 END IF;
 IF (SELECT count(*) FROM public.stock_activity)<>v_baseline+3 THEN
   RAISE EXCEPTION 'Postclose rejected requests created extra stock rows';
 END IF;
 v_response:=public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-INV');
 IF (v_response->'sources'->0->>'remainingPurchasedQty')::numeric<>0
 OR (v_response->'sources'->0->>'remainingZeroCostQty')::numeric<>0 THEN
   RAISE EXCEPTION 'Postclose source history does not reconcile after two returns: %',v_response;
 END IF;
 RAISE NOTICE 'PASS POSTCLOSE CASE 4/4: wrong-location destination rejected; original sources fully reconciled';
END;
$bb_ci_postclose$;
ROLLBACK;
DO $bb_ci_postcheck$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Postclose rollback check refused outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id LIKE 'BB-CI-POST-%')
 OR EXISTS(SELECT 1 FROM public.bb_postclose_reversal_routes WHERE return_id LIKE 'BB-CI-POST-%')
 OR EXISTS(SELECT 1 FROM public.bb_postclose_reversal_allocations WHERE return_id LIKE 'BB-CI-POST-%')
 OR EXISTS(SELECT 1 FROM public.stock_activity WHERE reference_no LIKE 'BB-CI-POST-%') THEN
    RAISE EXCEPTION 'Postclose CI ROLLBACK left temporary rows';
 END IF;
 IF (SELECT purchased_pending_qty_snapshot FROM public.stock_batch_items
     WHERE batch_id='BB-CI-DEST' AND product_code='BB-CI-PRODUCT')<>0 THEN
    RAISE EXCEPTION 'Postclose CI ROLLBACK left target Batch stock';
 END IF;
 RAISE NOTICE 'PASS: 4/4 postclose actual trigger scenarios and ROLLBACK verified';
END;
$bb_ci_postcheck$;
