-- BIG BROTHER | DEDUCT AS COST for genuinely Zero-Cost Damaged Stock
-- Register a $0 noncash write-off with no expense; never inflate purchased-stock expense.
CREATE OR REPLACE FUNCTION public.bb_stock_damage_post_zero_writeoff_v1(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $bb$
DECLARE
 v_transaction_id text:=nullif(trim(coalesce(p_payload->>'transactionId','')),'');
 v_date date:=nullif(trim(coalesce(p_payload->>'writeoffDate','')),'')::date;
 v_reference text:=nullif(trim(coalesce(p_payload->>'referenceNo','')),'');
 v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
 v_activity public.stock_activity%rowtype;
 v_next integer;
 v_id text;
BEGIN
 IF NOT public.bb_is_active_user() OR NOT public.bb_is_admin()
  THEN RAISE EXCEPTION 'Admin access required to post Zero-Cost write-off'; END IF;
 IF v_transaction_id IS NULL OR v_date IS NULL
  THEN RAISE EXCEPTION 'Clearance Transaction and write-off date required'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('BIG_BROTHER_INVENTORY_WRITEOFF_ID'));
 SELECT * INTO v_activity FROM public.stock_activity
 WHERE transaction_id=v_transaction_id AND movement_type='DAMAGE_CLEAR'
 AND damage_clearance_type='DEDUCT_AS_COST'
 AND source_entity_type='BB_DAMAGE_CLEAR_SOURCE'
 AND source_id='ZERO_COST'
 FOR UPDATE;
 IF NOT FOUND OR v_activity.qty<=0 OR coalesce(v_activity.unit_cost,0)<>0
    OR coalesce(v_activity.line_value,0)<>0
 THEN RAISE EXCEPTION 'Zero-Cost write-off must come from a documented $0 damaged source'; END IF;
 IF EXISTS(SELECT 1 FROM public.stock_damage_inventory_writeoffs
   WHERE clearance_transaction_id=v_transaction_id)
 THEN RAISE EXCEPTION 'Write-off already posted for %',v_transaction_id; END IF;
 SELECT coalesce(max(nullif(regexp_replace(writeoff_id,'[^0-9]','','g'),'')::integer),0)+1
 INTO v_next FROM public.stock_damage_inventory_writeoffs;
 v_id:='IWO-'||lpad(v_next::text,6,'0');
 INSERT INTO public.stock_damage_inventory_writeoffs(
  writeoff_id,clearance_movement_id,clearance_transaction_id,writeoff_date,
  product_code,product_name_snapshot,unit_snapshot,writeoff_qty,
  unit_cost,writeoff_value,currency,status,reference_no,note,created_by,expense_id
 ) VALUES (
  v_id,v_activity.movement_id,v_activity.transaction_id,v_date,
  v_activity.product_code,v_activity.product_name_snapshot,v_activity.unit_snapshot,
  v_activity.qty,0,0,'USD','POSTED',v_reference,
  concat_ws(' | ','Zero-Cost source: documented $0 inventory write-off; no expense posted',v_note),
  auth.uid(),NULL
 );
 RETURN jsonb_build_object(
  'success',true,'version','INVENTORY-WRITEOFF-ZERO-V1','writeoffId',v_id,
  'expenseId','','transactionId',v_transaction_id,
  'movementId',v_activity.movement_id,'writeoffDate',v_date::text,
  'productCode',v_activity.product_code,
  'productName',coalesce(v_activity.product_name_snapshot,v_activity.product_code),
  'qty',v_activity.qty,'unit',coalesce(v_activity.unit_snapshot,''),
  'unitCost',0,'writeoffValue',0,'writeoffStatus','POSTED',
  'expenseType','NONE','expenseCategory','Inventory Write-Off',
  'expenseDescription','Zero-Cost Stock Write-Off (no expense)',
  'expenseStatus','NOT_APPLICABLE'
 );
END;
$bb$;

DO $patch_post$
DECLARE d text;v text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT d
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='bb_stock_damage_post_inventory_writeoff';
 IF position('bb_stock_damage_post_zero_writeoff_v1' IN d)>0 THEN RETURN; END IF;
 v:=regexp_replace(d,
 'raise exception[[:space:]]*''Inventory Write-Off Value must be greater than zero'';',
 'IF v_writeoff_value=0 THEN RETURN public.bb_stock_damage_post_zero_writeoff_v1(p_payload); END IF;'||E'\n'||
 '    raise exception ''Inventory Write-Off Value must be greater than zero'';');
 IF position('bb_stock_damage_post_zero_writeoff_v1' IN v)=0
 THEN RAISE EXCEPTION 'Inventory Write-Off cost validation anchor changed'; END IF;
 EXECUTE v;
END;
$patch_post$;
