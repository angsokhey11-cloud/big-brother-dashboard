-- BIG BROTHER 16-Nov-2026: many-to-many Stock Swap with exact posted value balance.
-- Keep this SQL for Cloud/Local Brain parity. Uses existing table schema and permissions.
CREATE OR REPLACE FUNCTION public.bb_stock_save_adjustment(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_request_id text := nullif(trim(coalesce(p_payload->>'requestId','')),'');
  v_existing public.stock_movement_requests%rowtype;
  v_activity_date date := coalesce(nullif(p_payload->>'activityDate','')::date,current_date);
  v_location_code text := nullif(trim(coalesce(p_payload->>'locationCode','')),'');
  v_location_name text;
  v_controller_id text := nullif(trim(coalesce(p_payload->>'inventoryControllerStaffId','')),'');
  v_controller_name text;
  v_reference_no text := nullif(trim(coalesce(p_payload->>'referenceNo','')),'');
  v_reason_code text := upper(trim(coalesce(p_payload->>'reasonCode','')));
  v_reason_name text := nullif(trim(coalesce(p_payload->>'reasonName','')),'');
  v_note text := nullif(trim(coalesce(p_payload->>'note','')),'');
  v_items jsonb := coalesce(p_payload->'items','[]'::jsonb);
  v_item jsonb;
  v_product public.products%rowtype;
  v_direction text;
  v_qty numeric;
  v_purchased numeric;
  v_zero numeric;
  v_before numeric;
  v_after numeric;
  v_avg numeric;
  v_transfer_cost numeric := null;
  v_total_out_value numeric := 0;
  v_booked_out_value numeric := 0;
  v_booked_in_value numeric := 0;
  v_line_cost numeric;
  v_line_value numeric;
  v_remaining_in numeric := 0;
  v_out_costs jsonb := '{}'::jsonb;
  v_total_out numeric := 0;
  v_total_in numeric := 0;
  v_movement_id text;
  v_transaction_id text;
  v_revision text;
  v_lines jsonb := '[]'::jsonb;
  v_deltas jsonb := '[]'::jsonb;
  v_response jsonb;
  v_seen text[] := array[]::text[];
  v_value_impact numeric;
begin
  if not public.bb_is_active_user() or not public.bb_stock_keyin_route_access('create') then
    raise exception 'Stock Management create access denied';
  end if;

  if not public.bb_stock_ready_internal() then
    raise exception 'Stock Supabase cutover is not ready yet';
  end if;

  perform pg_advisory_xact_lock(hashtext('BB_STOCK_WRITE'));

  if v_request_id is null then
    v_request_id := 'STKSWAPREQ-'||
      to_char(clock_timestamp() at time zone 'Asia/Phnom_Penh','YYYYMMDDHH24MISSMS')||
      '-'||substr(md5(random()::text),1,6);
  end if;

  select * into v_existing
  from public.stock_movement_requests
  where request_id=v_request_id;

  if found then
    return v_existing.response_payload||
      jsonb_build_object('duplicate',true,'requestId',v_request_id);
  end if;

  if v_location_code is null then
    raise exception 'Warehouse Location is required';
  end if;

  if not exists(
    select 1 from public.locations l
    where l.location_code=v_location_code and coalesce(l.active,true)=true
  ) then
    raise exception 'Warehouse Location % is not active',v_location_code;
  end if;

  if not public.bb_has_location_access(v_location_code) then
    raise exception 'You do not have access to Warehouse Location %',v_location_code;
  end if;

  select l.location_name into v_location_name
  from public.locations l
  where l.location_code=v_location_code;

  if v_controller_id is null then
    raise exception 'Inventory Controller is required';
  end if;

  select s.staff_name into v_controller_name
  from public.staff s
  where s.staff_id=v_controller_id
    and lower(coalesce(s.status,'active'))='active';

  if not found then
    raise exception 'Inventory Controller was not found or is inactive';
  end if;

  if v_reason_code not in ('SKU_SWAP','PHYSICAL_COUNT','DATA_CORRECTION','OTHER') then
    raise exception 'Swap Adjustment Reason is required';
  end if;

  if v_reason_name is null then
    v_reason_name := case v_reason_code
      when 'SKU_SWAP' then 'SKU / Product Correction'
      when 'PHYSICAL_COUNT' then 'Physical Count Reclassification'
      when 'DATA_CORRECTION' then 'Data Entry Correction'
      else 'Other'
    end;
  end if;

  if v_reason_code='OTHER' and v_note is null then
    raise exception 'Note is required when Adjustment Reason is Other';
  end if;

  if jsonb_typeof(v_items)<>'array' or jsonb_array_length(v_items)<2 then
    raise exception 'Stock Swap requires at least one OUT product and one IN product';
  end if;

  -- Validate the complete swap before writing anything.
  for v_item in select value from jsonb_array_elements(v_items)
  loop
    if nullif(trim(coalesce(v_item->>'productCode','')),'') is null then
      raise exception 'Product Code is required';
    end if;

    if trim(v_item->>'productCode')=any(v_seen) then
      raise exception 'Product % was added more than once',v_item->>'productCode';
    end if;
    v_seen:=array_append(v_seen,trim(v_item->>'productCode'));

    select * into v_product
    from public.products
    where product_code=trim(v_item->>'productCode')
      and coalesce(active,true)=true
      and coalesce(track_stock,true)=true
      and upper(coalesce(item_type,'PRODUCT'))='PRODUCT';

    if not found then
      raise exception 'Product % was not found, inactive, or is not stock tracked',v_item->>'productCode';
    end if;

    v_direction:=upper(trim(coalesce(v_item->>'direction','')));
    if v_direction='INCREASE' then v_direction:='IN'; end if;
    if v_direction='DECREASE' then v_direction:='OUT'; end if;
    if v_direction not in ('IN','OUT') then
      raise exception '%: Swap Type must be IN or OUT',v_product.product_name;
    end if;

    v_qty:=coalesce(nullif(v_item->>'qty','')::numeric,0);
    if v_qty<=0 then
      raise exception '%: Swap Qty must be greater than 0',v_product.product_name;
    end if;

    select
      coalesce(sum(
        case
          when upper(coalesce(a.to_bucket,''))='WAREHOUSE_GOOD'
           and coalesce(a.to_location_code,a.location_code)=v_location_code
          then a.qty else 0
        end
        -
        case
          when upper(coalesce(a.from_bucket,''))='WAREHOUSE_GOOD'
           and coalesce(a.from_location_code,a.location_code)=v_location_code
          then a.qty else 0
        end
      ),0),
      coalesce(sum(
        case
          when upper(coalesce(a.to_bucket,''))='WAREHOUSE_ZERO_COST'
           and coalesce(a.to_location_code,a.location_code)=v_location_code
          then a.qty else 0
        end
        -
        case
          when upper(coalesce(a.from_bucket,''))='WAREHOUSE_ZERO_COST'
           and coalesce(a.from_location_code,a.location_code)=v_location_code
          then a.qty else 0
        end
      ),0)
    into v_purchased,v_zero
    from public.stock_activity a
    where a.product_code=v_product.product_code;

    if v_direction='OUT' then
      if v_qty>v_purchased+0.000001 then
        raise exception '%: Swap OUT Qty % exceeds Purchased Warehouse Qty %. Zero-Cost stock cannot be used by Stock Adjustment.',
          v_product.product_name,v_qty,v_purchased;
      end if;

      v_avg:=round(public.bb_stock_average_cost_internal(v_product.product_code),4);
      if v_avg<=0 then
        raise exception '%: Purchased stock has no valid cost. Fix its cost history before using Stock Swap.',v_product.product_name;
      end if;

      -- Preserve the true OUT cost of every SKU; many-to-many is valid when total quantity balances.
      v_out_costs:=v_out_costs||jsonb_build_object(v_product.product_code,v_avg);
      v_total_out_value:=v_total_out_value+(v_qty*v_avg);
      v_booked_out_value:=v_booked_out_value+round(v_qty*v_avg,2);

      v_total_out:=v_total_out+v_qty;
    else
      v_total_in:=v_total_in+v_qty;
    end if;
  end loop;

  if v_total_out<=0 or v_total_in<=0 then
    raise exception 'Stock Swap must contain both OUT and IN quantities';
  end if;

  if abs(v_total_out-v_total_in)>0.0001 then
    raise exception 'Stock Swap is not balanced. Total OUT % must equal Total IN %.',
      v_total_out,v_total_in;
  end if;

  v_transfer_cost:=round(v_total_out_value/v_total_in,4);
  if v_transfer_cost<=0 then
    raise exception 'Stock Swap could not determine a valid Purchased inventory cost';
  end if;
  v_remaining_in:=v_total_in;

  v_movement_id:=public.bb_next_prefixed_id(
    'public.stock_activity'::regclass,'movement_id','STK',6
  );

  for v_item in select value from jsonb_array_elements(v_items)
  loop
    select * into v_product
    from public.products
    where product_code=trim(v_item->>'productCode');

    v_direction:=upper(trim(coalesce(v_item->>'direction','')));
    if v_direction='INCREASE' then v_direction:='IN'; end if;
    if v_direction='DECREASE' then v_direction:='OUT'; end if;
    v_qty:=(v_item->>'qty')::numeric;

    select
      coalesce(sum(
        case
          when upper(coalesce(a.to_bucket,''))='WAREHOUSE_GOOD'
           and coalesce(a.to_location_code,a.location_code)=v_location_code
          then a.qty else 0
        end
        -
        case
          when upper(coalesce(a.from_bucket,''))='WAREHOUSE_GOOD'
           and coalesce(a.from_location_code,a.location_code)=v_location_code
          then a.qty else 0
        end
      ),0)
    into v_purchased
    from public.stock_activity a
    where a.product_code=v_product.product_code;

    v_before:=v_purchased;
    v_after:=case when v_direction='IN' then v_before+v_qty else v_before-v_qty end;
    if v_direction='OUT' then
      -- Each outgoing SKU retains its own validated weighted-average cost.
      v_line_cost:=(v_out_costs->>v_product.product_code)::numeric;
      v_line_value:=-round(v_qty*v_line_cost,2);
    else
      -- All incoming SKUs share the weighted transfer cost; assign any cent
      -- rounding remainder to the final IN line to balance posted ledger values.
      v_line_cost:=v_transfer_cost;
      v_remaining_in:=v_remaining_in-v_qty;
      if abs(v_remaining_in)<=0.0001 then
        v_line_value:=v_booked_out_value-v_booked_in_value;
      else
        v_line_value:=round(v_qty*v_total_out_value/v_total_in,2);
      end if;
      if v_line_value<0 then
        raise exception 'Stock Swap incoming value is invalid after rounding';
      end if;
      v_booked_in_value:=v_booked_in_value+v_line_value;
    end if;
    v_value_impact:=v_line_value;

    v_transaction_id:=public.bb_next_prefixed_id(
      'public.stock_activity'::regclass,'transaction_id','TRX',6
    );

    if v_direction='OUT' then
      insert into public.stock_activity(
        transaction_id,activity_date,activity_type,
        product_code,product_name_snapshot,qty,unit_snapshot,
        location_code,from_location_code,
        inventory_controller_staff_id,inventory_controller_name_snapshot,
        reference_no,note,source_created_at,movement_id,
        flow,movement_type,from_bucket,to_bucket,
        source_entity_type,source_id,source_name,
        unit_cost,line_value,location_name_snapshot,client_request_id
      ) values(
        v_transaction_id,v_activity_date,'Stock Swap Out',
        v_product.product_code,v_product.product_name,v_qty,coalesce(v_product.unit,''),
        v_location_code,v_location_code,
        v_controller_id,v_controller_name,
        v_reference_no,v_note,now(),v_movement_id,
        'OUTFLOW','STOCK_ADJUSTMENT','WAREHOUSE_GOOD','ADJUSTMENT_SWAP',
        'ADJUSTMENT_SWAP',v_reason_code,v_reason_name,
        v_line_cost,v_line_value,
        coalesce(v_location_name,v_location_code),v_request_id
      );
    else
      insert into public.stock_activity(
        transaction_id,activity_date,activity_type,
        product_code,product_name_snapshot,qty,unit_snapshot,
        location_code,to_location_code,
        inventory_controller_staff_id,inventory_controller_name_snapshot,
        reference_no,note,source_created_at,movement_id,
        flow,movement_type,from_bucket,to_bucket,
        source_entity_type,source_id,source_name,
        unit_cost,line_value,location_name_snapshot,client_request_id
      ) values(
        v_transaction_id,v_activity_date,'Stock Swap In',
        v_product.product_code,v_product.product_name,v_qty,coalesce(v_product.unit,''),
        v_location_code,v_location_code,
        v_controller_id,v_controller_name,
        v_reference_no,v_note,now(),v_movement_id,
        'INFLOW','STOCK_ADJUSTMENT','ADJUSTMENT_SWAP','WAREHOUSE_GOOD',
        'ADJUSTMENT_SWAP',v_reason_code,v_reason_name,
        v_line_cost,v_line_value,
        coalesce(v_location_name,v_location_code),v_request_id
      );
    end if;

    v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
      'productCode',v_product.product_code,
      'productName',v_product.product_name,
      'unit',coalesce(v_product.unit,''),
      'direction',v_direction,
      'qty',v_qty,
      'beforeQty',v_before,
      'afterQty',v_after,
      'transferCost',v_line_cost,
      'valueImpact',v_value_impact
    ));

    v_deltas:=v_deltas||jsonb_build_array(jsonb_build_object(
      'productCode',v_product.product_code,
      'productName',v_product.product_name,
      'warehouseDelta',case when v_direction='IN' then v_qty else -v_qty end,
      'warehousePurchasedDelta',case when v_direction='IN' then v_qty else -v_qty end,
      'warehouseZeroCostDelta',0,
      'batchPendingDelta',0,
      'totalGoodDelta',case when v_direction='IN' then v_qty else -v_qty end,
      'damagedDelta',0
    ));
  end loop;

  if abs(v_booked_out_value-v_booked_in_value)>0.000001 then
    raise exception 'Stock Swap ledger value is not balanced';
  end if;
  v_revision:=public.bb_stock_touch_revision_internal();

  v_response:=jsonb_build_object(
    'success',true,
    'version','STOCK-SWAP-ADJUSTMENT-V3',
    'revision',v_revision,
    'requestId',v_request_id,
    'movementId',v_movement_id,
    'movementType','STOCK_ADJUSTMENT',
    'activityDate',v_activity_date::text,
    'locationCode',v_location_code,
    'locationName',coalesce(v_location_name,v_location_code),
    'controllerId',v_controller_id,
    'controllerName',v_controller_name,
    'reasonCode',v_reason_code,
    'reasonName',v_reason_name,
    'totalOutQty',v_total_out,
    'totalInQty',v_total_in,
    'transferCost',v_transfer_cost,
    'totalOutValue',v_booked_out_value,
    'totalInValue',v_booked_in_value,
    'inventoryValueChange',v_booked_in_value-v_booked_out_value,
    'lines',v_lines,
    'deltas',v_deltas,
    'message','Many-to-many Stock Swap saved. Quantity and posted inventory value balance; individual OUT SKU costs preserved. Zero-Cost stock untouched.'
  );

  insert into public.stock_movement_requests(
    request_id,movement_id,response_payload,created_by
  ) values(
    v_request_id,v_movement_id,v_response,auth.uid()
  );

  return v_response;
end;
$function$
;
