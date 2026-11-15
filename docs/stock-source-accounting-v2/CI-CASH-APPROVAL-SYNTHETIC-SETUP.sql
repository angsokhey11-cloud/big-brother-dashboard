-- Synthetic Daily Cash approval state only: no real company cash or receipts.
\set ON_ERROR_STOP on
CREATE TABLE public.daily_cash_closes(
 close_id text PRIMARY KEY,
 status text NOT NULL,
 expected_usd numeric(18,2) NOT NULL DEFAULT 0
);
CREATE TABLE public.daily_cash_close_invoices(
 close_invoice_id text PRIMARY KEY,
 close_id text NOT NULL,
 invoice_id text NOT NULL,
 invoice_cash_amount numeric(18,2) NOT NULL DEFAULT 0
);
-- Existing DCC cash invoice has a $100 original CASH payment but no approval.
INSERT INTO public.invoices(
 invoice_id,invoice_no,customer_id,location_code,payment_method,
 subtotal,grand_total,amount_paid,outstanding,credit_amount,status,currency
) VALUES
('BB-CI-CASH-PENDING','CI-CASH-PENDING','BB-CI-AR-CUSTOMER','BB-SALES-TEST',
 'Cash + Bank',100,100,100,0,0,'Paid','USD'),
('BB-CI-CASH-REJECTED','CI-CASH-REJECTED','BB-CI-AR-CUSTOMER','BB-SALES-TEST',
 'Partially Paid in Cash',100,100,100,0,0,'Paid','USD'),
('BB-CI-BANK-ONLY','CI-BANK-ONLY','BB-CI-AR-CUSTOMER','BB-SALES-TEST',
 'Bank',100,100,100,0,0,'Paid','USD');
INSERT INTO public.daily_cash_closes(close_id,status,expected_usd) VALUES
('BB-CI-CLOSE-PENDING','Pending',100),
('BB-CI-CLOSE-REJECTED','Rejected',100);
INSERT INTO public.daily_cash_close_invoices(
 close_invoice_id,close_id,invoice_id,invoice_cash_amount
) VALUES
('BB-CI-CLOSE-LINK-P','BB-CI-CLOSE-PENDING','BB-CI-CASH-PENDING',40),
('BB-CI-CLOSE-LINK-R','BB-CI-CLOSE-REJECTED','BB-CI-CASH-REJECTED',50);
\echo 'Synthetic Daily Cash Close Pending / Rejected / unapproved Cash and Bank records ready'
