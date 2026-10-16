-- LOCAL V3.4: restore only the missing bank balance view; no business-data writes.
-- Use the controller backup and approved single-transaction SQL runner.
DO $repair$
BEGIN
 IF to_regclass('public.bb_verified_bank_transactions') IS NULL
    OR to_regclass('public.bb_bank_balance_allocations') IS NULL THEN
    RAISE EXCEPTION 'BANK VIEW SAFE STOP: missing bank dependency table';
 END IF;
 IF to_regclass('public.bb_bank_balance_snapshot') IS NULL THEN
   EXECUTE $view$
     CREATE VIEW public.bb_bank_balance_snapshot AS
     SELECT t.transaction_id, t.customer_id, t.currency, t.invoice_currency,
            t.approved_exchange_rate, t.received_date, t.amount AS original_amount,
            CASE WHEN t.status='USED' THEN t.amount
                 WHEN t.status='CANCELLED' THEN 0::numeric
                 ELSE COALESCE(sum(a.applied_bank_amount) FILTER (WHERE a.reversed_at IS NULL),0::numeric)
            END AS used_amount,
            CASE WHEN t.status='AVAILABLE'
                 THEN greatest(0::numeric,t.amount-COALESCE(sum(a.applied_bank_amount)
                      FILTER (WHERE a.reversed_at IS NULL),0::numeric))
                 ELSE 0::numeric
            END AS remaining_amount,
            t.status
     FROM public.bb_verified_bank_transactions t
     LEFT JOIN public.bb_bank_balance_allocations a ON a.transaction_id=t.transaction_id
     GROUP BY t.transaction_id
   $view$;
 END IF;
 IF NOT EXISTS (
   SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname='bb_bank_balance_snapshot' AND c.relkind='v'
 ) THEN
   RAISE EXCEPTION 'BANK VIEW SAFE STOP: conflicting relation';
 END IF;
 IF position('bb_bank_balance_allocations' IN
    pg_get_viewdef('public.bb_bank_balance_snapshot'::regclass,true))=0 THEN
   RAISE EXCEPTION 'BANK VIEW SAFE STOP: snapshot definition mismatch';
 END IF;
 RAISE NOTICE 'BANK_BALANCE_SNAPSHOT_VIEW_OK';
END
$repair$;
