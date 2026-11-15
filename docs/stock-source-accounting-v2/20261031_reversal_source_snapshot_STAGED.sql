-- BIG BROTHER Batch Reversal Source Snapshot V2 — STAGED / NO LIVE DEPLOYMENT
-- Read-only original sale/return lineage, per invoice line AND physical product.
-- This function NEVER chooses a source on the user's behalf.
CREATE OR REPLACE FUNCTION public.bb_invoice_reversal_batch_source_snapshot_v2(p_invoice_id text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
 v_invoice public.invoices%rowtype;
 v_lines jsonb;
BEGIN
 IF NOT public.bb_is_active_user() OR NOT
   (public.bb_has_module_access('invoice_reversal','view')
    OR public.bb_has_module_access('invoice_reversal','create')) THEN
   RAISE EXCEPTION 'Invoice Reversal access denied';
 END IF;
 SELECT * INTO v_invoice FROM public.invoices WHERE invoice_id=trim(coalesce(p_invoice_id,''));
 IF NOT FOUND THEN RAISE EXCEPTION 'Invoice does not exist'; END IF;
 IF NOT public.bb_has_location_access(v_invoice.location_code) THEN
   RAISE EXCEPTION 'Invoice location access denied';
 END IF;
 IF v_invoice.batch_id IS NULL THEN
   RETURN jsonb_build_object('success',true,'invoiceId',v_invoice.invoice_id,'isBatch',false,'sources','[]'::jsonb);
 END IF;

 WITH sold AS (
  SELECT il.line_id,sa.product_code,
   COALESCE(SUM(sa.qty) FILTER(WHERE sa.from_bucket='BATCH_PENDING'),0)::numeric sold_p,
   COALESCE(SUM(sa.qty) FILTER(WHERE sa.from_bucket='BATCH_ZERO_COST'),0)::numeric sold_z,
   COALESCE(SUM(sa.line_value) FILTER(WHERE sa.from_bucket='BATCH_PENDING'),0)::numeric sold_p_value
  FROM public.invoice_lines il
  JOIN public.stock_activity sa ON
    sa.batch_id=v_invoice.batch_id AND sa.product_code IS NOT NULL
    AND sa.movement_type='BATCH_SALE'
    AND sa.related_invoice_no=v_invoice.invoice_no
    AND sa.customer_id IS NOT DISTINCT FROM v_invoice.customer_id
    AND split_part(sa.client_request_id,':',1)='BATCH-INVOICE'
    AND split_part(sa.client_request_id,':',2)=il.line_id
  WHERE il.invoice_id=v_invoice.invoice_id
  GROUP BY il.line_id,sa.product_code
 ),returned AS (
  SELECT sr.line_id,sa.product_code,
   COALESCE(SUM(sa.qty) FILTER(WHERE sa.to_bucket IN ('BATCH_PENDING','WAREHOUSE_GOOD')),0)::numeric returned_p,
   COALESCE(SUM(sa.qty) FILTER(WHERE sa.to_bucket IN ('BATCH_ZERO_COST','WAREHOUSE_ZERO_COST')),0)::numeric returned_z
  FROM public.sales_returns sr
  JOIN public.stock_activity sa ON sa.reference_no=sr.return_id
    AND sa.product_code IS NOT NULL
    AND sa.from_bucket='EXTERNAL'
    AND sa.movement_type IN ('BATCH_SALE_RETURN','POSTCLOSE_SALE_RETURN')
  WHERE sr.invoice_id=v_invoice.invoice_id
  GROUP BY sr.line_id,sa.product_code
 )
 SELECT COALESCE(jsonb_agg(jsonb_build_object(
   'lineId',s.line_id,
   'productCode',s.product_code,
   'originalPurchasedQty',s.sold_p,
   'originalZeroCostQty',s.sold_z,
   'returnedPurchasedQty',COALESCE(r.returned_p,0),
   'returnedZeroCostQty',COALESCE(r.returned_z,0),
   'remainingPurchasedQty',greatest(s.sold_p-COALESCE(r.returned_p,0),0),
   'remainingZeroCostQty',greatest(s.sold_z-COALESCE(r.returned_z,0),0),
   'originalPurchasedValue',s.sold_p_value,
   'originalPurchasedUnitCost',CASE WHEN s.sold_p>0 THEN s.sold_p_value/s.sold_p ELSE 0 END,
   'sourceMismatch',COALESCE(r.returned_p,0)>s.sold_p+0.000001 OR COALESCE(r.returned_z,0)>s.sold_z+0.000001
 ) ORDER BY s.line_id,s.product_code),'[]'::jsonb)
 INTO v_lines
 FROM sold s LEFT JOIN returned r
 ON r.line_id=s.line_id AND r.product_code=s.product_code;

 RETURN jsonb_build_object(
  'success',true,'version','BATCH-REVERSAL-SOURCE-V2',
  'invoiceId',v_invoice.invoice_id,'isBatch',true,'batchId',v_invoice.batch_id,
  'sources',v_lines
 );
END;
$function$;
REVOKE ALL ON FUNCTION public.bb_invoice_reversal_batch_source_snapshot_v2(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_invoice_reversal_batch_source_snapshot_v2(text) TO authenticated;
