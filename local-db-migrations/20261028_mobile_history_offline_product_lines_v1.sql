-- BIG BROTHER Mobile Invoice History: one authorized read-only sync of ALL
-- original invoice product lines in the current user's permitted locations.
-- This is an RPC-only migration. No invoice/stock/payment rows are modified.
-- Cloud and Local Brain V5/V6 can apply the same function by Code Sync.
--
-- Access deliberately matches bb_invoice_history_mobile_list:
--   private.bb_invoice_history_mobile_has_access()
--   private.bb_invoice_history_mobile_location_allowed(location_code)
-- Never grant it to anon or PUBLIC.

CREATE OR REPLACE FUNCTION public.bb_invoice_history_mobile_offline_lines_v1()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $bb$
DECLARE
  v_items jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT private.bb_invoice_history_mobile_has_access() THEN
    RAISE EXCEPTION 'Mobile Invoice History access denied';
  END IF;

  SELECT coalesce(
    jsonb_object_agg(i.invoice_id, coalesce(lines.items,'[]'::jsonb)),
    '{}'::jsonb
  )
  INTO v_items
  FROM public.invoices i
  LEFT JOIN public.customers c ON c.customer_id=i.customer_id
  LEFT JOIN LATERAL (
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'lineId', il.line_id,
          'lineNo', il.line_no,
          'entryType', coalesce(il.entry_type,''),
          'productCode', coalesce(il.display_product_code,il.product_code,il.product_group_code,''),
          'exactProductCode', coalesce(il.product_code,''),
          'productGroupCode', coalesce(il.product_group_code,''),
          'productName', coalesce(il.product_name_snapshot,''),
          'productBarcode', coalesce(il.product_barcode_snapshot,''),
          'productNote', coalesce(il.product_note,''),
          'qty', coalesce(il.qty,0),
          'unit', coalesce(il.unit_snapshot,''),
          'price', coalesce(il.unit_price,0),
          'unitPrice', coalesce(il.unit_price,0),
          'total', coalesce(il.line_total,0),
          'amount', coalesce(il.line_total,0)
        ) ORDER BY il.line_no,il.line_id
      ),'[]'::jsonb
    ) AS items
    FROM public.invoice_lines il
    WHERE il.invoice_id=i.invoice_id
  ) lines ON true
  WHERE private.bb_invoice_history_mobile_location_allowed(
    coalesce(i.location_code,c.location_code,'')
  );

  RETURN jsonb_build_object(
    'success', true,
    'revision', public.bb_invoice_history_mobile_revision(),
    'itemsByInvoiceId', v_items
  );
END;
$bb$;

REVOKE ALL ON FUNCTION public.bb_invoice_history_mobile_offline_lines_v1()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bb_invoice_history_mobile_offline_lines_v1()
  TO authenticated;
