-- Synthetic proof of a narrowly scoped UNIQUE source index, not a migration.
\set ON_ERROR_STOP on
BEGIN;
DO $ci$
DECLARE e text; rejected boolean;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
  RAISE EXCEPTION 'Refuse index proof outside disposable database';
 END IF;

 -- 1) Distinct source keys on same invoice/product are valid.
 INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,
 qty,movement_type,from_bucket,to_bucket,client_request_id)
 VALUES
 ('BB-CI-IDX-P1',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:PURCHASED'),
 ('BB-CI-IDX-Z1',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE','BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:ZERO');
 RAISE NOTICE 'PASS SOURCE UNIQUE CASE 1/5: one Purchased and one Zero-Cost source accepted';

 -- 2) Duplicate ZERO source with new transaction ID must fail.
 rejected:=false;
 BEGIN
  INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,
   qty,movement_type,from_bucket,to_bucket,client_request_id)
  VALUES('BB-CI-IDX-Z2',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE',
   'BATCH_ZERO_COST','EXTERNAL','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:ZERO');
 EXCEPTION WHEN unique_violation THEN
  rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'INDEX CASE2 duplicate ZERO source accepted';END IF;
 RAISE NOTICE 'PASS SOURCE UNIQUE CASE 2/5: second Zero-Cost deduction blocked';

 -- 3) Original PURCHASED duplicate still blocked.
 rejected:=false;
 BEGIN
  INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,
   qty,movement_type,from_bucket,to_bucket,client_request_id)
  VALUES('BB-CI-IDX-P2',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE',
   'BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:PURCHASED');
 EXCEPTION WHEN unique_violation THEN
  rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'INDEX CASE3 duplicate Purchased source accepted';END IF;
 RAISE NOTICE 'PASS SOURCE UNIQUE CASE 3/5: duplicate Purchased deduction blocked';

 -- 4) Wrong bucket but identical source key still blocked.
 rejected:=false;
 BEGIN
  INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,
   qty,movement_type,from_bucket,to_bucket,client_request_id)
  VALUES('BB-CI-IDX-WRONG',current_date,'BB-CI-PRODUCT',1,'BATCH_SALE',
   'BATCH_PENDING','EXTERNAL','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:ZERO');
 EXCEPTION WHEN unique_violation THEN rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'INDEX CASE4 mismatched bucket source accepted';END IF;
 RAISE NOTICE 'PASS SOURCE UNIQUE CASE 4/5: cross-bucket key duplication blocked';

 -- 5) Other movement types remain independently capable of repeated keys.
 INSERT INTO public.stock_activity(transaction_id,activity_date,product_code,
 qty,movement_type,from_bucket,to_bucket,client_request_id)
 VALUES
 ('BB-CI-IDX-OTHER1',current_date,'BB-CI-PRODUCT',1,'BACK_SALE',
  'BATCH_ZERO_COST','WAREHOUSE_ZERO_COST','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:ZERO'),
 ('BB-CI-IDX-OTHER2',current_date,'BB-CI-PRODUCT',1,'BACK_SALE',
  'BATCH_ZERO_COST','WAREHOUSE_ZERO_COST','BATCH-INVOICE:BB-CI-IDX1:BB-CI-PRODUCT:ZERO');
 RAISE NOTICE 'PASS SOURCE UNIQUE CASE 5/5: unrelated Back Sale remains outside partial unique-index coverage';
END;
$ci$;
ROLLBACK;
DO $after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN RAISE EXCEPTION 'Unsafe test DB';END IF;
 IF EXISTS(SELECT 1 FROM public.stock_activity WHERE transaction_id LIKE 'BB-CI-IDX-%') THEN
   RAISE EXCEPTION 'CI partial index proof rollback failed';
 END IF;
 RAISE NOTICE 'PASS: 5/5 selective unique stock-source index proof; all test ledger rows rolled back';
END;
$after$;
