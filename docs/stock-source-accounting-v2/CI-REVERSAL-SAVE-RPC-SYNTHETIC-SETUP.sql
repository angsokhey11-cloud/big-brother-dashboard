-- BIG BROTHER: synthetic full Reversal SAVE RPC integration harness setup.
-- Runs AFTER stock source/snapshot/open/closed trigger synthetic tests.
-- Absolutely no real Cloud/Local data, all fixture rows are invented.
\set ON_ERROR_STOP on
ALTER TABLE public.invoice_lines
 ADD COLUMN qty numeric(18,4) DEFAULT 0 NOT NULL,
 ADD COLUMN line_no integer DEFAULT 1 NOT NULL,
 ADD COLUMN unit_price numeric(18,4) DEFAULT 1 NOT NULL,
 ADD COLUMN product_name_snapshot text,
 ADD COLUMN display_product_code text,
 ADD COLUMN product_group_code text,
 ADD COLUMN entry_type text DEFAULT 'EXACT' NOT NULL,
 ADD COLUMN stock_allocation_json jsonb;
ALTER TABLE public.sales_returns
 ADD COLUMN invoice_no_snapshot text,
 ADD COLUMN customer_id text,
 ADD COLUMN customer_name_snapshot text,
 ADD COLUMN location_code text,
 ADD COLUMN salesperson_staff_id text,
 ADD COLUMN salesperson_name_snapshot text,
 ADD COLUMN product_code text,
 ADD COLUMN product_group_code text,
 ADD COLUMN product_name_snapshot text,
 ADD COLUMN unit_price numeric(18,4),
 ADD COLUMN return_amount numeric(18,2),
 ADD COLUMN return_type text,
 ADD COLUMN reason text,
 ADD COLUMN note text,
 ADD COLUMN source_created_at timestamptz;
ALTER TABLE public.bb_postclose_reversal_routes ADD COLUMN created_by uuid;
CREATE TABLE public.product_groups(group_code text PRIMARY KEY);
CREATE TABLE public.sales_database_edit_history(
 audit_id text PRIMARY KEY,occurred_at timestamptz,
 module text,record_id text,record_no text,
 action text,field_name text,old_value text,new_value text,reason text,
 admin_legacy_id text,admin_name_snapshot text);
-- This is a CI-only revision stub. Production logic is NOT replaced.
CREATE FUNCTION public.bb_sales_history_revision() RETURNS text
LANGUAGE sql AS $$SELECT 'CI-SALES-HISTORY-REVISION'::text$$;
-- Prepared synthetic original invoices. One Open and one Closed Batch, both
-- 3 Purchased + 2 Zero-Cost original physical sales, each $9.85 Purchased COGS.
INSERT INTO public.stock_batches(
 batch_id,batch_date,location_code,location_name_snapshot,status,
 issued_qty,sold_qty
) VALUES
('BB-CI-RPC-OPEN',CURRENT_DATE,'BB-SALES-TEST','Synthetic Route','Open',5,5),
('BB-CI-RPC-CLOSED',CURRENT_DATE,'BB-SALES-TEST','Synthetic Route','Closed',5,5);
INSERT INTO public.stock_batch_items(
 batch_id,product_code,product_name_snapshot,unit_snapshot,
 issued_qty,sold_qty_snapshot,pending_qty_snapshot,
 purchased_issued_qty,zero_cost_issued_qty,
 purchased_sold_qty_snapshot,zero_cost_sold_qty_snapshot,
 purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
) VALUES
('BB-CI-RPC-OPEN','BB-CI-PRODUCT','Synthetic 2L Milk','bottle',5,5,0,3,2,3,2,0,0),
('BB-CI-RPC-CLOSED','BB-CI-PRODUCT','Synthetic 2L Milk','bottle',5,5,0,3,2,3,2,0,0);
INSERT INTO public.invoices(invoice_id,invoice_no,customer_id,customer_name_snapshot,location_code,batch_id)
VALUES
('BB-CI-RPC-INV-OPEN','BB-CI-DUPLICATE-9','BB-CI-CUSTOMER-1','Synthetic Customer 1','BB-SALES-TEST','BB-CI-RPC-OPEN'),
('BB-CI-RPC-INV-CLOSED','BB-CI-DUPLICATE-9','BB-CI-CUSTOMER-2','Synthetic Customer 2','BB-SALES-TEST','BB-CI-RPC-CLOSED');
INSERT INTO public.invoice_lines(
 line_id,invoice_id,product_code,qty,line_no,unit_price,
 product_name_snapshot,display_product_code,entry_type
) VALUES
('BB-CI-RPC-LINE-OPEN','BB-CI-RPC-INV-OPEN','BB-CI-PRODUCT',5,1,2.50,'Synthetic 2L Milk','BB-CI-PRODUCT','EXACT'),
('BB-CI-RPC-LINE-CLOSED','BB-CI-RPC-INV-CLOSED','BB-CI-PRODUCT',5,1,2.50,'Synthetic 2L Milk','BB-CI-PRODUCT','EXACT');
INSERT INTO public.stock_activity(
 transaction_id,batch_id,activity_date,activity_type,
 product_code,related_invoice_no,customer_id,qty,
 from_bucket,to_bucket,movement_type,client_request_id,unit_cost,line_value
) VALUES
('BB-CI-RPC-OPEN-P','BB-CI-RPC-OPEN',CURRENT_DATE,'Invoice','BB-CI-PRODUCT','BB-CI-DUPLICATE-9','BB-CI-CUSTOMER-1',3,
 'BATCH_PENDING','EXTERNAL','BATCH_SALE','BATCH-INVOICE:BB-CI-RPC-LINE-OPEN:BB-CI-PRODUCT:PURCHASED',3.2825,9.85),
('BB-CI-RPC-OPEN-Z','BB-CI-RPC-OPEN',CURRENT_DATE,'Invoice','BB-CI-PRODUCT','BB-CI-DUPLICATE-9','BB-CI-CUSTOMER-1',2,
 'BATCH_ZERO_COST','EXTERNAL','BATCH_SALE','BATCH-INVOICE:BB-CI-RPC-LINE-OPEN:BB-CI-PRODUCT:ZERO',0,0),
('BB-CI-RPC-CLOSED-P','BB-CI-RPC-CLOSED',CURRENT_DATE,'Invoice','BB-CI-PRODUCT','BB-CI-DUPLICATE-9','BB-CI-CUSTOMER-2',3,
 'BATCH_PENDING','EXTERNAL','BATCH_SALE','BATCH-INVOICE:BB-CI-RPC-LINE-CLOSED:BB-CI-PRODUCT:PURCHASED',3.2825,9.85),
('BB-CI-RPC-CLOSED-Z','BB-CI-RPC-CLOSED',CURRENT_DATE,'Invoice','BB-CI-PRODUCT','BB-CI-DUPLICATE-9','BB-CI-CUSTOMER-2',2,
 'BATCH_ZERO_COST','EXTERNAL','BATCH_SALE','BATCH-INVOICE:BB-CI-RPC-LINE-CLOSED:BB-CI-PRODUCT:ZERO',0,0);
\echo 'CI synthetic full-save RPC fixture prepared (same Invoice No, DIFFERENT invoice IDs/customers)'
