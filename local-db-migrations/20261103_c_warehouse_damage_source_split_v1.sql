-- BIG BROTHER | Warehouse Damage Purchased vs Zero-Cost source | 03-Nov-2026
-- NEW source-aware path. Does not modify legacy Staff Allowance or reported Batch Damage.
-- No historical stock/data changes; the same stock activity accounting buckets are preserved.
CREATE OR REPLACE FUNCTION public.bb_stock_save_warehouse_damage_sources_v1(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $bb$
DECLARE
  v_request_id text:=nullif(trim(coalesce(p_payload->>'requestId','')),'');
  v_existing public.stock_movement_requests%rowtype;
  v_date date:=coalesce(nullif(p_payload->>'activityDate','')::date,current_date);
  v_location text:=coalesce(nullif(trim(coalesce(p_payload->>'warehouseLocationCode','')),''),
        nullif(trim(coalesce(p_payload->>'locationCode','')),''),public.bb_stock_default_warehouse_internal());
  v_loc_name text;
  v_controller text:=nullif(trim(coalesce(p_payload->>'inventoryControllerStaffId','')),'');
  v_controller_name text;
  v_reference text:=nullif(trim(coalesce(p_payload->>'referenceNo','')),'');
  v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
  v_items jsonb:=coalesce(p_payload->'items','[]'::jsonb);
  v_item jsonb;
  v_product public.products%rowtype;
  v_code text;
  v_seen text[]:=array[]::text[];
  v_qty numeric;
  v_p numeric;
  v_z numeric;
  v_available_p numeric;
  v_available_z numeric;
  v_cost numeric;
  v_value numeric;
  v_movement text;
  v_transaction text;
  v_revision text;
  v_lines jsonb:='[]'::jsonb;
  v_deltas jsonb:='[]'::jsonb;
  v_response jsonb;
  v_source text;
  v_split_type text;
  v_part_qty numeric;
  v_part_cost numeric;
  v_part_value numeric;
BEGIN
  IF NOT public.bb_is_active_user() OR NOT public.bb_stock_keyin_route_access('create')
    THEN RAISE EXCEPTION 'Stock Management create access denied'; END IF;
  IF NOT public.bb_stock_ready_internal()
    THEN RAISE EXCEPTION 'Stock cutover is not ready'; END IF;
  IF upper(trim(coalesce(p_payload->>'movementType',''))) <> 'STOCK_DAMAGE'
    OR upper(trim(coalesce(p_payload->>'damageSource','WAREHOUSE'))) <> 'WAREHOUSE'
    THEN RAISE EXCEPTION 'Source-aware Warehouse Damage only'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('BB_STOCK_WRITE'));

  IF v_request_id IS NULL THEN
    v_request_id:='STKREQ-'||to_char(clock_timestamp() AT TIME ZONE 'Asia/Phnom_Penh','YYYYMMDDHH24MISSMS')
                      ||'-'||substr(md5(random()::text),1,6);
  END IF;
  SELECT * INTO v_existing FROM public.stock_movement_requests WHERE request_id=v_request_id;
  IF FOUND THEN RETURN v_existing.response_payload||
    jsonb_build_object('duplicate',true,'requestId',v_request_id); END IF;

  IF v_location<>public.bb_stock_default_warehouse_internal()
    THEN RAISE EXCEPTION 'Warehouse Damage must deduct from physical warehouse %, not sales location %',
       public.bb_stock_default_warehouse_internal(),v_location; END IF;
  SELECT location_name INTO v_loc_name FROM public.locations
   WHERE location_code=v_location AND active=true;
  IF NOT FOUND OR NOT public.bb_has_location_access(v_location)
    THEN RAISE EXCEPTION 'Warehouse Location access denied or inactive'; END IF;
  IF v_controller IS NOT NULL THEN
    SELECT staff_name INTO v_controller_name FROM public.staff
      WHERE staff_id=v_controller AND lower(coalesce(status,'active'))='active';
    IF NOT FOUND THEN RAISE EXCEPTION 'Inventory Controller was not found or inactive'; END IF;
  END IF;
  IF jsonb_typeof(v_items)<>'array' OR jsonb_array_length(v_items)=0
    THEN RAISE EXCEPTION 'Add at least one Warehouse Damage product'; END IF;

  -- First validate the complete request; no movement is written until every source is safe.
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    v_code:=nullif(trim(coalesce(v_item->>'productCode','')),'');
    IF v_code IS NULL OR v_code=ANY(v_seen)
      THEN RAISE EXCEPTION 'Warehouse Damage product missing or duplicated: %',v_code; END IF;
    v_seen:=array_append(v_seen,v_code);
    SELECT * INTO v_product FROM public.products WHERE product_code=v_code AND active=true;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product % missing or inactive',v_code; END IF;
    IF NOT (v_item ? 'purchasedQty' AND v_item ? 'zeroCostQty')
      THEN RAISE EXCEPTION 'Explicit Purchased and Zero-Cost quantities are required for Warehouse Damage'; END IF;
    v_p:=coalesce(nullif(v_item->>'purchasedQty','')::numeric,0);
    v_z:=coalesce(nullif(v_item->>'zeroCostQty','')::numeric,0);
    v_qty:=coalesce(nullif(v_item->>'qty','')::numeric,0);
    IF v_p<0 OR v_z<0 OR v_qty<=0 OR abs(v_qty-v_p-v_z)>0.000001
      THEN RAISE EXCEPTION '%: invalid Purchased / Zero-Cost split',v_product.product_name; END IF;
    v_available_p:=greatest(public.bb_stock_warehouse_purchased_qty_internal(v_code),0);
    v_available_z:=greatest(public.bb_stock_warehouse_zero_cost_qty_internal(v_code),0);
    IF v_p>v_available_p+0.000001 OR v_z>v_available_z+0.000001
      THEN RAISE EXCEPTION '%: insufficient exact warehouse source (Purchased % of %, Zero-Cost % of %)',
           v_product.product_name,v_p,v_available_p,v_z,v_available_z; END IF;
    IF v_p>0 AND coalesce(public.bb_stock_average_cost_internal(v_code),0)<=0
      THEN RAISE EXCEPTION '%: Purchased stock cost missing; Warehouse Damage not saved',
         v_product.product_name; END IF;
  END LOOP;

  v_movement:=public.bb_next_prefixed_id('public.stock_activity'::regclass,'movement_id','STK',6);
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    v_code:=trim(v_item->>'productCode');
    SELECT * INTO v_product FROM public.products WHERE product_code=v_code;
    v_p:=coalesce(nullif(v_item->>'purchasedQty','')::numeric,0);
    v_z:=coalesce(nullif(v_item->>'zeroCostQty','')::numeric,0);
    v_qty:=v_p+v_z;
    v_cost:=CASE WHEN v_p>0 THEN public.bb_stock_average_cost_internal(v_code) ELSE 0 END;

    FOR v_split_type IN SELECT unnest(ARRAY['WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST']) LOOP
      v_part_qty:=CASE WHEN v_split_type='WAREHOUSE_GOOD' THEN v_p ELSE v_z END;
      IF v_part_qty<=0 THEN CONTINUE; END IF;
      v_part_cost:=CASE WHEN v_split_type='WAREHOUSE_GOOD' THEN v_cost ELSE 0 END;
      v_part_value:=round(v_part_qty*v_part_cost,2);
      v_transaction:=public.bb_next_prefixed_id('public.stock_activity'::regclass,'transaction_id','TRX',6);
      INSERT INTO public.stock_activity(
        transaction_id,activity_date,activity_type,product_code,product_name_snapshot,
        qty,unit_snapshot,location_code,from_location_code,
        inventory_controller_staff_id,inventory_controller_name_snapshot,
        reference_no,note,source_created_at,movement_id,flow,movement_type,
        from_bucket,to_bucket,damage_source,unit_cost,line_value,
        location_name_snapshot,client_request_id
      ) VALUES (
        v_transaction,v_date,'Damaged Stock',v_code,v_product.product_name,
        v_part_qty,coalesce(v_product.unit,''),v_location,v_location,
        v_controller,v_controller_name,v_reference,v_note,
        now(),v_movement,'OUTFLOW','STOCK_DAMAGE',v_split_type,'DAMAGED','WAREHOUSE',
        v_part_cost,v_part_value,coalesce(v_loc_name,v_location),v_request_id
      );

      v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
        'transactionId',v_transaction,'productCode',v_code,
        'productName',v_product.product_name,'unit',coalesce(v_product.unit,''),
        'qty',v_part_qty,'unitCost',v_part_cost,'lineValue',v_part_value,
        'fromBucket',v_split_type,'toBucket','DAMAGED',
        'stockSource',CASE WHEN v_split_type='WAREHOUSE_GOOD' THEN 'Purchased' ELSE 'Zero Cost' END
      ));
    END LOOP;

    v_deltas:=v_deltas||jsonb_build_array(jsonb_build_object(
      'productCode',v_code,'productName',v_product.product_name,
      'warehouseDelta',-v_qty,'warehousePurchasedDelta',-v_p,
      'warehouseZeroCostDelta',-v_z,'batchPendingDelta',0,
      'batchPurchasedDelta',0,'batchZeroCostDelta',0,
      'totalGoodDelta',-v_qty,'damagedDelta',v_qty
    ));
  END LOOP;

  v_revision:=public.bb_stock_touch_revision_internal();
  v_response:=jsonb_build_object(
    'success',true,'version','WAREHOUSE-DAMAGE-SOURCE-V1',
    'revision',v_revision,'requestId',v_request_id,'movementId',v_movement,
    'batchId','','flow','OUTFLOW','movementType','STOCK_DAMAGE',
    'damageSource','WAREHOUSE','activityDate',v_date::text,
    'locationCode',v_location,'locationName',coalesce(v_loc_name,v_location),
    'lines',v_lines,'deltas',v_deltas,
    'message','Warehouse Damage saved with exact Purchased / Zero-Cost source.'
  );
  INSERT INTO public.stock_movement_requests(request_id,movement_id,response_payload,created_by)
  VALUES(v_request_id,v_movement,v_response,auth.uid());
  RETURN v_response;
END;
$bb$;

DO $route_damage_source$
DECLARE v_definition text; v_original text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT v_definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_save_movement';
 v_original:='  if v_type=''STOCK_DAMAGE'' and v_damage=''WAREHOUSE'' then return public.bb_stock_save_warehouse_out_internal(p_payload,''STOCK_DAMAGE''); end if;';
 IF position('bb_stock_save_warehouse_damage_sources_v1' IN v_definition)>0 THEN
   RAISE NOTICE 'Warehouse Damage source routing already installed';
   RETURN;
 END IF;
 IF position(v_original IN v_definition)=0
   THEN RAISE EXCEPTION 'Stock save dispatcher changed: abort source-aware patch'; END IF;
 v_definition:=replace(v_definition,v_original,
   '  if v_type=''STOCK_DAMAGE'' and v_damage=''WAREHOUSE'' then'||E'\n'||
   '    if exists (select 1 from jsonb_array_elements(coalesce(p_payload->''items'',''[]''::jsonb)) x where x ? ''purchasedQty'' or x ? ''zeroCostQty'') then'||E'\n'||
   '      return public.bb_stock_save_warehouse_damage_sources_v1(p_payload);'||E'\n'||
   '    end if;'||E'\n'||
   '    return public.bb_stock_save_warehouse_out_internal(p_payload,''STOCK_DAMAGE'');'||E'\n'||
   '  end if;');
 EXECUTE v_definition;
END
$route_damage_source$;

DO $verify_source_damage$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
               WHERE n.nspname='public' AND p.proname='bb_stock_save_warehouse_damage_sources_v1')
 THEN RAISE EXCEPTION 'Warehouse Damage source save function missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
               WHERE n.nspname='public' AND p.proname='bb_stock_save_movement'
               AND position('bb_stock_save_warehouse_damage_sources_v1' IN pg_get_functiondef(p.oid))>0)
 THEN RAISE EXCEPTION 'Warehouse Damage source dispatcher missing'; END IF;
END
$verify_source_damage$;
