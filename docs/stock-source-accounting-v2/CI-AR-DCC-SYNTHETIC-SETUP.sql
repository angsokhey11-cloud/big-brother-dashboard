-- BIG BROTHER: synthetic A/R + Cash Collection full-reversal audit.
-- Run ONLY in disposable bb_stock_v2_sandbox after stock-source CI fixtures.
-- Real Cloud definitions are installed separately from
-- CI-CLOUD-AR-DCC-CURRENT-FUNCTIONS-READONLY.sql.
\set ON_ERROR_STOP on

ALTER TABLE public.invoices
 ADD COLUMN discount numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN note text,
 ADD COLUMN subtotal numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN grand_total numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN reversal_amount numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN amount_paid numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN outstanding numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN credit_amount numeric(18,2) DEFAULT 0 NOT NULL,
 ADD COLUMN payment_method text,
 ADD COLUMN status text,
 ADD COLUMN currency text DEFAULT 'USD',
 ADD COLUMN exchange_rate numeric DEFAULT 4000,
 ADD COLUMN invoice_date date DEFAULT current_date,
 ADD COLUMN batch_number text,
 ADD COLUMN shipping_to_legacy text,
 ADD COLUMN due_date date;
CREATE TABLE public.customers (
 customer_id text PRIMARY KEY, location_code text,phone text,address text
);
CREATE TABLE public.payments(
 payment_id text PRIMARY KEY,invoice_id text NOT NULL,
 payment_date date, created_at timestamptz DEFAULT now(),
 currency text, exchange_rate numeric,
 amount numeric(18,2), payment_method text,payment_source text
);
CREATE TABLE public.ar_payment_requests(
 request_id text PRIMARY KEY,status text,
 reviewed_by_name_snapshot text,reviewed_by_user_id uuid,
 reviewed_at timestamptz,reject_reason text,updated_at timestamptz
);
CREATE TABLE public.ar_request_allocations(
 request_id text NOT NULL,invoice_id text NOT NULL
);
-- Only in disposable CI: allow the synthetic test actor to view Daily Cash.
CREATE OR REPLACE FUNCTION public.bb_has_module_access(p_module text,p_action text)
 RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT public.bb_is_active_user()
   AND p_module IN ('invoice_reversal','daily_cash_collection')
   AND p_action IN ('view','create')
$$;
CREATE FUNCTION public.bb_dcc_revision() RETURNS text
 LANGUAGE sql STABLE AS $$ SELECT 'CI-DCC-REVISION'::text $$;
CREATE FUNCTION public.bb_dcc_access_profile() RETURNS jsonb
 LANGUAGE sql STABLE AS $$ SELECT '{"synthetic":true}'::jsonb $$;

INSERT INTO public.customers(customer_id,location_code,phone,address)
VALUES ('BB-CI-AR-CUSTOMER','BB-SALES-TEST','','');
INSERT INTO public.invoices(
 invoice_id,invoice_no,customer_id,customer_name_snapshot,location_code,
 subtotal,grand_total,amount_paid,outstanding,credit_amount,
 payment_method,status,currency,invoice_date
) VALUES
('BB-CI-AR-PART','CI-AR-PART','BB-CI-AR-CUSTOMER','Synthetic','BB-SALES-TEST',
 100,100,40,60,60,'Credit','Processing','USD',current_date),
('BB-CI-AR-OVER','CI-AR-OVER','BB-CI-AR-CUSTOMER','Synthetic','BB-SALES-TEST',
 100,100,90,10,10,'Credit','Processing','USD',current_date),
('BB-CI-AR-MULTI','CI-AR-MULTI','BB-CI-AR-CUSTOMER','Synthetic','BB-SALES-TEST',
 100,100,25,75,75,'Credit','Processing','USD',current_date),
('BB-CI-DCC-CASH','CI-DCC-CASH','BB-CI-AR-CUSTOMER','Synthetic','BB-SALES-TEST',
 100,100,100,0,0,'Cash','Paid','USD',current_date);
INSERT INTO public.ar_payment_requests(request_id,status)
VALUES ('BB-CI-AR-REQUEST','Processing');
INSERT INTO public.ar_request_allocations(request_id,invoice_id)
VALUES ('BB-CI-AR-REQUEST','BB-CI-AR-PART');
INSERT INTO public.payments(payment_id,invoice_id,payment_date,
 currency,exchange_rate,amount,payment_method,payment_source)
VALUES ('BB-CI-CASH-PAY','BB-CI-DCC-CASH',current_date,
 'USD',4000,100,'Cash','Invoice');
\echo 'CI synthetic A/R and Cash Collection fixtures ready, no business records'
