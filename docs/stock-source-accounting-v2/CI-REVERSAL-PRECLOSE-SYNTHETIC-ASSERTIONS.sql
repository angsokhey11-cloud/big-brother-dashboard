-- Actual staged open-Batch Reversal AFTER INSERT stock trigger integration.
-- Synthetic PostgreSQL, no network, no live Local/Cloud. Unconditional ROLLBACK.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $bb_ci_reversal$
DECLARE
  p numeric;z numeric;pv numeric;pc numeric;n bigint;
  snap record;
  v jsonb;
  v_err text;
  rejected boolean;
  baseline bigint;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Preclose Reversal CI REFUSED outside sandbox';
 END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 baseline:=(SELECT count(*) FROM public.stock_activity);
 -- CASE 1: source-specific oversell while total sold quantity is sufficient.
 rejected:=false;v_err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,return_date,stock_allocation_json)
   VALUES ('BB-CI-BAD-PRECLOSE-SOURCE','BB-CI-INV','BB-CI-LINE',current_date,
     jsonb_build_array(jsonb_build_object(
      'productCode','BB-CI-PRODUCT','qty',3,'purchasedQty',3,'zeroCostQty',0)));
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('Purchased returned exceeds current Purchased sold balance' IN v_err)=0 THEN
      RAISE EXCEPTION 'CI REVERSAL CASE1 unexpected source error: %',v_err;
   END IF;
   rejected:=true;
 END;
 IF NOT rejected OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-BAD-PRECLOSE-SOURCE') THEN
   RAISE EXCEPTION 'CI REVERSAL CASE1 source-specific over-return accepted';
 END IF;
 RAISE NOTICE 'PASS RECOVERY POSTING CASE 1/4: Purchased source over-return rejected without ledger writes';

 -- CASE 2: Actual partial reversal 1 Purchased / 1 Zero-Cost to open Batch.
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,return_date,stock_allocation_json)
 VALUES ('BB-CI-ACTUAL-PRECLOSE','BB-CI-INV','BB-CI-LINE',current_date,
   jsonb_build_array(jsonb_build_object(
    'productCode','BB-CI-PRODUCT','qty',2,'purchasedQty',1,'zeroCostQty',1)));
 SELECT count(*),
  coalesce(sum(qty) FILTER(WHERE to_bucket='BATCH_PENDING'),0),
  coalesce(sum(qty) FILTER(WHERE to_bucket='BATCH_ZERO_COST'),0),
  coalesce(sum(line_value) FILTER(WHERE to_bucket='BATCH_PENDING'),0),
  coalesce(max(unit_cost) FILTER(WHERE to_bucket='BATCH_PENDING'),0)
 INTO n,p,z,pv,pc
 FROM public.stock_activity
 WHERE reference_no='BB-CI-ACTUAL-PRECLOSE'
   AND movement_type='BATCH_SALE_RETURN' AND from_bucket='EXTERNAL';
 IF n<>2 OR p<>1 OR z<>1 OR pv<>3.28 OR pc<>3.2833 THEN
   RAISE EXCEPTION 'CI REVERSAL posting CASE 2 ledger error: %,%,%,%,%',n,p,z,pv,pc;
 END IF;
 SELECT sold_qty_snapshot,pending_qty_snapshot,
  purchased_sold_qty_snapshot,zero_cost_sold_qty_snapshot,
  purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
 INTO snap FROM public.stock_batch_items
 WHERE batch_id='BB-CI-BATCH' AND product_code='BB-CI-PRODUCT';
 IF snap.sold_qty_snapshot<>1 OR snap.pending_qty_snapshot<>39
   OR snap.purchased_sold_qty_snapshot<>1 OR snap.zero_cost_sold_qty_snapshot<>0
   OR snap.purchased_pending_qty_snapshot<>19 OR snap.zero_cost_pending_qty_snapshot<>20 THEN
   RAISE EXCEPTION 'CI REVERSAL posting CASE 2 batch snapshots incorrect: %',to_jsonb(snap);
 END IF;
 IF (SELECT sold_qty FROM public.stock_batches WHERE batch_id='BB-CI-BATCH')<>1 THEN
   RAISE EXCEPTION 'CI REVERSAL posting CASE 2 batch aggregate mismatch';
 END IF;
 RAISE NOTICE 'PASS RECOVERY POSTING CASE 2/4: historical COGS 3.28 + exact P1/Z1 restored to OPEN Batch';

 -- CASE 3: Invalid source split (0 + 0 != 1) MUST rollback line and stock.
 rejected:=false;v_err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,return_date,stock_allocation_json)
   VALUES ('BB-CI-BAD-PRECLOSE-SPLIT','BB-CI-INV','BB-CI-LINE',current_date,
     jsonb_build_array(jsonb_build_object(
      'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',0,'zeroCostQty',0)));
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('invalid Purchased / Zero-Cost Reversal source quantities' IN v_err)=0 THEN
      RAISE EXCEPTION 'CI REVERSAL posting CASE 3 unexpected error: %',v_err;
   END IF;
   rejected:=true;
 END;
 IF NOT rejected OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-BAD-PRECLOSE-SPLIT') THEN
   RAISE EXCEPTION 'CI REVERSAL posting CASE 3 incorrect source split accepted';
 END IF;
 RAISE NOTICE 'PASS RECOVERY POSTING CASE 3/4: bad Purchased/Zero-Cost split rejected and rolled back';

 -- CASE 4: over-return above currently sold Qty must rollback.
 rejected:=false;v_err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,return_date,stock_allocation_json)
   VALUES ('BB-CI-BAD-PRECLOSE-OVER','BB-CI-INV','BB-CI-LINE',current_date,
     jsonb_build_array(jsonb_build_object(
      'productCode','BB-CI-PRODUCT','qty',2,'purchasedQty',2,'zeroCostQty',0)));
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('exceeds Batch sold Qty' IN v_err)=0 THEN
     RAISE EXCEPTION 'CI REVERSAL posting CASE 4 unexpected error: %',v_err;
   END IF;
   rejected:=true;
 END;
 IF NOT rejected OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-BAD-PRECLOSE-OVER') THEN
   RAISE EXCEPTION 'CI REVERSAL posting CASE 4 over-return accepted';
 END IF;
 IF (SELECT count(*) FROM public.stock_activity)<>baseline+2 THEN
   RAISE EXCEPTION 'CI REVERSAL failed: rejected rows mutated stock ledger';
 END IF;
 v:=public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-INV');
 IF (v->'sources'->0->>'remainingPurchasedQty')::numeric<>1 OR
    (v->'sources'->0->>'remainingZeroCostQty')::numeric<>0 THEN
   RAISE EXCEPTION 'CI REVERSAL after posting source snapshot wrong: %',v;
 END IF;
 RAISE NOTICE 'PASS RECOVERY POSTING CASE 4/4: Sold-quantity over-return rejected; source history reconciles';
END;
$bb_ci_reversal$;
ROLLBACK;
DO $bb_ci_after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'CI post-rollback refused outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id LIKE 'BB-CI-%PRECLOSE%')
 OR EXISTS(SELECT 1 FROM public.stock_activity WHERE reference_no='BB-CI-ACTUAL-PRECLOSE') THEN
   RAISE EXCEPTION 'CI Reversal posting rollback failed: synthetic rows survived';
 END IF;
 IF EXISTS(SELECT 1 FROM public.stock_batch_items
           WHERE batch_id='BB-CI-BATCH' AND product_code='BB-CI-PRODUCT'
            AND (purchased_pending_qty_snapshot<>18 OR zero_cost_pending_qty_snapshot<>19
              OR purchased_sold_qty_snapshot<>2 OR zero_cost_sold_qty_snapshot<>1)) THEN
    RAISE EXCEPTION 'CI Reversal posting rollback failed: source snapshots changed';
 END IF;
 RAISE NOTICE 'PASS: actual open-Batch reversal posting 4/4 cases; synthetic transaction ROLLBACK verified';
END;
$bb_ci_after$;
