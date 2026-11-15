-- Actual staged read-only reversal source snapshot regression (synthetic).
-- DO NOT run against real Local or Cloud. Requires bb_stock_v2_sandbox DB.
\set ON_ERROR_STOP on
DO $bb_ci_snapshot$
DECLARE
  v jsonb;
  row0 jsonb;
  error_text text;
  v_rejected boolean;
BEGIN
  IF current_database()<>'bb_stock_v2_sandbox' THEN
    RAISE EXCEPTION 'CI Reversal Source test refused outside sandbox';
  END IF;
  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);

  -- CASE 1: actual 3 Purchased + 2 Zero original; partial 1/1 return.
  v:=public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-INV');
  row0:=v->'sources'->0;
  IF v->>'success'<>'true' OR v->>'isBatch'<>'true' OR
     jsonb_array_length(v->'sources')<>1 OR
     (row0->>'originalPurchasedQty')::numeric<>3 OR
     (row0->>'originalZeroCostQty')::numeric<>2 OR
     (row0->>'returnedPurchasedQty')::numeric<>1 OR
     (row0->>'returnedZeroCostQty')::numeric<>1 OR
     (row0->>'remainingPurchasedQty')::numeric<>2 OR
     (row0->>'remainingZeroCostQty')::numeric<>1 OR
     (row0->>'originalPurchasedValue')::numeric<>9.85 OR
     (row0->>'originalPurchasedUnitCost')::numeric<>(9.85::numeric/3) OR
     (row0->>'sourceMismatch')::boolean IS DISTINCT FROM false THEN
     RAISE EXCEPTION 'CI REVERSAL SOURCE CASE1 failure: %',v;
  END IF;
  RAISE NOTICE 'PASS REVERSAL SOURCE CASE 1/4: exact original P/Z history and historical COGS';

  -- CASE 2: non-Batch invoice must report isBatch=false, no invented sources.
  v:=public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-DIRECT');
  IF v->>'isBatch'<>'false' OR jsonb_array_length(v->'sources')<>0 THEN
    RAISE EXCEPTION 'CI REVERSAL SOURCE CASE2 nonbatch misclassified: %',v;
  END IF;
  RAISE NOTICE 'PASS REVERSAL SOURCE CASE 2/4: Direct Sale has no Batch source';

  -- CASE 3: unknown user cannot read invoice source history.
  v_rejected:=false;error_text:='';
  BEGIN
    PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
    PERFORM public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-INV');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_text=MESSAGE_TEXT;
    IF position('Invoice Reversal access denied' in error_text)=0 THEN
      RAISE EXCEPTION 'CI REVERSAL SOURCE CASE3 unexpected auth error: %',error_text;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'CI REVERSAL SOURCE CASE3 unauthorized access accepted';END IF;
  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  RAISE NOTICE 'PASS REVERSAL SOURCE CASE 3/4: unauthorized user denied';

  -- CASE 4: an excessive historical return must be FLAGGED as a mismatch.
  -- Intentional exception subtransaction ensures the synthetic extra return
  -- is rolled back, preserving the validated state.
  v_rejected:=false;
  BEGIN
    INSERT INTO public.stock_activity(transaction_id,activity_date,activity_type,
      product_code,batch_id,reference_no,qty,from_bucket,to_bucket,movement_type)
    VALUES('BB-CI-BAD-RETURN',CURRENT_DATE,'Test', 'BB-CI-PRODUCT',
      'BB-CI-BATCH','BB-CI-RETURN',4,'EXTERNAL','BATCH_PENDING','BATCH_SALE_RETURN');
    v:=public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-INV');
    IF (v->'sources'->0->>'sourceMismatch')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'CI REVERSAL SOURCE CASE4 mismatch not flagged: %',v;
    END IF;
    RAISE EXCEPTION 'CI_ROLLBACK_BAD_RETURN';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_text=MESSAGE_TEXT;
    IF error_text<>'CI_ROLLBACK_BAD_RETURN' THEN
      RAISE EXCEPTION 'CI REVERSAL SOURCE CASE4 unexpected failure: %',error_text;
    END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected OR EXISTS(SELECT 1 FROM public.stock_activity WHERE transaction_id='BB-CI-BAD-RETURN') THEN
    RAISE EXCEPTION 'CI REVERSAL SOURCE CASE4 failed to roll back extra movement';
  END IF;
  RAISE NOTICE 'PASS REVERSAL SOURCE CASE 4/4: excessive return flagged; extra movement rolled back';

  v:=public.bb_invoice_reversal_batch_source_snapshot_v2('BB-CI-INV');
  IF (v->'sources'->0->>'remainingPurchasedQty')::numeric<>2 THEN
    RAISE EXCEPTION 'CI REVERSAL SOURCE after-check failed';
  END IF;
  RAISE NOTICE 'PASS: 4/4 real reversal snapshot function tests, synthetic data, no production access';
END;
$bb_ci_snapshot$;
