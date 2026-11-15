-- BIG BROTHER: synthetic cash refund funding environment (NOT production).
-- Requires previous synthetic Finance and Cash Approval setup and triggers.
-- Invoice source: $100 paid Cash, $80 partial reversal after Approved DCC.
-- Approved DCC cash collected into Cash Vault; $40 transferred to Daily Cash.
\set ON_ERROR_STOP on
CREATE TABLE public.cash_vault_ledger (
 vault_entry_id text PRIMARY KEY, entry_at timestamptz NOT NULL DEFAULT now(),
 entry_type text NOT NULL, source text, close_id text, transaction_id text,
 usd_amount numeric NOT NULL DEFAULT 0,
 khr_amount numeric NOT NULL DEFAULT 0,
 exchange_rate numeric NOT NULL DEFAULT 1,
 usd_equivalent numeric NOT NULL DEFAULT 0,
 note text
);
CREATE TABLE public.daily_cash_ledger (
 daily_cash_entry_id text PRIMARY KEY, entry_at timestamptz NOT NULL DEFAULT now(),
 entry_type text NOT NULL, source text NOT NULL,
 reference_type text NOT NULL, reference_id text NOT NULL,
 currency text NOT NULL, amount numeric NOT NULL,
 exchange_rate numeric NOT NULL, amount_usd numeric NOT NULL,
 note text
);
CREATE TABLE public.bb_ci_refund_requests (
 request_key text PRIMARY KEY,
 invoice_id text NOT NULL,
 cash_source text NOT NULL CHECK (cash_source IN ('CASH_VAULT','DAILY_CASH','BANK')),
 amount_usd numeric(18,2) NOT NULL CHECK (amount_usd>0),
 status text NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending','Approved','Executed','Rejected')),
 approved_by uuid,
 approved_at timestamptz,
 ledger_entry_id text UNIQUE,
 executed_at timestamptz
);
-- First populate synthetic APPROVED Daily Cash Close and a real reversal.
INSERT INTO public.daily_cash_closes(close_id,status,expected_usd)
VALUES ('BB-CI-REF-CLOSE','Approved',100);
INSERT INTO public.daily_cash_close_invoices
  (close_invoice_id,close_id,invoice_id,invoice_cash_amount)
VALUES('BB-CI-REF-LINK','BB-CI-REF-CLOSE','BB-CI-DCC-CASH',100);
INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
VALUES('BB-CI-REF-ORIGINAL-RETURN','BB-CI-DCC-CASH','BB-CI-REF-LINE',1,80);
-- Physical route is explicit: DCC -> Vault $100, Vault -> Daily Wallet $40.
INSERT INTO public.cash_vault_ledger
 (vault_entry_id,entry_type,source,close_id,usd_amount,usd_equivalent)
VALUES
 ('BB-CI-VAULT-RECEIPT','IN','Daily Cash','BB-CI-REF-CLOSE',100,100),
 ('BB-CI-VAULT-TRANSFER','OUT','Daily Cash Wallet',NULL,40,40);
INSERT INTO public.daily_cash_ledger
 (daily_cash_entry_id,entry_type,source,reference_type,reference_id,
  currency,amount,exchange_rate,amount_usd)
VALUES
 ('BB-CI-DAILY-IN','IN','CASH VAULT','VAULT_TRANSFER','BB-CI-VTX',
 'USD',40,1,40);
INSERT INTO public.bb_ci_refund_requests(request_key,invoice_id,cash_source,amount_usd)
VALUES
 ('BB-CI-REF-VAULT-30','BB-CI-DCC-CASH','CASH_VAULT',30),
 ('BB-CI-REF-DAILY-20','BB-CI-DCC-CASH','DAILY_CASH',20),
 ('BB-CI-REF-EXCESS-40','BB-CI-DCC-CASH','CASH_VAULT',40),
 ('BB-CI-REF-BANK-10','BB-CI-DCC-CASH','BANK',10),
 ('BB-CI-REF-NOTAPPROVED','BB-CI-DCC-CASH','DAILY_CASH',5),
 ('BB-CI-REF-WRONGINVOICE','BB-CI-BANK-ONLY','CASH_VAULT',10);
\echo 'Synthetic Approved DCC + $80 Reversal + Vault/Wallet funding ready (all fake records)'
