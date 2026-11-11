-- Tests V2 Local 08C stock source guard on synthetic no-network DB only.
-- No actual merge/production/local operations occur. Transaction rollback.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='45s';
LOCK TABLE public.stock_activity IN SHARE ROW EXCLUSIVE MODE NOWAIT;
DO $test$
DECLARE e text; rejected boolean; n bigint;
BEGIN
  IF current_database()<>'bb_stock_v2_sandbox' THEN
    RAISE EXCEPTION 'Refuse V2 local sync regression outside synthetic DB';
  END IF;
  -- Case 1: same source keys+same stock TX IDs on both sides are safe;
  -- Purchased and Zero-Cost source keys remain independent.
  INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
  VALUES
   ('BB-CI-SYNC-P',current_date,'BB-CI-PRODUCT',3,'BATCH_SALE','BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-SYNC:BB-CI-PRODUCT:PURCHASED'),
   ('BB-CI-SYNC-Z',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-SYNC:BB-CI-PRODUCT:ZERO');
  INSERT INTO bb_cloud_stage.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
  VALUES
   ('BB-CI-SYNC-P',current_date,'BB-CI-PRODUCT',3,'BATCH_SALE','BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-SYNC:BB-CI-PRODUCT:PURCHASED'),
   ('BB-CI-SYNC-Z',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-SYNC:BB-CI-PRODUCT:ZERO');
  PERFORM public.bb_ci_stock_source_pre_v2();
  PERFORM public.bb_ci_stock_source_post_v2();
  RAISE NOTICE 'PASS STOCK SYNC CASE 1/7: valid Purchased+Zero-Cost Cloud/Local keys accepted';

  -- Case 2: two Cloud movements with same ZERO source but distinct TX IDs.
  rejected:=false;
  BEGIN
   INSERT INTO bb_cloud_stage.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES
    ('BB-CI-CLOUD-Z1',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-CLOUD-Z:BB-CI-PRODUCT:ZERO'),
    ('BB-CI-CLOUD-Z2',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-CLOUD-Z:BB-CI-PRODUCT:ZERO');
   PERFORM public.bb_ci_stock_source_pre_v2();
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS e=MESSAGE_TEXT;
   IF position('repeated Cloud invoice source keys' in e)=0 THEN
      RAISE EXCEPTION 'SYNC CASE2 unexpected failure: %',e;
   END IF;
   rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'SYNC CASE2 ignored duplicated Cloud ZERO source';END IF;
  RAISE NOTICE 'PASS STOCK SYNC CASE 2/7: duplicate Cloud ZERO source denied';

  -- Case 3: two Local ZERO deductions with different IDs.
  rejected:=false;
  BEGIN
   INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES
    ('BB-CI-LOCAL-Z1',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-LOCAL-Z:BB-CI-PRODUCT:ZERO'),
    ('BB-CI-LOCAL-Z2',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-LOCAL-Z:BB-CI-PRODUCT:ZERO');
   PERFORM public.bb_ci_stock_source_pre_v2();
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS e=MESSAGE_TEXT;
   IF position('repeated Local invoice source keys' in e)=0 THEN
      RAISE EXCEPTION 'SYNC CASE3 unexpected failure: %',e;
   END IF;
   rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'SYNC CASE3 ignored duplicated Local ZERO source';END IF;
  RAISE NOTICE 'PASS STOCK SYNC CASE 3/7: duplicate Local ZERO source denied';

  -- Case 4: one Cloud ZERO and one Local ZERO, same source but diff IDs.
  rejected:=false;
  BEGIN
   INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES ('BB-CI-CROSS-LOCAL',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-CROSS:BB-CI-PRODUCT:ZERO');
   INSERT INTO bb_cloud_stage.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES ('BB-CI-CROSS-CLOUD',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-CROSS:BB-CI-PRODUCT:ZERO');
   PERFORM public.bb_ci_stock_source_pre_v2();
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS e=MESSAGE_TEXT;
   IF position('Cloud/Local stock invoice source ID/bucket collisions' in e)=0 THEN
      RAISE EXCEPTION 'SYNC CASE4 unexpected failure: %',e;
   END IF;
   rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'SYNC CASE4 ignored Cloud/Local ZERO collision';END IF;
  RAISE NOTICE 'PASS STOCK SYNC CASE 4/7: same ZERO source with different IDs rejected';

  -- Case 5: equal transaction IDs but contradicting source buckets.
  rejected:=false;
  BEGIN
   INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES ('BB-CI-CROSS-BUCKET',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-CROSS-B:BB-CI-PRODUCT:ZERO');
   INSERT INTO bb_cloud_stage.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES ('BB-CI-CROSS-BUCKET',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-CROSS-B:BB-CI-PRODUCT:ZERO');
   PERFORM public.bb_ci_stock_source_pre_v2();
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS e=MESSAGE_TEXT;
   IF position('Cloud/Local stock invoice source ID/bucket collisions' in e)=0 THEN
     RAISE EXCEPTION 'SYNC CASE5 unexpected failure: %',e;
   END IF;
   rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'SYNC CASE5 source-bucket mismatch was accepted';END IF;
  RAISE NOTICE 'PASS STOCK SYNC CASE 5/7: same transaction ID but wrong source bucket rejected';

  -- Case 6: after-merge verifier must detect duplicate ZERO sources.
  rejected:=false;
  BEGIN
   INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES
    ('BB-CI-POST-Z1',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-POST-Z:BB-CI-PRODUCT:ZERO'),
    ('BB-CI-POST-Z2',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-POST-Z:BB-CI-PRODUCT:ZERO');
   PERFORM public.bb_ci_stock_source_post_v2();
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS e=MESSAGE_TEXT;
   IF position('duplicate invoice stock source keys after merge' in e)=0 THEN
     RAISE EXCEPTION 'SYNC CASE6 unexpected failure: %',e;
   END IF;
   rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'SYNC CASE6 post-check ignored duplicate ZERO source';END IF;
  RAISE NOTICE 'PASS STOCK SYNC CASE 6/7: post-merge ZERO duplicate denied';

  -- Case 7: prior guard also prevents same Purchased key with different IDs.
  rejected:=false;
  BEGIN
   INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES ('BB-CI-P-CONFLICT-L',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-P-CROSS:BB-CI-PRODUCT:PURCHASED');
   INSERT INTO bb_cloud_stage.stock_activity(transaction_id,activity_date,product_code,qty,
      movement_type,from_bucket,to_bucket,client_request_id)
   VALUES ('BB-CI-P-CONFLICT-C',current_date,'BB-CI-PRODUCT',2,'BATCH_SALE','BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-P-CROSS:BB-CI-PRODUCT:PURCHASED');
   PERFORM public.bb_ci_stock_source_pre_v2();
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS e=MESSAGE_TEXT;
   IF position('Cloud/Local stock invoice source ID/bucket collisions' in e)=0 THEN
     RAISE EXCEPTION 'SYNC CASE7 unexpected failure: %',e;
   END IF;
   rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'SYNC CASE7 purchased regression was accepted';END IF;
  RAISE NOTICE 'PASS STOCK SYNC CASE 7/7: Purchased duplicate protection retained';

  IF (SELECT count(*) FROM public.stock_activity WHERE transaction_id LIKE 'BB-CI-SYNC-%')<>2
   OR (SELECT count(*) FROM bb_cloud_stage.stock_activity WHERE transaction_id LIKE 'BB-CI-SYNC-%')<>2 THEN
    RAISE EXCEPTION 'CI stock sync rejected requests escaped subtransaction';
  END IF;
END;
$test$;
ROLLBACK;
DO $done$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN RAISE EXCEPTION 'Unsafe CI target';END IF;
 IF EXISTS(SELECT 1 FROM public.stock_activity WHERE transaction_id LIKE 'BB-CI-SYNC-%') THEN
   RAISE EXCEPTION 'CI rollback retained new stock movements';
 END IF;
 RAISE NOTICE 'PASS: 7/7 local sync Purchased+Zero-Cost source collision tests rolled back';
END;
$done$;
