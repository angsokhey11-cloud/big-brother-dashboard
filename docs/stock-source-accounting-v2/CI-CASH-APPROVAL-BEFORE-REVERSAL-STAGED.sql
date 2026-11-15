-- BIG BROTHER Stock Source V2 — cash collection approval gate for invoice reversal.
-- STAGED ONLY. Do not execute against Cloud production or real Local.
-- Separate future Invoice Cancellation workflow is OUT OF SCOPE.
--
-- The accountant's rule:
-- - Original invoice containing cash collection MUST be APPROVED via Daily Cash
--   Collection before any return is posted.
-- - Approval state is daily_cash_closes.status='Approved', linked through
--   daily_cash_close_invoices.invoice_id (identity is Invoice ID, not Invoice No).
-- - Approved closings and their original cash receipts must never be deleted;
--   any actual refund requires a separate, auditable payout transaction.
--
-- This guard covers all insert paths including the by-ID, legacy, and post-close
-- Reversal RPCs. It deliberately DOES NOT issue a refund or change a cash ledger.
CREATE OR REPLACE FUNCTION public.bb_v2_reversal_require_approved_cash_close()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_inv public.invoices%rowtype;
  v_is_invoice_cash boolean;
  v_approved boolean;
BEGIN
  SELECT * INTO v_inv
    FROM public.invoices
   WHERE invoice_id=NEW.invoice_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice not found for cash collection approval check';
  END IF;

  -- Real original invoice cash, not subsequently received Credit A/R cash:
  -- original Cash/Cash + Bank/Partially Paid in Cash invoice methods, OR
  -- a positive invoice-originated Cash payment row.
  SELECT
    lower(trim(coalesce(v_inv.payment_method,''))) IN
      ('cash','cash + bank','partially paid in cash')
    OR EXISTS(
      SELECT 1 FROM public.payments p
       WHERE p.invoice_id=v_inv.invoice_id
         AND lower(trim(coalesce(p.payment_source,'')))='invoice'
         AND lower(trim(coalesce(p.payment_method,'')))='cash'
         AND coalesce(p.amount,0)>0
    )
    INTO v_is_invoice_cash;

  IF v_is_invoice_cash THEN
    SELECT EXISTS(
      SELECT 1 FROM public.daily_cash_close_invoices d
        JOIN public.daily_cash_closes c ON c.close_id=d.close_id
       WHERE d.invoice_id=v_inv.invoice_id
         AND lower(trim(coalesce(c.status,'')))='approved'
    ) INTO v_approved;
    IF NOT v_approved THEN
      RAISE EXCEPTION
        'Invoice % has original Cash collection not yet approved in Daily Cash Collection. Approve Daily Cash Collection before Reversal.',
        v_inv.invoice_no;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- Trigger-only helper; no need to expose EXECUTE to public app callers.
REVOKE ALL ON FUNCTION public.bb_v2_reversal_require_approved_cash_close() FROM PUBLIC;

-- NOTE: install this trigger ONLY as part of a future reviewed migration.
-- Testing creates this trigger in a disposable synthetic database, not here.
-- CREATE TRIGGER trg_bb_v2_reversal_cash_approval
--   BEFORE INSERT ON public.sales_returns
--   FOR EACH ROW EXECUTE FUNCTION public.bb_v2_reversal_require_approved_cash_close();
