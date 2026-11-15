-- BIG BROTHER V2: PROPOSED duplicate prevention for original Batch Invoice sales.
-- NOT APPROVED AS A PRODUCTION MIGRATION. CI/REVIEW ONLY.
-- This is narrower than an all-stock client_request_id unique constraint;
-- other stock event types may legitimately reuse their own request keys.
-- Only create after verifying NO duplicate stock invoice sale source keys on
-- BOTH Cloud and Local and proving old APK/PWA compatibility.
--
-- Read-only diagnostic that should return 0 before deploying this candidate:
-- SELECT count(*) FROM (
--   SELECT client_request_id FROM public.stock_activity
--   WHERE movement_type='BATCH_SALE'
--     AND from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
--     AND to_bucket='EXTERNAL'
--     AND client_request_id LIKE 'BATCH-INVOICE:%'
--   GROUP BY client_request_id HAVING count(*)>1
-- ) d;
--
-- On an isolated PostgreSQL test database:
CREATE UNIQUE INDEX bb_ci_unique_batch_invoice_source_v2
ON public.stock_activity (client_request_id)
WHERE movement_type='BATCH_SALE'
  AND from_bucket IN ('BATCH_PENDING','BATCH_ZERO_COST')
  AND to_bucket='EXTERNAL'
  AND client_request_id LIKE 'BATCH-INVOICE:%';
