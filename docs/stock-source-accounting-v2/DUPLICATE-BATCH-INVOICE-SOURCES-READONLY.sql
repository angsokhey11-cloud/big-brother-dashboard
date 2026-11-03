-- BIG BROTHER — detect repeat Purchased/Zero-Cost sale deductions on the same invoice line.
-- Read only. This is an audit of stock_activity, NOT a migration or repair.
-- Run separately on Cloud and Local V5/V6; expected: no duplicate BATCH-INVOICE source IDs.
-- A duplicate does not prove one row may be safely deleted; cross-check the original
-- invoice line, returns, transaction timestamps and independently backed up Local rows.
SELECT
  batch_id,product_code,client_request_id,
  count(*) AS stock_deduction_count,
  sum(qty) AS total_deducted_qty,
  string_agg(transaction_id || ' (' || qty::text || ')',', ' ORDER BY transaction_id)
    AS source_transactions,
  min(created_at) AS earliest_created,
  max(created_at) AS latest_created
FROM public.stock_activity
WHERE movement_type='BATCH_SALE'
  AND client_request_id LIKE 'BATCH-INVOICE:%'
  AND from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
GROUP BY batch_id,product_code,client_request_id
HAVING count(*)>1
ORDER BY count(*) DESC,batch_id,product_code,client_request_id;
