-- SYNTHETIC V2: pre-close Reversal actual AFTER INSERT trigger integration.
-- Extends disposable CI schema after Back Sale + snapshot synthetic checks.
-- Adds only the test columns and synthetic source balances for this path.
\set ON_ERROR_STOP on
ALTER TABLE public.stock_activity ADD COLUMN customer_name_snapshot text;
ALTER TABLE public.invoices ADD COLUMN customer_name_snapshot text;
ALTER TABLE public.sales_returns ADD COLUMN return_date date;
ALTER TABLE public.sales_returns ADD COLUMN stock_allocation_json jsonb;
ALTER TABLE public.stock_batch_items
 ADD COLUMN purchased_sold_qty_snapshot numeric DEFAULT 0 NOT NULL,
 ADD COLUMN zero_cost_sold_qty_snapshot numeric DEFAULT 0 NOT NULL;
CREATE TABLE public.bb_postclose_reversal_routes(
 return_id text PRIMARY KEY,invoice_id text NOT NULL,
 original_batch_id text NOT NULL);
-- Prior historical return P1/Z1 already exists in synthetic stock_activity;
-- initialize snapshot to the resulting remaining sold position P2/Z1.
UPDATE public.stock_batch_items SET
 sold_qty_snapshot=3,pending_qty_snapshot=37,
 purchased_sold_qty_snapshot=2,zero_cost_sold_qty_snapshot=1,
 purchased_pending_qty_snapshot=18,zero_cost_pending_qty_snapshot=19
WHERE batch_id='BB-CI-BATCH' AND product_code='BB-CI-PRODUCT';
UPDATE public.stock_batches SET sold_qty=3
WHERE batch_id='BB-CI-BATCH';
\echo 'Synthetic open-Batch reversal source balances and tables ready'
