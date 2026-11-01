-- SYNTHETIC ONLY: extends the disposable Back Sale stock test schema.
-- Testing real staged read-only reversal-source snapshot against sale/return
-- ledger history; no real invoices/customers or production connection.
\set ON_ERROR_STOP on
ALTER TABLE public.stock_activity ADD COLUMN customer_id text;
ALTER TABLE public.stock_activity ADD COLUMN related_invoice_no text;
CREATE TABLE public.invoices(
 invoice_id text PRIMARY KEY,invoice_no text NOT NULL,
 customer_id text,location_code text NOT NULL,batch_id text
);
CREATE TABLE public.invoice_lines(
 line_id text PRIMARY KEY,invoice_id text NOT NULL,product_code text
);
CREATE TABLE public.sales_returns(
 return_id text PRIMARY KEY,invoice_id text NOT NULL,line_id text NOT NULL
);
CREATE FUNCTION public.bb_is_active_user() RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT EXISTS(SELECT 1 FROM public.app_users WHERE user_id=auth.uid() AND active)
$$;
-- CI-only module-access stub: requires an active synthetic test user;
-- NOT a substitute for production module access / RLS integration.
CREATE FUNCTION public.bb_has_module_access(p_module text,p_action text)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT public.bb_is_active_user() AND p_module='invoice_reversal'
   AND p_action IN ('view','create')
$$;
INSERT INTO public.invoices(invoice_id,invoice_no,customer_id,location_code,batch_id)
VALUES
('BB-CI-INV','BB-CI-INVOICE-NO','BB-CI-CUSTOMER','BB-SALES-TEST','BB-CI-BATCH'),
('BB-CI-DIRECT','BB-CI-DIRECT-NO','BB-CI-CUSTOMER','BB-SALES-TEST',NULL);
INSERT INTO public.invoice_lines(line_id,invoice_id,product_code)
VALUES('BB-CI-LINE','BB-CI-INV','BB-CI-PRODUCT');
-- Two original sale-source movements, as written by the V2 invoice trigger.
INSERT INTO public.stock_activity(transaction_id,activity_date,activity_type,
 product_code,batch_id,related_invoice_no,customer_id,qty,
 from_bucket,to_bucket,movement_type,client_request_id,unit_cost,line_value)
VALUES
('BB-CI-SOLD-P',CURRENT_DATE,'Invoice','BB-CI-PRODUCT','BB-CI-BATCH',
 'BB-CI-INVOICE-NO','BB-CI-CUSTOMER',3,'BATCH_PENDING','EXTERNAL','BATCH_SALE',
 'BATCH-INVOICE:BB-CI-LINE:BB-CI-PRODUCT:PURCHASED',3.2825,9.85),
('BB-CI-SOLD-Z',CURRENT_DATE,'Invoice','BB-CI-PRODUCT','BB-CI-BATCH',
 'BB-CI-INVOICE-NO','BB-CI-CUSTOMER',2,'BATCH_ZERO_COST','EXTERNAL','BATCH_SALE',
 'BATCH-INVOICE:BB-CI-LINE:BB-CI-PRODUCT:ZERO',0,0);
INSERT INTO public.sales_returns(return_id,invoice_id,line_id)
VALUES('BB-CI-RETURN','BB-CI-INV','BB-CI-LINE');
INSERT INTO public.stock_activity(transaction_id,activity_date,activity_type,
 product_code,batch_id,reference_no,qty,from_bucket,to_bucket,movement_type,
 unit_cost,line_value)
VALUES
('BB-CI-RETURN-P',CURRENT_DATE,'Reversal','BB-CI-PRODUCT','BB-CI-BATCH',
 'BB-CI-RETURN',1,'EXTERNAL','BATCH_PENDING','BATCH_SALE_RETURN',3.2825,3.28),
('BB-CI-RETURN-Z',CURRENT_DATE,'Reversal','BB-CI-PRODUCT','BB-CI-BATCH',
 'BB-CI-RETURN',1,'EXTERNAL','BATCH_ZERO_COST','BATCH_SALE_RETURN',0,0);
\echo 'CI synthetic sale-origin and partial reversal history ready'
