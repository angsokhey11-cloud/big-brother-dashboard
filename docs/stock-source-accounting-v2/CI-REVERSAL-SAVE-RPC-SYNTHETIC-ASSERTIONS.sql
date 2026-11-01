-- BIG BROTHER: actual staged by-ID + post-close reversal SAVE RPC end-to-end.
-- Synthetic CI db ONLY. Real BEFORE and both actual AFTER stock triggers.
-- Check business return amount + audit and exact historical stock sources.
-- Every operation rolled back; no Cloud/real Local connections.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $bb_ci_rpc$
DECLARE
  payload jsonb;
  resp jsonb;
  rid text;
  n bigint;
  p numeric;z numeric;v_cost numeric;v_value numeric;
  err text;
  rejected boolean;
  ledger_before bigint;
  audit_before bigint;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Reversal RPC CI refused outside sandbox';
 END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 ledger_before=(SELECT count(*) FROM public.stock_activity);
 audit_before=(SELECT count(*) FROM public.sales_database_edit_history);

 -- CASE 1: invoice ID / number mismatched must not silently reverse wrong invoice.
 rejected:=false;err:='';
 BEGIN
   PERFORM public.bb_invoice_reversal_save_by_id_v2(jsonb_build_object(
     'invoiceId','BB-CI-RPC-INV-OPEN','invoiceNo','BB-CI-WRONG-INVOICE',
     'returnDate',current_date::text,'reason','Synthetic mismatch rejection',
     'returnType','Partial Reversal',
     'lines',jsonb_build_array(jsonb_build_object(
       'lineId','BB-CI-RPC-LINE-OPEN','qty',1,
       'stockAllocations',jsonb_build_array(jsonb_build_object(
         'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',1,'zeroCostQty',0))
     ))
   ));
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Invoice No / ID mismatch' IN err)=0 THEN
     RAISE EXCEPTION 'CI SAVE CASE 1 unexpected rejection: %',err;
   END IF;
   rejected:=true;
 END;
 IF NOT rejected THEN
   RAISE EXCEPTION 'CI SAVE CASE 1 failed: Invoice ID / Invoice Number mismatch accepted';
 END IF;
 IF (SELECT count(*) FROM public.stock_activity)<>ledger_before OR
    (SELECT count(*) FROM public.sales_returns WHERE return_id LIKE 'REV-%')<>0 OR
    (SELECT count(*) FROM public.sales_database_edit_history)<>audit_before THEN
   RAISE EXCEPTION 'CI SAVE CASE 1 rejected mismatch produced stock or audit entries';
 END IF;
 RAISE NOTICE 'PASS RPC CASE 1/6: wrong Invoice ID/No pair rejected atomically';

 -- CASE 2: real by-ID RPC -> BEFORE origin-source guard -> open-Batch stock
 -- AFTER trigger -> record return amount + audit. Duplicate invoice numbers
 -- exist across *different customers* in the same synthetic test database.
 payload:=jsonb_build_object(
  'invoiceId','BB-CI-RPC-INV-OPEN','invoiceNo','BB-CI-DUPLICATE-9',
  'returnDate',current_date::text,'reason','Synthetic partial return',
  'returnType','Partial Reversal',
  'lines',jsonb_build_array(jsonb_build_object(
    'lineId','BB-CI-RPC-LINE-OPEN','qty',2,
    'stockAllocations',jsonb_build_array(jsonb_build_object(
      'productCode','BB-CI-PRODUCT','qty',2,'purchasedQty',1,'zeroCostQty',1))
  )));
 resp:=public.bb_invoice_reversal_save_by_id_v2(payload);
 IF resp->>'success'<>'true' OR (resp->>'lineCount')::int<>1 OR
    (resp->>'totalAmount')::numeric<>5.00 THEN
   RAISE EXCEPTION 'CI SAVE CASE 2 failed by-ID RPC response: %',resp;
 END IF;
 rid:=resp->'returns'->0->>'returnId';
 IF rid IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.sales_returns r WHERE r.return_id=rid
     AND r.invoice_id='BB-CI-RPC-INV-OPEN' AND r.qty=2
     AND r.return_amount=5.00
 ) THEN RAISE EXCEPTION 'CI SAVE CASE 2 no exact return transaction';END IF;
 SELECT count(*),
   coalesce(sum(qty) FILTER(WHERE to_bucket='BATCH_PENDING'),0),
   coalesce(sum(qty) FILTER(WHERE to_bucket='BATCH_ZERO_COST'),0),
   coalesce(sum(line_value) FILTER(WHERE to_bucket='BATCH_PENDING'),0),
   coalesce(max(unit_cost) FILTER(WHERE to_bucket='BATCH_PENDING'),0)
 INTO n,p,z,v_value,v_cost
 FROM public.stock_activity
 WHERE reference_no=rid AND movement_type='BATCH_SALE_RETURN';
 IF n<>2 OR p<>1 OR z<>1 OR v_value<>3.28 OR v_cost<>3.2833 THEN
  RAISE EXCEPTION 'CI SAVE CASE 2 historical source movement incorrect P %, Z %, value %, unit %',
    p,z,v_value,v_cost;
 END IF;
 IF (SELECT count(*) FROM public.sales_database_edit_history)<>audit_before+1 THEN
   RAISE EXCEPTION 'CI SAVE CASE 2 missing audit record';
 END IF;
 IF (SELECT purchased_sold_qty_snapshot FROM public.stock_batch_items
      WHERE batch_id='BB-CI-RPC-OPEN' AND product_code='BB-CI-PRODUCT')<>2 OR
    (SELECT zero_cost_sold_qty_snapshot FROM public.stock_batch_items
      WHERE batch_id='BB-CI-RPC-OPEN' AND product_code='BB-CI-PRODUCT')<>1 THEN
   RAISE EXCEPTION 'CI SAVE CASE 2 incorrect open-Batch remaining source quantities';
 END IF;
 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE invoice_id='BB-CI-RPC-INV-CLOSED') THEN
   RAISE EXCEPTION 'CI SAVE CASE 2 duplicate invoice number contaminated different Invoice ID';
 END IF;
 RAISE NOTICE 'PASS RPC CASE 2/6: by-ID SAVE + BEFORE guard + OPEN stock + audit + $5 partial return, duplicate invoice numbers isolated';

 -- CASE 3: postclose save RPC -> route row -> BEFORE guard ->
 -- two AFTER triggers, original CLOSED Batch unchanged.
 payload:=jsonb_build_object(
  'invoiceId','BB-CI-RPC-INV-CLOSED','invoiceNo','BB-CI-DUPLICATE-9',
  'returnDate',current_date::text,'reason','Synthetic postclose return',
  'returnType','Partial Reversal',
  'lines',jsonb_build_array(jsonb_build_object(
    'lineId','BB-CI-RPC-LINE-CLOSED','qty',2,
    'stockAllocations',jsonb_build_array(jsonb_build_object(
      'productCode','BB-CI-PRODUCT','qty',2,'purchasedQty',1,'zeroCostQty',1)),
    'destinations',jsonb_build_array(jsonb_build_object(
      'productCode','BB-CI-PRODUCT','destinationType','WAREHOUSE'))
  )));
 resp:=public.bb_invoice_reversal_postclose_save_v1(payload);
 IF resp->>'success'<>'true' OR (resp->>'totalAmount')::numeric<>5.00 THEN
   RAISE EXCEPTION 'CI SAVE CASE 3 postclose RPC response failure: %',resp;
 END IF;
 rid:=resp->'returns'->0->>'returnId';
 IF rid IS NULL OR NOT EXISTS(SELECT 1 FROM public.bb_postclose_reversal_routes
    WHERE return_id=rid AND original_batch_id='BB-CI-RPC-CLOSED') THEN
   RAISE EXCEPTION 'CI SAVE CASE 3 postclose destination route missing';
 END IF;
 SELECT count(*),
   coalesce(sum(qty) FILTER(WHERE to_bucket='WAREHOUSE_GOOD'),0),
   coalesce(sum(qty) FILTER(WHERE to_bucket='WAREHOUSE_ZERO_COST'),0),
   coalesce(sum(line_value) FILTER(WHERE to_bucket='WAREHOUSE_GOOD'),0)
 INTO n,p,z,v_value FROM public.stock_activity
 WHERE reference_no=rid AND movement_type='POSTCLOSE_SALE_RETURN';
 IF n<>2 OR p<>1 OR z<>1 OR v_value<>3.28 THEN
    RAISE EXCEPTION 'CI SAVE CASE 3 returned stock to wrong warehouse buckets';
 END IF;
 IF (SELECT status FROM public.stock_batches WHERE batch_id='BB-CI-RPC-CLOSED')<>'Closed' THEN
   RAISE EXCEPTION 'CI SAVE CASE 3 changed original closed Batch';
 END IF;
 IF (SELECT count(*) FROM public.sales_database_edit_history)<>audit_before+2 THEN
   RAISE EXCEPTION 'CI SAVE CASE 3 missing audit record';
 END IF;
 RAISE NOTICE 'PASS RPC CASE 3/6: postclose SAVE + routes + warehouse P/Z + historical cost + audit';

 -- CASE 4: second postclose request to a wrong-location OPEN Batch must fail
 -- BEFORE anything reaches ledger; subtransaction rollback includes route/audit.
 rejected:=false;err:='';
 BEGIN
   PERFORM public.bb_invoice_reversal_postclose_save_v1(jsonb_build_object(
     'invoiceId','BB-CI-RPC-INV-CLOSED','invoiceNo','BB-CI-DUPLICATE-9',
     'returnDate',current_date::text,'reason','Synthetic wrong-location refusal',
     'returnType','Partial Reversal',
     'lines',jsonb_build_array(jsonb_build_object(
       'lineId','BB-CI-RPC-LINE-CLOSED','qty',1,
       'stockAllocations',jsonb_build_array(jsonb_build_object(
         'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',1,'zeroCostQty',0)),
       'destinations',jsonb_build_array(jsonb_build_object(
         'productCode','BB-CI-PRODUCT','destinationType','OPEN_BATCH','batchId','BB-CI-WRONG-LOC'))
     ))
   ));
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Target Batch must be Open in the same location' IN err)=0 THEN
     RAISE EXCEPTION 'CI SAVE CASE 4 unexpected error: %',err;
   END IF;
   rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'CI SAVE CASE 4 wrong-location target accepted';END IF;
 IF (SELECT count(*) FROM public.sales_database_edit_history)<>audit_before+2 OR
    (SELECT count(*) FROM public.bb_postclose_reversal_routes
       WHERE invoice_id='BB-CI-RPC-INV-CLOSED')<>1 THEN
   RAISE EXCEPTION 'CI SAVE CASE 4 invalid request left routes/audit';
 END IF;

 RAISE NOTICE 'PASS RPC CASE 4/6: invalid destination rejected, no extra routes or audit';

 -- CASE 5: legacy Invoice No-only RPC must reject duplicated invoice numbers,
 -- without creating returns for either customer.
 rejected:=false;err:='';
 BEGIN
   PERFORM public.bb_invoice_reversal_save_v2(jsonb_build_object(
    'invoiceNo','BB-CI-DUPLICATE-9',
    'returnDate',current_date::text,
    'reason','Synthetic legacy ambiguity rejection',
    'returnType','Partial Reversal',
    'lines',jsonb_build_array(jsonb_build_object(
      'lineId','BB-CI-RPC-LINE-OPEN','qty',1,
      'stockAllocations',jsonb_build_array(jsonb_build_object(
        'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',1,'zeroCostQty',0))
    ))
   ));
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Duplicate Invoice No; use Invoice ID' IN err)=0 THEN
     RAISE EXCEPTION 'CI SAVE CASE 5 unexpected error: %',err;
   END IF;
   rejected:=true;
 END;
 IF NOT rejected THEN
    RAISE EXCEPTION 'CI SAVE CASE 5 ambiguous legacy invoice-number-only reversal accepted';
 END IF;
 IF (SELECT count(*) FROM public.sales_database_edit_history)<>audit_before+2 OR
    (SELECT count(*) FROM public.sales_returns WHERE invoice_id='BB-CI-RPC-INV-OPEN')<>1 OR
    (SELECT count(*) FROM public.sales_returns WHERE invoice_id='BB-CI-RPC-INV-CLOSED')<>1 THEN
    RAISE EXCEPTION 'CI SAVE CASE 5 ambiguity attempted a financial change';
 END IF;
 RAISE NOTICE 'PASS RPC CASE 5/6: duplicate invoice number legacy RPC rejected safely';

 -- CASE 6: legacy Invoice No-only RPC still works with a unique invoice number.
 resp:=public.bb_invoice_reversal_save_v2(jsonb_build_object(
    'invoiceNo','BB-CI-UNIQUE-INVOICE',
    'returnDate',current_date::text,
    'reason','Synthetic unique number compatibility',
    'returnType','Partial Reversal',
    'lines',jsonb_build_array(jsonb_build_object(
      'lineId','BB-CI-RPC-LINE-UNIQUE','qty',1,
      'stockAllocations',jsonb_build_array(jsonb_build_object(
        'productCode','BB-CI-PRODUCT','qty',1,'purchasedQty',1,'zeroCostQty',0))
    ))
 ));
 rid:=resp->'returns'->0->>'returnId';
 IF resp->>'success'<>'true' OR (resp->>'totalAmount')::numeric<>2.50 OR
    rid IS NULL OR NOT EXISTS(SELECT 1 FROM public.sales_returns
      WHERE return_id=rid AND invoice_id='BB-CI-RPC-INV-UNIQUE'
        AND return_amount=2.50) OR
    NOT EXISTS(SELECT 1 FROM public.stock_activity
      WHERE reference_no=rid AND to_bucket='BATCH_PENDING'
        AND line_value=3.28) OR
    (SELECT count(*) FROM public.sales_database_edit_history)<>audit_before+3 THEN
     RAISE EXCEPTION 'CI SAVE CASE 6 unique legacy RPC incompatible: %',resp;
 END IF;
 RAISE NOTICE 'PASS RPC CASE 6/6: legacy unique-number save works; source and financial records correct';
END;
$bb_ci_rpc$;
ROLLBACK;
DO $bb_ci_rpc_after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
  RAISE EXCEPTION 'CI Reversal RPC post-rollback check refused outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE invoice_id LIKE 'BB-CI-RPC-%')
 OR EXISTS(SELECT 1 FROM public.bb_postclose_reversal_routes WHERE invoice_id LIKE 'BB-CI-RPC-%')
 OR EXISTS(SELECT 1 FROM public.sales_database_edit_history WHERE record_id LIKE 'BB-CI-RPC-%')
 OR EXISTS(SELECT 1 FROM public.stock_activity WHERE reference_no LIKE 'REV-%') THEN
   RAISE EXCEPTION 'CI Reversal RPC ROLLBACK left created return, route, audit, or stock';
 END IF;
 RAISE NOTICE 'PASS: 6/6 real Reversal SAVE RPC transaction tests rolled back with no synthetic changes';
END;
$bb_ci_rpc_after$;
