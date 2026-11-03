-- BIG BROTHER V2: SYNTHETIC historical gross cash + executed refund rows.
-- NOT A CASH-CLOSE SELECTION API. DO NOT DEPLOY.
-- Requires bb_ci_refund_requests and synthetic Vault / Daily Cash ledgers.
\set ON_ERROR_STOP on
CREATE OR REPLACE FUNCTION public.bb_ci_refund_reconciliation_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO '' AS $body$
DECLARE
 v jsonb;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'CI Reconciliation cannot run outside synthetic DB';
 END IF;
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.app_users WHERE user_id=auth.uid() AND active=true
 ) THEN RAISE EXCEPTION 'CI reconciliation requires authenticated test actor'; END IF;
 WITH approved AS (
   SELECT d.invoice_id, i.invoice_no, i.customer_id,
    coalesce(sum(d.invoice_cash_amount),0)::numeric AS approved_cash_usd,
    coalesce(max(i.grand_total),0) AS original_invoice_value_usd,
    coalesce(max(i.reversal_amount),0) AS reversal_usd,
    greatest(coalesce(max(i.grand_total),0)-coalesce(max(i.reversal_amount),0),0) AS net_sale_usd
   FROM public.daily_cash_close_invoices d
   JOIN public.daily_cash_closes c ON c.close_id=d.close_id
   JOIN public.invoices i ON i.invoice_id=d.invoice_id
   WHERE lower(trim(coalesce(c.status,'')))='approved'
     AND upper(coalesce(i.currency,'USD'))='USD'
     AND lower(trim(coalesce(i.payment_method,'')))='cash'
   GROUP BY d.invoice_id,i.invoice_no,i.customer_id
 ),
 settled AS (
   SELECT r.invoice_id,
    coalesce(sum(r.amount_usd) FILTER(WHERE r.cash_source='CASH_VAULT' AND
      EXISTS(SELECT 1 FROM public.cash_vault_ledger v
        WHERE v.vault_entry_id=r.ledger_entry_id AND v.entry_type='OUT'
          AND v.usd_amount=r.amount_usd AND v.source='INVOICE_REVERSAL_REFUND')),0) AS vault_refund_usd,
    coalesce(sum(r.amount_usd) FILTER(WHERE r.cash_source='DAILY_CASH' AND
      EXISTS(SELECT 1 FROM public.daily_cash_ledger l
        WHERE l.daily_cash_entry_id=r.ledger_entry_id AND l.entry_type='OUT'
          AND l.currency='USD' AND l.amount=r.amount_usd
          AND l.source='INVOICE_REVERSAL_REFUND')),0) AS wallet_refund_usd
   FROM public.bb_ci_refund_requests r WHERE r.status='Executed'
   GROUP BY r.invoice_id
 ), totals AS (
   SELECT a.*,
     coalesce(s.vault_refund_usd,0) AS vault_refund_usd,
     coalesce(s.wallet_refund_usd,0) AS wallet_refund_usd,
     (coalesce(s.vault_refund_usd,0)+coalesce(s.wallet_refund_usd,0)) AS cash_refund_out_usd
   FROM approved a LEFT JOIN settled s ON s.invoice_id=a.invoice_id
 ), returns AS (
  SELECT *,
    greatest(approved_cash_usd-cash_refund_out_usd,0) AS net_cash_retained_usd,
    greatest(approved_cash_usd-net_sale_usd-cash_refund_out_usd,0) AS refund_review_remaining_usd
  FROM totals
 )
 SELECT jsonb_build_object(
  'success',true,
  'viewType','APPROVED_DAILY_CASH_HISTORY_NOT_SELECTABLE',
  'cashClosings',coalesce(jsonb_agg(jsonb_build_object(
   'invoiceId',invoice_id,'invoiceNo',invoice_no,'customerId',customer_id,
   'originalApprovedCashUSD',approved_cash_usd,
   'reversalUSD',reversal_usd,'netSaleUSD',net_sale_usd,
   'vaultRefundOUTUSD',vault_refund_usd,'dailyCashRefundOUTUSD',wallet_refund_usd,
   'totalRefundOUTUSD',cash_refund_out_usd,
   'netCashRetainedUSD',net_cash_retained_usd,
   'refundReviewRemainingUSD',refund_review_remaining_usd,
   'selectableForClose',false
  ) ORDER BY invoice_id),'[]'::jsonb)
 ) INTO v FROM returns;
 RETURN v;
END;
$body$;
REVOKE ALL ON FUNCTION public.bb_ci_refund_reconciliation_v1() FROM PUBLIC;
