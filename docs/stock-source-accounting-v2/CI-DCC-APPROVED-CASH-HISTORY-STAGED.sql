-- BIG BROTHER V2 — approved Daily Cash historical reconciliation (STAGED).
-- TEST-ONLY FUNCTION. Not a selectable Close Selected invoice list, not a
-- refund-posting endpoint, not an approval action, and not a production migration.
-- Source of clearance: daily_cash_closes.status='Approved' + close_invoice_id
-- joins on immutable invoice_id. Preserve approved cash even after full Reversal.
CREATE OR REPLACE FUNCTION public.bb_v2_dcc_approved_cash_history_staged()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
WITH paid AS (
  SELECT p.invoice_id,
   coalesce(sum(p.amount) FILTER (
      WHERE lower(trim(coalesce(p.payment_method,'')))='cash'
        AND lower(trim(coalesce(p.payment_source,'')))='invoice'),0) AS original_cash_received,
   coalesce(sum(p.amount) FILTER (
      WHERE lower(trim(coalesce(p.payment_source,'')))='invoice'),0) AS original_invoice_payments
  FROM public.payments p
  GROUP BY p.invoice_id
),
history AS (
 SELECT d.close_id,c.status AS approval_status,
        d.invoice_id,i.invoice_no,i.customer_id,i.location_code,
        d.invoice_cash_amount AS approved_cash_close_amount,
        coalesce(p.original_cash_received,0) AS original_cash_received,
        coalesce(p.original_invoice_payments,0) AS original_invoice_payments,
        coalesce(i.reversal_amount,0) AS reversal_amount,
        greatest(coalesce(i.grand_total,0)-coalesce(i.reversal_amount,0),0) AS net_invoice_value,
        -- This is a REVIEW signal, NOT evidence of an owed/paid refund.
        coalesce(i.reversal_amount,0)>0 AS reversal_reconciliation_review,
        'APPROVED_CASH_CLOSE_HISTORY'::text AS record_type
   FROM public.daily_cash_close_invoices d
   JOIN public.daily_cash_closes c ON c.close_id=d.close_id
   JOIN public.invoices i ON i.invoice_id=d.invoice_id
   LEFT JOIN paid p ON p.invoice_id=i.invoice_id
  WHERE lower(trim(coalesce(c.status,'')))='approved'
)
SELECT jsonb_build_object(
 'success',true,
 'history',coalesce(jsonb_agg(to_jsonb(history)
     ORDER BY history.invoice_id,history.close_id),'[]'::jsonb),
 'settlementState','NOT_EVALUATED_NO_REFUND_LEDGER'
)
FROM history;
$function$;

-- Never grant this isolated prototype to app roles.
REVOKE ALL ON FUNCTION public.bb_v2_dcc_approved_cash_history_staged()
 FROM PUBLIC;
