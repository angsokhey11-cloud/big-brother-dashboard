-- BIG BROTHER | Exact sourced Damaged Stock Clearance | 03-Nov-2026
-- New transactions only, separate Purchased and Zero-Cost original damage.
CREATE OR REPLACE FUNCTION public.bb_stock_damaged_source_available_v1(p_code text,p_source text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $f$
SELECT coalesce(sum(greatest(d.qty-coalesce(a.used_qty,0),0)),0)
FROM public.stock_activity d LEFT JOIN (
  SELECT damage_transaction_id,sum(allocated_qty) used_qty
  FROM public.stock_damage_clear_allocations GROUP BY damage_transaction_id
) a ON a.damage_transaction_id=d.transaction_id
WHERE d.product_code=p_code AND d.movement_type='STOCK_DAMAGE' AND d.to_bucket='DAMAGED'
AND CASE WHEN upper(p_source)='ZERO_COST'
THEN (d.from_bucket IN ('WAREHOUSE_ZERO_COST','BATCH_ZERO_COST')
  OR (d.from_bucket='BATCH_PENDING' AND d.unit_cost=0))
WHEN upper(p_source)='PURCHASED'
THEN NOT (d.from_bucket IN ('WAREHOUSE_ZERO_COST','BATCH_ZERO_COST')
  OR (d.from_bucket='BATCH_PENDING' AND d.unit_cost=0))
ELSE false END;
$f$;

CREATE OR REPLACE FUNCTION public.bb_stock_damage_clear_source_balances_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $f$
BEGIN
 IF NOT public.bb_is_active_user() OR NOT public.bb_stock_keyin_route_access('view')
 THEN RAISE EXCEPTION 'Stock Management view access denied'; END IF;
 IF NOT public.bb_stock_ready_internal() THEN RAISE EXCEPTION 'Stock cutover not ready'; END IF;
 RETURN jsonb_build_object('rows',coalesce((
 SELECT jsonb_agg(jsonb_build_object(
 'productCode',r.product_code,'totalDamaged',r.damaged,
 'purchasedAvailable',public.bb_stock_damaged_source_available_v1(r.product_code,'PURCHASED'),
 'zeroCostAvailable',public.bb_stock_damaged_source_available_v1(r.product_code,'ZERO_COST')
 ) ORDER BY r.product_code)
 FROM public.bb_stock_product_rows_zero_cost_v1_internal() r WHERE r.damaged>0.000001
 ),'[]'::jsonb));
END;$f$;

DO $clone$
DECLARE d text; v text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_clear_damaged';
 IF position('v_qty numeric;' IN d)=0 OR position('v_qty:=nullif(v_item->>''qty'','''')::numeric;' IN d)=0
 THEN RAISE EXCEPTION 'Damage clearance base changed'; END IF;
 v:=replace(d,'public.bb_stock_clear_damaged(p_payload jsonb)','public.bb_stock_clear_damaged_sources_v1(p_payload jsonb)');
 v:=replace(v,'  v_qty numeric;','  v_qty numeric;'||E'\n  v_p_qty numeric;\n  v_z_qty numeric;\n  v_source text;');
 v:=replace(v,'    select coalesce(b.damaged,0) into v_available',
  '    IF NOT (v_item ? ''purchasedQty'' AND v_item ? ''zeroCostQty'') THEN'||E'\n'||
  '      RAISE EXCEPTION ''Purchased and Zero-Cost damage quantities are required'';'||E'\n'||
  '    END IF;'||E'\n'||
  '    v_p_qty:=coalesce(nullif(v_item->>''purchasedQty'','''')::numeric,0);'||E'\n'||
  '    v_z_qty:=coalesce(nullif(v_item->>''zeroCostQty'','''')::numeric,0);'||E'\n'||
  '    IF v_p_qty<0 OR v_z_qty<0 OR abs(v_qty-v_p_qty-v_z_qty)>0.000001 THEN'||E'\n'||
  '      RAISE EXCEPTION ''Purchased plus Zero-Cost damage must equal the requested quantity'';'||E'\n'||
  '    END IF;'||E'\n'||
  '    IF v_p_qty>public.bb_stock_damaged_source_available_v1(v_product.product_code,''PURCHASED'')+0.000001'||E'\n'||
  '      OR v_z_qty>public.bb_stock_damaged_source_available_v1(v_product.product_code,''ZERO_COST'')+0.000001 THEN'||E'\n'||
  '      RAISE EXCEPTION ''Insufficient damaged stock by source: %'',v_product.product_name;'||E'\n'||
  '    END IF;'||E'\n'||
  '    select coalesce(b.damaged,0) into v_available');
 v:=replace(v,'    v_qty:=nullif(v_item->>''qty'','''')::numeric;'||E'\n'||
    '    v_cost:=coalesce(public.bb_stock_average_cost_internal(v_product.product_code),0);',
    '    v_p_qty:=coalesce(nullif(v_item->>''purchasedQty'','''')::numeric,0);'||E'\n'||
    '    v_z_qty:=coalesce(nullif(v_item->>''zeroCostQty'','''')::numeric,0);'||E'\n'||
    '    FOR v_source IN SELECT unnest(ARRAY[''PURCHASED'',''ZERO_COST'']) LOOP'||E'\n'||
    '    v_qty:=CASE WHEN v_source=''PURCHASED'' THEN v_p_qty ELSE v_z_qty END;'||E'\n'||
    '    IF v_qty<=0 THEN CONTINUE; END IF;'||E'\n'||
    '    v_cost:=CASE WHEN v_source=''ZERO_COST'' THEN 0'||E'\n'||
    '     ELSE coalesce(public.bb_stock_average_cost_internal(v_product.product_code),0) END;');
 v:=replace(v,'''DAMAGED_STOCK'',v_product.product_code,v_product.product_name',
   '''BB_DAMAGE_CLEAR_SOURCE'',v_source,v_product.product_name');
 v:=replace(v,'''unitCost'',round(v_cost,6),','''damagedSource'',v_source,'||E'\n      '||'''unitCost'',round(v_cost,6),');
 v:=replace(v,'  end loop;'||E'\n\n  v_revision:=',
    '    END LOOP; /* BB_DAMAGE_CLEAR_SEPARATE_SOURCE_V1 */'||E'\n  end loop;\n\n  v_revision:=');
 IF position('BB_DAMAGE_CLEAR_SEPARATE_SOURCE_V1' IN v)=0
   OR position('BB_DAMAGE_CLEAR_SOURCE' IN v)=0 THEN
   RAISE EXCEPTION 'Failed to clone source-specific clearance';
 END IF;
 EXECUTE v;
END;$clone$;

DO $fifo$
DECLARE d text;v text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_allocate_damage_clearance_internal';
 IF position('BB_DAMAGE_CLEAR_SOURCE_FIFO_V1' IN d)>0 THEN RETURN; END IF;
 v:=regexp_replace(d,
  'd[.]product_code[[:space:]]*=[[:space:]]*v_clear[.]product_code',
  'd.product_code=v_clear.product_code /* BB_DAMAGE_CLEAR_SOURCE_FIFO_V1 */'||E'\n'||
  '  AND (coalesce(v_clear.source_entity_type,'''')<>''BB_DAMAGE_CLEAR_SOURCE'''||E'\n'||
  '    OR (v_clear.source_id=''ZERO_COST'' AND (d.from_bucket IN (''WAREHOUSE_ZERO_COST'',''BATCH_ZERO_COST'')'||E'\n'||
  '         OR (d.from_bucket=''BATCH_PENDING'' AND d.unit_cost=0)))'||E'\n'||
  '    OR (v_clear.source_id=''PURCHASED'' AND NOT (d.from_bucket IN (''WAREHOUSE_ZERO_COST'',''BATCH_ZERO_COST'')'||E'\n'||
  '         OR (d.from_bucket=''BATCH_PENDING'' AND d.unit_cost=0))))');
 IF position('BB_DAMAGE_CLEAR_SOURCE_FIFO_V1' IN v)=0 THEN
  RAISE EXCEPTION 'Damage FIFO source filter not found';
 END IF;
 EXECUTE v;
END;$fifo$;

DO $v2$
DECLARE d text;v text;anchor text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_clear_damaged_v2';
 IF position('BB_DAMAGE_CLEAR_SOURCE_ROUTING_V1' IN d)>0 THEN RETURN; END IF;
 v:=regexp_replace(d,
  'v_result[[:space:]]*:=[[:space:]]*public[.]bb_stock_clear_damaged[(][[:space:]]*p_payload[[:space:]]*[)];',
  '/* BB_DAMAGE_CLEAR_SOURCE_ROUTING_V1 */'||E'\n'||
  'IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_payload->''items'',''[]''::jsonb)) x'||E'\n'||
  '  WHERE x ? ''purchasedQty'' OR x ? ''zeroCostQty'') THEN'||E'\n'||
  '  v_result:=public.bb_stock_clear_damaged_sources_v1(p_payload);'||E'\n'||
  'ELSE'||E'\n'||
  '  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_payload->''items'',''[]''::jsonb)) x'||E'\n'||
  '     WHERE public.bb_stock_damaged_source_available_v1(x->>''productCode'',''ZERO_COST'')>0) THEN'||E'\n'||
  '    RAISE EXCEPTION ''Damaged stock includes Zero-Cost: select exact source before clearing'';'||E'\n'||
  '  END IF;'||E'\n'||
  '  v_result:=public.bb_stock_clear_damaged(p_payload);'||E'\n'||
  'END IF;');
 IF position('BB_DAMAGE_CLEAR_SOURCE_ROUTING_V1' IN v)=0 THEN
  RAISE EXCEPTION 'Damage Clearance entry point changed';
 END IF;
 v:=replace(v,'IF v_movement_id IS NOT NULL AND EXISTS (',
  'IF v_movement_id IS NOT NULL AND (EXISTS (');
 anchor:='  ) THEN'||E'\n'||'    WITH documented_cost';
 IF position(anchor IN v)=0 THEN
  RAISE EXCEPTION 'Damage Clearance existing valuation anchor changed';
 END IF;
 v:=replace(v,anchor,
  '  ) OR EXISTS(SELECT 1 FROM public.stock_activity c WHERE c.movement_id=v_movement_id'||E'\n'||
  '    AND c.source_entity_type=''BB_DAMAGE_CLEAR_SOURCE'')) THEN'||E'\n'||
  '    IF EXISTS (SELECT 1 FROM public.stock_damage_clear_allocations a'||E'\n'||
  '    JOIN public.stock_activity c ON c.transaction_id=a.clear_transaction_id'||E'\n'||
  '    JOIN public.stock_activity d ON d.transaction_id=a.damage_transaction_id'||E'\n'||
  '    WHERE a.clear_movement_id=v_movement_id'||E'\n'||
  '      AND c.source_entity_type=''BB_DAMAGE_CLEAR_SOURCE'' AND c.source_id=''PURCHASED'''||E'\n'||
  '      AND coalesce(d.unit_cost,0)<=0) THEN'||E'\n'||
  '      RAISE EXCEPTION ''Purchased damaged stock has no documented unit cost'';'||E'\n'||
  '    END IF;'||E'\n'||
  '    WITH documented_cost');
 EXECUTE v;
END;$v2$;

DO $verify$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_clear_damaged_sources_v1')
 OR NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_clear_damaged_v2'
 AND position('BB_DAMAGE_CLEAR_SOURCE_ROUTING_V1' IN pg_get_functiondef(p.oid))>0)
 THEN RAISE EXCEPTION 'Sourced Damage Clearance patch incomplete'; END IF;
END;$verify$;
