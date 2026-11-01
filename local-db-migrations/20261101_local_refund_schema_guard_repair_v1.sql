-- V3.4 LOCAL-ONLY REFUND SCHEMA MIGRATION. Code Sync provides backup and transaction.
SET LOCAL lock_timeout='8s';
SET LOCAL statement_timeout='60s';
DO $guard$ BEGIN
 IF current_database()<>'postgres' OR to_regclass('public.invoices') IS NULL OR to_regclass('public.daily_cash_closes') IS NULL THEN RAISE EXCEPTION 'Unexpected Local database'; END IF;
END $guard$;
ALTER TABLE public.daily_cash_closes ADD COLUMN IF NOT EXISTS gross_expected_usd numeric, ADD COLUMN IF NOT EXISTS salesman_refund_deduction_usd numeric NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS public.bb_invoice_direct_refunds (
 refund_id text PRIMARY KEY, invoice_id text NOT NULL REFERENCES public.invoices(invoice_id),
 refund_date date NOT NULL DEFAULT CURRENT_DATE, method text NOT NULL CHECK(method IN ('DAILY_CASH','BANK','SALESMAN_COLLECTION')),
 currency text NOT NULL CHECK(currency IN ('USD','KHR')), amount numeric NOT NULL CHECK(amount>0),
 exchange_rate numeric NOT NULL CHECK(exchange_rate>0), amount_invoice_currency numeric NOT NULL CHECK(amount_invoice_currency>0),
 bank_account text,bank_transaction_id text,cash_ledger_id text,reason text,created_by uuid,created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT bank_refund_reference_required CHECK(method<>'BANK' OR (nullif(trim(bank_account),'') IS NOT NULL AND nullif(trim(bank_transaction_id),'') IS NOT NULL)),
 CONSTRAINT no_bank_details_cash CHECK(method<>'DAILY_CASH' OR (bank_account IS NULL AND bank_transaction_id IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS bb_refunds_bank_tx_unique ON public.bb_invoice_direct_refunds(lower(trim(bank_transaction_id))) WHERE bank_transaction_id IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.bb_bank_refund_ledger (
 refund_id text PRIMARY KEY REFERENCES public.bb_invoice_direct_refunds(refund_id),
 invoice_id text NOT NULL REFERENCES public.invoices(invoice_id),bank_account text NOT NULL,transaction_id text NOT NULL,
 amount numeric NOT NULL,currency text NOT NULL,exchange_rate numeric NOT NULL,entry_at timestamptz NOT NULL DEFAULT now(),
 direction text NOT NULL DEFAULT 'OUT',created_by uuid
);
CREATE UNIQUE INDEX IF NOT EXISTS bb_bank_refund_ledger_tx_unique ON public.bb_bank_refund_ledger(lower(trim(transaction_id)));
CREATE TABLE IF NOT EXISTS public.bb_closed_collection_refund_adjustments (
 refund_id text PRIMARY KEY REFERENCES public.bb_invoice_direct_refunds(refund_id),
 close_id text NOT NULL REFERENCES public.daily_cash_closes(close_id),
 invoice_id text NOT NULL REFERENCES public.invoices(invoice_id),adjustment_usd numeric NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),created_by uuid
);
CREATE TABLE IF NOT EXISTS public.bb_salesman_refund_deductions (
 refund_id text PRIMARY KEY REFERENCES public.bb_invoice_direct_refunds(refund_id),
 invoice_id text NOT NULL REFERENCES public.invoices(invoice_id),salesman_staff_id text NOT NULL,
 location_code text NOT NULL,amount_usd numeric NOT NULL,
 status text NOT NULL DEFAULT 'AVAILABLE' CHECK(status IN ('AVAILABLE','CLAIMED','USED')),
 close_id text REFERENCES public.daily_cash_closes(close_id),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
-- Archive is schema-compatible but not an accounting balance source.
CREATE TABLE IF NOT EXISTS public.bb_test_cleanup_archive_20261101 (
 archive_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,cleanup_key text NOT NULL,
 table_name text NOT NULL,row_data jsonb NOT NULL,archived_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS bb_test_cleanup_archive_unique ON public.bb_test_cleanup_archive_20261101(cleanup_key,table_name,md5(row_data::text));
ALTER TABLE public.bb_invoice_direct_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_bank_refund_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_closed_collection_refund_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_salesman_refund_deductions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_test_cleanup_archive_20261101 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_invoice_direct_refunds,public.bb_bank_refund_ledger,public.bb_closed_collection_refund_adjustments,public.bb_salesman_refund_deductions,public.bb_test_cleanup_archive_20261101 FROM PUBLIC,anon,authenticated;
DO $verify$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['bb_invoice_direct_refunds','bb_bank_refund_ledger','bb_closed_collection_refund_adjustments','bb_salesman_refund_deductions','bb_test_cleanup_archive_20261101'] LOOP
 IF to_regclass('public.'||t) IS NULL THEN RAISE EXCEPTION 'Missing refund table %',t; END IF; END LOOP;
END $verify$;
