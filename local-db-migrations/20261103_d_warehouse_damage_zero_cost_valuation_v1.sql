-- BIG BROTHER | Warehouse Damage Zero-Cost Valuation Guard | 03-Nov-2026
-- Makes damage reporting and later Damage Clearance respect source-cost provenance.
-- Never changes existing transactions, warehouse qty, batch qty or any purchased cost.
CREATE OR REPLACE FUNCTION public.bb_stock_damaged_zero_remaining_qty_internal(p_product_code text)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO ''
AS $bb$
  SELECT coalesce(sum(greatest(d.qty-coalesce(a.allocated_qty,0),0)),0)
  FROM public.stock_activity d
  LEFT JOIN (
    SELECT damage_transaction_id,sum(allocated_qty) allocated_qty
    FROM public.stock_damage_clear_allocations
    GROUP BY damage_transaction_id
  ) a ON a.damage_transaction_id=d.transaction_id
  WHERE d.product_code=p_product_code
    AND upper(coalesce(d.movement_type,''))='STOCK_DAMAGE'
    AND upper(coalesce(d.to_bucket,''))='DAMAGED'
    AND upper(coalesce(d.from_bucket,'')) IN ('WAREHOUSE_ZERO_COST','BATCH_ZERO_COST');
$bb$;

DO $update_damage_report$
DECLARE
  v_def text;
  v_new text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT v_def
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_damage_report';
 IF position('bb_stock_damaged_zero_remaining_qty_internal' IN v_def)>0 THEN
   RAISE NOTICE 'Zero-Cost damaged valuation is already installed';
   RETURN;
 END IF;
 v_new:=regexp_replace(v_def,
   'r[.]damaged[[:space:]]*[*][[:space:]]*r[.]average_cost',
   'greatest(r.damaged-public.bb_stock_damaged_zero_remaining_qty_internal(r.product_code),0)*r.average_cost',
   'g');
 v_new:=regexp_replace(v_new,
   'x[.]damaged[[:space:]]*[*][[:space:]]*x[.]average_cost',
   'greatest(x.damaged-public.bb_stock_damaged_zero_remaining_qty_internal(x.product_code),0)*x.average_cost',
   'g');
 IF v_new=v_def OR position('greatest(r.damaged-public.bb_stock_damaged_zero_remaining_qty_internal' IN v_new)=0
     OR position('greatest(x.damaged-public.bb_stock_damaged_zero_remaining_qty_internal' IN v_new)=0
 THEN
   RAISE EXCEPTION 'Damage report valuation source changed: abort';
 END IF;
 EXECUTE v_new;
 RAISE NOTICE 'Damage report excludes zero-cost remaining damaged quantities from inventory value';
END
$update_damage_report$;

DO $update_damage_clearance$
DECLARE
  v_def text;
  v_updated text;
  v_anchor text;
  v_replacement text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT v_def
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_clear_damaged_v2';
 IF position('BB_DAMAGE_CLEAR_SOURCE_COST_20261103' IN v_def)>0 THEN
   RAISE NOTICE 'Damage Clearance source-cost calculation already installed';
   RETURN;
 END IF;
 v_anchor:=E'  /* =======================================================\r\n     EXCHANGE FOR GOOD PRODUCTS\r\n     CREATE EXCHANGE PENDING';
 IF position(v_anchor IN v_def)=0 THEN
   v_anchor:=E'  /* =======================================================\n     EXCHANGE FOR GOOD PRODUCTS\n     CREATE EXCHANGE PENDING';
 END IF;
 IF position(v_anchor IN v_def)=0 THEN
   RAISE EXCEPTION 'Damage Clearance v2 post-allocation anchor changed: abort';
 END IF;
 v_replacement:= $block$
  /* BB_DAMAGE_CLEAR_SOURCE_COST_20261103
     Zero-Cost origin stays $0 when damaged goods are later cleared.
     Purchased origin preserves documented damage unit cost.
     Only clearances containing an explicitly Zero-Cost damaged source
     take this path; all legacy purchased-only clearances are unchanged. */
  IF v_movement_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.stock_damage_clear_allocations al
    JOIN public.stock_activity damage ON damage.transaction_id=al.damage_transaction_id
    WHERE al.clear_movement_id=v_movement_id
      AND upper(coalesce(damage.from_bucket,'')) IN ('WAREHOUSE_ZERO_COST','BATCH_ZERO_COST')
  ) THEN
    WITH documented_cost AS (
      SELECT al.clear_transaction_id,
             sum(al.allocated_qty) as source_qty,
             sum(al.allocated_qty *
               CASE WHEN upper(coalesce(damage.from_bucket,'')) IN
                    ('WAREHOUSE_ZERO_COST','BATCH_ZERO_COST')
                    THEN 0
                    ELSE coalesce(damage.unit_cost,public.bb_stock_average_cost_internal(damage.product_code),0)
               END) as source_value
      FROM public.stock_damage_clear_allocations al
      JOIN public.stock_activity damage ON damage.transaction_id=al.damage_transaction_id
      WHERE al.clear_movement_id=v_movement_id
      GROUP BY al.clear_transaction_id
    )
    UPDATE public.stock_activity cleared
    SET unit_cost=round(documented_cost.source_value/nullif(documented_cost.source_qty,0),6),
        line_value=round(documented_cost.source_value,2),
        updated_at=now()
    FROM documented_cost
    WHERE cleared.transaction_id=documented_cost.clear_transaction_id
      AND abs(cleared.qty-documented_cost.source_qty)<=0.000001;

    v_result:=jsonb_set(v_result,'{totalValue}',
      to_jsonb(coalesce((SELECT round(sum(line_value),2) FROM public.stock_activity
                         WHERE movement_id=v_movement_id AND movement_type='DAMAGE_CLEAR'),0)));

    v_result:=jsonb_set(v_result,'{lines}',
      coalesce((SELECT jsonb_agg(item.row_json ||
        jsonb_build_object('unitCost',round(c.unit_cost,6),
                           'lineValue',round(c.line_value,2)) ORDER BY item.ordinal)
        FROM jsonb_array_elements(v_result->'lines') WITH ORDINALITY AS item(row_json,ordinal)
        JOIN public.stock_activity c ON c.transaction_id=item.row_json->>'transactionId'), '[]'::jsonb));

    UPDATE public.stock_movement_requests
    SET response_payload=coalesce(response_payload,'{}'::jsonb) ||
      jsonb_build_object('totalValue',v_result->'totalValue','lines',v_result->'lines')
    WHERE movement_id=v_movement_id;
  END IF;

$block$;
 v_updated:=replace(v_def,v_anchor,v_replacement||v_anchor);
 EXECUTE v_updated;
 RAISE NOTICE 'Damage Clearance now preserves Zero-Cost provenance before exchange and recovery processing';
END
$update_damage_clearance$;

DO $validate_damage_source_value$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='bb_stock_damaged_zero_remaining_qty_internal')
 OR NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='bb_stock_clear_damaged_v2'
   AND position('BB_DAMAGE_CLEAR_SOURCE_COST_20261103' IN pg_get_functiondef(p.oid))>0)
 THEN RAISE EXCEPTION 'Source-aware damage value/clearance guards missing'; END IF;
END
$validate_damage_source_value$;
