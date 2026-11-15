-- CI synthetic post-close reversal infrastructure (test DB ONLY).
-- Extends the earlier Back Sale -> source snapshot -> open-Batch test setup.
\set ON_ERROR_STOP on
ALTER TABLE public.invoices ADD COLUMN salesperson_staff_id text;
ALTER TABLE public.invoices ADD COLUMN salesperson_name_snapshot text;
ALTER TABLE public.sales_returns ADD COLUMN qty numeric(18,4);
ALTER TABLE public.bb_postclose_reversal_routes ADD COLUMN destinations jsonb;
CREATE TABLE public.stock_cutover_state (
 state_id text PRIMARY KEY, default_warehouse_location_code text
);
INSERT INTO public.stock_cutover_state(state_id,default_warehouse_location_code)
VALUES('MAIN','BB-WH-TEST');
CREATE TABLE public.bb_postclose_reversal_allocations (
 return_id text NOT NULL,invoice_id text NOT NULL,original_batch_id text NOT NULL,
 product_code text NOT NULL,stock_source text NOT NULL,qty numeric NOT NULL,
 destination_type text NOT NULL,destination_batch_id text,
 destination_location text,stock_transaction_id text NOT NULL
);
-- Original Batch becomes Closed. Its historical stock source quantities remain.
UPDATE public.stock_batches SET status='Closed'
WHERE batch_id='BB-CI-BATCH';
INSERT INTO public.stock_batches(batch_id,batch_date,location_code,location_name_snapshot,
 status,issued_qty) VALUES
('BB-CI-DEST',CURRENT_DATE,'BB-SALES-TEST','Synthetic Sales Route','Open',0),
('BB-CI-WRONG-LOC',CURRENT_DATE,'BB-WH-TEST','Synthetic Warehouse','Open',0);
INSERT INTO public.stock_batch_items(batch_id,product_code,
 product_name_snapshot,unit_snapshot,pending_qty_snapshot,
 purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
) VALUES
('BB-CI-DEST','BB-CI-PRODUCT','Synthetic 2L Milk','bottle',0,0,0),
('BB-CI-WRONG-LOC','BB-CI-PRODUCT','Synthetic 2L Milk','bottle',0,0,0);
\echo 'CI synthetic closed original Batch / open same-location target ready'
