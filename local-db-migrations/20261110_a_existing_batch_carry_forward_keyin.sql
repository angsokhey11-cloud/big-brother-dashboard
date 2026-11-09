-- BIG BROTHER | Existing Open Batch -> Existing Open Batch stock rollover
-- Atomic, idempotent, preserving Purchased/Zero-Cost split; no warehouse movement.
-- Requires Stock Management create AND edit permissions and access to both locations.
CREATE OR REPLACE FUNCTION public.bb_stock_transfer_between_open_batches(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_source_id text := trim(coalesce(p_payload->>'sourceBatchId',''));
  v_target_id text := trim(coalesce(p_payload->>'targetBatchId',''));
  v_request_id text := trim(coalesce(p_payload->>'requestId',''));
  v_source public.stock_batches%rowtype;
  v_target public.stock_batches%rowtype;
  v_existing public.stock_movement_requests%rowtype;
  v_activity_date date := coalesce(nullif(p_payload->>'activityDate','')::date, (now() at time zone 'Asia/Phnom_Penh')::date);
  v_transfer_all boolean := coalesce((p_payload->>'transferAll')::boolean, false);
  v_items jsonb := coalesce(p_payload->'items','[]'::jsonb);
  v_item jsonb;
  v_product public.products%rowtype;
  v_source_item public.stock_batch_items%rowtype;
  v_code text;
  v_qty numeric;
  v_purchased numeric;
  v_zero numeric;
  v_total numeric := 0;
  v_cost numeric;
  v_seen text[] := array[]::text[];
  v_movement_id text;
  v_transaction_id text;
  v_revision text;
  v_source_remaining numeric;
  v_target_remaining numeric;
  v_lines jsonb := '[]'::jsonb;
  v_response jsonb;
  v_controller_id text := public.bb_actor_staff_id();
  v_controller_name text := public.bb_actor_name();
  v_bucket text;
  v_bucket_qty numeric;
BEGIN
  IF NOT public.bb_is_active_user()
     OR NOT public.bb_stock_keyin_route_access('create')
     OR NOT public.bb_has_module_access('Stock Management','edit') THEN
    RAISE EXCEPTION 'Batch to Batch transfer requires Stock Management create and edit access';
  END IF;
  IF NOT public.bb_stock_ready_internal() THEN
    RAISE EXCEPTION 'Stock Supabase cutover is not ready';
  END IF;
  IF v_request_id='' OR length(v_request_id)>160 THEN
    RAISE EXCEPTION 'A unique transfer Request ID is required';
  END IF;
  IF v_source_id='' OR v_target_id='' OR v_source_id=v_target_id THEN
    RAISE EXCEPTION 'Choose two different open batches: Source and Destination';
  END IF;

  -- Match every live stock movement writer to prevent competing updates.
  PERFORM pg_advisory_xact_lock(hashtext('BB_STOCK_WRITE'));
  SELECT * INTO v_existing FROM public.stock_movement_requests WHERE request_id=v_request_id;
  IF found THEN
    RETURN v_existing.response_payload || jsonb_build_object('duplicate',true,'requestId',v_request_id);
  END IF;

  -- A fixed order avoids deadlocks when a parallel transfer uses reversed batches.
  PERFORM 1 FROM public.stock_batches b WHERE b.batch_id IN (v_source_id,v_target_id)
    ORDER BY b.batch_id FOR UPDATE;
  SELECT * INTO v_source FROM public.stock_batches WHERE batch_id=v_source_id;
  SELECT * INTO v_target FROM public.stock_batches WHERE batch_id=v_target_id;
  IF v_source.batch_id IS NULL OR v_target.batch_id IS NULL THEN
    RAISE EXCEPTION 'Source or Destination Batch no longer exists';
  END IF;
  IF upper(coalesce(v_source.status,''))<>'OPEN' THEN
    RAISE EXCEPTION 'Source Batch % is %; only Open batches can transfer',v_source_id,v_source.status;
  END IF;
  IF upper(coalesce(v_target.status,''))<>'OPEN' THEN
    RAISE EXCEPTION 'Destination Batch % is %; only Open batches can receive',v_target_id,v_target.status;
  END IF;
  IF NOT public.bb_has_location_access(v_source.location_code)
     OR NOT public.bb_has_location_access(v_target.location_code) THEN
    RAISE EXCEPTION 'Access to both batch locations is required';
  END IF;

  IF v_transfer_all THEN
    -- Never trust a browser's cached quantities for Full Carry Forward.
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'productCode',i.product_code,
        'qty',i.pending_qty_snapshot
      ) ORDER BY i.product_code),'[]'::jsonb)
      INTO v_items
      FROM public.stock_batch_items i
      WHERE i.batch_id=v_source_id AND i.pending_qty_snapshot>0.000001;
  END IF;
  IF jsonb_typeof(v_items)<>'array' OR jsonb_array_length(v_items)=0 THEN
    RAISE EXCEPTION 'No remaining source products selected for transfer';
  END IF;

  v_movement_id:=public.bb_next_prefixed_id(
    'public.stock_activity'::regclass,'movement_id','STK',6
  );

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    v_code:=trim(coalesce(v_item->>'productCode',''));
    IF v_code='' OR v_code=any(v_seen) THEN
      RAISE EXCEPTION 'Missing or repeated product in Batch Transfer: %',v_code;
    END IF;
    v_seen:=array_append(v_seen,v_code);
    SELECT * INTO v_product FROM public.products
      WHERE product_code=v_code AND coalesce(active,true)=true
        AND coalesce(track_stock,true)=true AND upper(coalesce(item_type,'PRODUCT'))='PRODUCT';
    IF NOT found THEN RAISE EXCEPTION 'Stock Product % was not found or inactive',v_code; END IF;
    SELECT * INTO v_source_item FROM public.stock_batch_items
      WHERE batch_id=v_source_id AND product_code=v_code FOR UPDATE;
    IF NOT found THEN RAISE EXCEPTION '% is not in Source Batch %',v_code,v_source_id; END IF;
    IF abs(v_source_item.pending_qty_snapshot-
      (v_source_item.purchased_pending_qty_snapshot+v_source_item.zero_cost_pending_qty_snapshot))>0.000001
      OR abs(v_source_item.pending_qty_snapshot-
       (v_source_item.issued_qty-v_source_item.sold_qty_snapshot-v_source_item.back_sale_qty-
        v_source_item.damaged_qty-v_source_item.other_out_qty))>0.000001 THEN
       RAISE EXCEPTION 'Source Batch % product % has a stock integrity mismatch',v_source_id,v_code;
    END IF;

    v_qty:=coalesce(nullif(v_item->>'qty','')::numeric,0);
    IF v_qty<=0 OR v_qty>v_source_item.pending_qty_snapshot+0.000001 THEN
      RAISE EXCEPTION '%: requested % exceeds Source remaining %',
        v_code,v_qty,v_source_item.pending_qty_snapshot;
    END IF;
    -- Existing transfer defaults Purchased-first. Explicit source split is
    -- also supported for later UI revisions (both values must sum to Qty).
    IF (v_item?'purchasedQty') OR (v_item?'zeroCostQty') THEN
      v_purchased:=coalesce(nullif(v_item->>'purchasedQty','')::numeric,0);
      v_zero:=coalesce(nullif(v_item->>'zeroCostQty','')::numeric,0);
      IF v_purchased<0 OR v_zero<0 OR abs(v_qty-(v_purchased+v_zero))>0.000001 THEN
        RAISE EXCEPTION '%: Purchased + Zero-Cost must equal requested Qty',v_code;
      END IF;
    ELSE
      v_purchased:=least(v_qty,v_source_item.purchased_pending_qty_snapshot);
      v_zero:=greatest(v_qty-v_purchased,0);
    END IF;
    IF v_purchased>v_source_item.purchased_pending_qty_snapshot+0.000001
      OR v_zero>v_source_item.zero_cost_pending_qty_snapshot+0.000001 THEN
      RAISE EXCEPTION '%: Source Purchased or Zero-Cost is insufficient',v_code;
    END IF;

    -- Remove only pending goods from Source; record as Other Out so the
    -- existing source batch reconciliation (issued - sold - return - damage -
    -- otherOut = pending) still holds, enabling the normal Close Batch guard.
    UPDATE public.stock_batch_items SET
      pending_qty_snapshot=pending_qty_snapshot-v_qty,
      purchased_pending_qty_snapshot=purchased_pending_qty_snapshot-v_purchased,
      zero_cost_pending_qty_snapshot=zero_cost_pending_qty_snapshot-v_zero,
      other_out_qty=other_out_qty+v_qty,
      source_updated_at=now(),updated_at=now()
    WHERE batch_id=v_source_id AND product_code=v_code;

    -- Carry the same product + cost source into the EXISTING destination.
    -- Do not modify the destination's existing sales, damage, or history.
    INSERT INTO public.stock_batch_items(
      batch_id,product_code,product_name_snapshot,unit_snapshot,
      issued_qty,purchased_issued_qty,zero_cost_issued_qty,
      pending_qty_snapshot,purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot,
      source_created_at,source_updated_at
    ) VALUES(
      v_target_id,v_code,v_source_item.product_name_snapshot,v_source_item.unit_snapshot,
      v_qty,v_purchased,v_zero,
      v_qty,v_purchased,v_zero,now(),now()
    ) ON CONFLICT(batch_id,product_code) DO UPDATE SET
      issued_qty=public.stock_batch_items.issued_qty+excluded.issued_qty,
      purchased_issued_qty=public.stock_batch_items.purchased_issued_qty+excluded.purchased_issued_qty,
      zero_cost_issued_qty=public.stock_batch_items.zero_cost_issued_qty+excluded.zero_cost_issued_qty,
      pending_qty_snapshot=public.stock_batch_items.pending_qty_snapshot+excluded.pending_qty_snapshot,
      purchased_pending_qty_snapshot=public.stock_batch_items.purchased_pending_qty_snapshot+excluded.purchased_pending_qty_snapshot,
      zero_cost_pending_qty_snapshot=public.stock_batch_items.zero_cost_pending_qty_snapshot+excluded.zero_cost_pending_qty_snapshot,
      source_updated_at=now(),updated_at=now();

    -- Same-bucket stock TRANSFER is deliberate. It carries no global
    -- warehouse/batch quantity or COGS change in the stock ledger, consistent
    -- with the existing Source -> New Batch transfer implementation.
    FOR v_bucket,v_bucket_qty IN
      SELECT 'BATCH_PENDING'::text,v_purchased
      UNION ALL SELECT 'BATCH_ZERO_COST'::text,v_zero
    LOOP
      IF v_bucket_qty>0.000001 THEN
        v_cost:=CASE WHEN v_bucket='BATCH_PENDING'
          THEN public.bb_stock_average_cost_internal(v_code) ELSE 0 END;
        v_transaction_id:=public.bb_next_prefixed_id(
          'public.stock_activity'::regclass,'transaction_id','TRX',6);
        INSERT INTO public.stock_activity(
          transaction_id,batch_id,activity_date,activity_type,
          product_code,product_name_snapshot,qty,unit_snapshot,
          location_code,from_location_code,to_location_code,
          inventory_controller_staff_id,inventory_controller_name_snapshot,
          salesman_staff_id,salesman_name_snapshot,
          driver_staff_id,driver_name_snapshot,
          driver2_staff_id,driver2_name_snapshot,
          reference_no,note,source_created_at,movement_id,flow,movement_type,
          from_bucket,to_bucket,source_entity_type,source_id,source_name,
          unit_cost,line_value,location_name_snapshot,client_request_id
        ) VALUES (
          v_transaction_id,v_target_id,v_activity_date,'Batch Transfer',
          v_code,coalesce(v_source_item.product_name_snapshot,v_product.product_name),
          v_bucket_qty,coalesce(v_source_item.unit_snapshot,v_product.unit,''),
          v_target.location_code,v_source.location_code,v_target.location_code,
          v_controller_id,v_controller_name,
          v_target.salesman_staff_id,v_target.salesman_name_snapshot,
          v_target.driver_staff_id,v_target.driver_name_snapshot,
          v_target.driver2_staff_id,v_target.driver2_name_snapshot,
          v_source_id||' -> '||v_target_id,
          'Carry forward to existing Open Batch '||v_target_id,
          now(),v_movement_id,'TRANSFER','BATCH_TRANSFER',
          v_bucket,v_bucket,'BATCH_TRANSFER',v_source_id,
          'Batch carry forward '||v_source_id||' -> '||v_target_id,
          v_cost,round(v_bucket_qty*v_cost,6),
          v_target.location_name_snapshot,v_request_id
        );
      END IF;
    END LOOP;
    v_total:=v_total+v_qty;
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
      'productCode',v_code,'productName',v_product.product_name,
      'qty',v_qty,'purchasedQty',v_purchased,'zeroCostQty',v_zero
    ));
  END LOOP;

  -- Header issued quantity is informational. Source header issued remains
  -- historical; destination issued increases for the additional stock.
  UPDATE public.stock_batches SET issued_qty=issued_qty+v_total,
    source_updated_at=now(),updated_at=now()
  WHERE batch_id=v_target_id;

  PERFORM public.bb_stock_refresh_batch_status_internal(v_source_id);
  PERFORM public.bb_stock_refresh_batch_status_internal(v_target_id);
  IF EXISTS (
    SELECT 1 FROM public.stock_batch_items i
    WHERE i.batch_id IN(v_source_id,v_target_id)
      AND (abs(i.pending_qty_snapshot-(i.purchased_pending_qty_snapshot+i.zero_cost_pending_qty_snapshot))>0.000001
        OR abs(i.pending_qty_snapshot-(i.issued_qty-i.sold_qty_snapshot-i.back_sale_qty-i.damaged_qty-i.other_out_qty))>0.000001)
  ) THEN RAISE EXCEPTION 'Transfer rolled back: Batch integrity check failed'; END IF;

  SELECT coalesce(sum(pending_qty_snapshot),0) INTO v_source_remaining
    FROM public.stock_batch_items WHERE batch_id=v_source_id;
  SELECT coalesce(sum(pending_qty_snapshot),0) INTO v_target_remaining
    FROM public.stock_batch_items WHERE batch_id=v_target_id;
  v_revision:=public.bb_stock_touch_revision_internal();
  v_response:=jsonb_build_object(
    'success',true,'version','BATCH-EXISTING-TRANSFER-V1',
    'requestId',v_request_id,'movementId',v_movement_id,'revision',v_revision,
    'sourceBatchId',v_source_id,'targetBatchId',v_target_id,
    'transferQty',v_total,'activityDate',v_activity_date::text,
    'sourceRemainingQty',v_source_remaining,'targetRemainingQty',v_target_remaining,
    'sourceCleared',v_source_remaining<=0.000001,
    'closeRequiresNormalGuard',true,'lines',v_lines,
    'message','Stock carried into existing Batch; close old Batch separately after normal reconciliation.'
  );
  INSERT INTO public.stock_movement_requests(
    request_id,movement_id,response_payload,created_by
  ) VALUES(v_request_id,v_movement_id,v_response,auth.uid());
  RETURN v_response;
END;
$function$;
-- Restrict a SECURITY DEFINER function to signed-in users: internal guard also checks role+modules.
REVOKE ALL ON FUNCTION public.bb_stock_transfer_between_open_batches(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_stock_transfer_between_open_batches(jsonb) TO authenticated;
