-- BIG BROTHER: Batch selling-date window, one-day or multi-day issue; 12-Nov-2026.
-- Keep both dates NULL for historical batches (no retroactive restriction).
ALTER TABLE public.stock_batches ADD COLUMN IF NOT EXISTS selling_date_from date;
ALTER TABLE public.stock_batches ADD COLUMN IF NOT EXISTS selling_date_to date;
ALTER TABLE public.stock_batches DROP CONSTRAINT IF EXISTS bb_batch_selling_window_consistent;
ALTER TABLE public.stock_batches ADD CONSTRAINT bb_batch_selling_window_consistent
CHECK ((selling_date_from IS NULL AND selling_date_to IS NULL)
   OR (selling_date_from IS NOT NULL AND selling_date_to IS NOT NULL AND selling_date_from<=selling_date_to));

-- This internal helper saves a real batch through the EXISTING, guarded stock engine.
-- Then attaches the approved selling-date window atomically to the returned batch.
CREATE OR REPLACE FUNCTION public.bb_stock_issue_batch_with_selling_window_v1(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $func$
DECLARE
 v_from_text text:=nullif(btrim(coalesce(p_payload->>'sellingDateFrom','')),'');
 v_to_text text:=nullif(btrim(coalesce(p_payload->>'sellingDateTo','')),'');
 v_date text:=btrim(coalesce(p_payload->>'activityDate',''));
 v_from date;
 v_to date;
 v_result jsonb;
 v_id text;
 v_batch public.stock_batches%ROWTYPE;
 v_duplicate boolean;
 v_source text:=upper(btrim(coalesce(p_payload->>'stockSource','WAREHOUSE')));
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_active_user()
    OR NOT public.bb_stock_keyin_route_access('create')
 THEN RAISE EXCEPTION 'Stock Issue access denied'; END IF;
 IF NOT public.bb_stock_ready_internal() THEN
   RAISE EXCEPTION 'Stock cutover is not ready'; END IF;
 IF upper(btrim(coalesce(p_payload->>'movementType',''))) <> 'BATCH_STOCK' THEN
   RAISE EXCEPTION 'Selling date range can only be set when issuing a Batch'; END IF;
 -- Compatibility: an older stock key-in client gets a single-day window,
 -- NOT an unrestricted batch. New clients submit both explicit dates.
 IF v_from_text IS NULL THEN v_from_text:=v_date; END IF;
 IF v_to_text IS NULL THEN v_to_text:=v_date; END IF;
 IF v_from_text !~ '^\d{4}-\d{2}-\d{2}$'
    OR v_to_text !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RAISE EXCEPTION 'Select both allowed Batch Selling Dates (YYYY-MM-DD)'; END IF;
 BEGIN
    v_from:=v_from_text::date;
    v_to:=v_to_text::date;
 EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Invalid Batch Selling Date range'; END;
 IF to_char(v_from,'YYYY-MM-DD')<>v_from_text
    OR to_char(v_to,'YYYY-MM-DD')<>v_to_text
    OR v_from>v_to
 THEN RAISE EXCEPTION 'Batch selling From Date cannot be later than To Date'; END IF;

 IF v_source='OPEN_BATCH'
    OR nullif(btrim(coalesce(p_payload->>'sourceBatchId','')),'') IS NOT NULL
 THEN
   v_result:=public.bb_stock_save_batch_transfer_internal(p_payload);
 ELSE
   v_result:=public.bb_stock_save_batch_stock_with_earning_review(p_payload);
 END IF;
 v_id:=nullif(btrim(coalesce(v_result->>'batchId','')),'');
 IF v_id IS NULL THEN RAISE EXCEPTION 'Batch issue did not return the new Batch ID'; END IF;
 SELECT * INTO v_batch FROM public.stock_batches WHERE batch_id=v_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Issued Batch % does not exist',v_id; END IF;
 v_duplicate:=coalesce((v_result->>'duplicate')::boolean,false);
 IF v_duplicate THEN
   IF v_batch.selling_date_from IS DISTINCT FROM v_from
      OR v_batch.selling_date_to IS DISTINCT FROM v_to
   THEN RAISE EXCEPTION 'Duplicate issue request has a different date window; refresh the Batch list'; END IF;
 ELSE
   IF v_batch.selling_date_from IS NOT NULL OR v_batch.selling_date_to IS NOT NULL
   THEN RAISE EXCEPTION 'New Batch selling-date window already set'; END IF;
   UPDATE public.stock_batches SET selling_date_from=v_from,selling_date_to=v_to
    WHERE batch_id=v_id;
 END IF;
 RETURN v_result||jsonb_build_object('sellingDateFrom',v_from::text,'sellingDateTo',v_to::text);
END;
$func$;

CREATE OR REPLACE FUNCTION public.bb_stock_save_movement(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_type text:=upper(trim(coalesce(p_payload->>'movementType','')));
  v_damage text:=upper(trim(coalesce(p_payload->>'damageSource','WAREHOUSE')));
  v_stock_source text:=upper(trim(coalesce(p_payload->>'stockSource','WAREHOUSE')));
begin
  if not public.bb_is_active_user() or not public.bb_stock_keyin_route_access('create') then
    raise exception 'Stock Management create access denied';
  end if;
  if not public.bb_stock_ready_internal() then
    raise exception 'Stock Supabase cutover is not ready yet';
  end if;
  if v_type='PURCHASE' then return public.bb_stock_save_purchase_movement_v1(p_payload); end if;
  if v_type='RECEIVE_FROM_CLIENT' then return public.bb_stock_save_receive_client_internal(p_payload); end if;
  if v_type='CUSTOMER_BORROW' then return public.bb_stock_save_customer_borrow(p_payload); end if;
  if v_type='BATCH_STOCK' then return public.bb_stock_issue_batch_with_selling_window_v1(p_payload); end if;
  if v_type='BACK_SALE' then return public.bb_stock_save_batch_reference_internal(p_payload,'BACK_SALE'); end if;
  if v_type='CUSTOMER_BORROW_CLEAR' then return public.bb_stock_clear_customer_borrow(p_payload); end if;
  if v_type='STAFF_ALLOWANCE' then return public.bb_stock_save_warehouse_out_internal(p_payload,'STAFF_ALLOWANCE'); end if;
  if v_type='STOCK_DAMAGE' and v_damage='WAREHOUSE' then
    if exists (select 1 from jsonb_array_elements(coalesce(p_payload->'items','[]'::jsonb)) x where x ? 'purchasedQty' or x ? 'zeroCostQty') then
      return public.bb_stock_save_warehouse_damage_sources_v1(p_payload);
    end if;
    return public.bb_stock_save_warehouse_out_internal(p_payload,'STOCK_DAMAGE');
  end if;
  if v_type='STOCK_DAMAGE' and v_damage='BATCH' then return public.bb_stock_receive_reported_batch_damage(p_payload); end if;
  if v_type='DAMAGE_CLEAR' then return public.bb_stock_clear_damaged_v2(p_payload); end if;
  if v_type='DAMAGE_EXCHANGE_RECEIVE' then return public.bb_stock_receive_damage_exchange(p_payload); end if;
  raise exception 'Stock movement % is not migrated yet',coalesce(nullif(v_type,''),'UNKNOWN');
end;
$function$;

-- Extend the existing batch picker; preserve its location authorization.
CREATE OR REPLACE FUNCTION public.bb_sales_open_batches()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v jsonb; v_batches jsonb;
begin
  if not (public.bb_has_module_access('invoice_generator','view') or public.bb_has_module_access('invoice_generator','create')) then raise exception 'Invoice Generator access denied'; end if;
  v:=public.bb_sales_open_batches_core_access_v1();
  select coalesce(jsonb_agg(
    x || jsonb_build_object('sellingDateFrom',b.selling_date_from,'sellingDateTo',b.selling_date_to)
    ),'[]'::jsonb) into v_batches
  from jsonb_array_elements(coalesce(v->'batches','[]'::jsonb)) x
  join public.stock_batches b on b.batch_id=x->>'batchId'
  where public.bb_has_location_access(x->>'locationCode');
  return jsonb_set(v,'{batches}',v_batches,true);
end;$function$;

-- Staff-only guard: Invoice Generator cannot use a date outside the issued range.
-- Admin remains authorized to make historical or exceptional corrections.
CREATE OR REPLACE FUNCTION private.bb_invoice_batch_selling_date_guard_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $func$
DECLARE v_batch_id text;
        v_from date;
        v_to date;
        v_status text;
BEGIN
 IF auth.uid() IS NULL OR public.bb_is_admin() THEN RETURN NEW; END IF;
 v_batch_id:=coalesce(nullif(btrim(coalesce(NEW.batch_id,'')),''),
                      nullif(btrim(coalesce(NEW.batch_number,'')),''));
 IF v_batch_id IS NULL THEN RETURN NEW; END IF; -- direct/warehouse sale unchanged
 SELECT b.selling_date_from,b.selling_date_to,b.status INTO v_from,v_to,v_status
 FROM public.stock_batches b WHERE b.batch_id=v_batch_id;
 IF NOT FOUND THEN
    RAISE EXCEPTION 'Selected Batch % does not exist',v_batch_id; END IF;
 IF v_from IS NULL AND v_to IS NULL THEN RETURN NEW; END IF; -- legacy batch
 IF v_from IS NULL OR v_to IS NULL OR NEW.invoice_date IS NULL
   THEN RAISE EXCEPTION 'Batch % has an incomplete selling-date restriction',v_batch_id; END IF;
 IF NEW.invoice_date<v_from OR NEW.invoice_date>v_to THEN
   RAISE EXCEPTION 'Batch % permits selling dates % to %. Staff cannot save an invoice dated %. Ask Admin to correct the Batch range',
    v_batch_id,to_char(v_from,'DD-Mon-YYYY'),to_char(v_to,'DD-Mon-YYYY'),to_char(NEW.invoice_date,'DD-Mon-YYYY');
 END IF;
 RETURN NEW;
END;
$func$;
DROP TRIGGER IF EXISTS bb_invoice_batch_selling_date_guard_v1 ON public.invoices;
CREATE TRIGGER bb_invoice_batch_selling_date_guard_v1
 BEFORE INSERT OR UPDATE OF invoice_date,batch_id,batch_number ON public.invoices
 FOR EACH ROW EXECUTE FUNCTION private.bb_invoice_batch_selling_date_guard_v1();

-- Admin may adjust a window on an open batch, but cannot retrospectively
-- exclude invoices already issued. Require an auditable reason.
CREATE OR REPLACE FUNCTION public.bb_stock_admin_update_selling_window_v1(
 p_batch_id text,p_from date,p_to date,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $func$
DECLARE v_batch public.stock_batches%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_admin() THEN
   RAISE EXCEPTION 'Only Admin may change an issued Batch date range'; END IF;
 IF length(btrim(coalesce(p_reason,'')))<5 THEN
   RAISE EXCEPTION 'Enter an audit reason (at least 5 characters)'; END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_to<p_from THEN
   RAISE EXCEPTION 'Invalid Batch date window'; END IF;
 SELECT * INTO v_batch FROM public.stock_batches
 WHERE batch_id=btrim(coalesce(p_batch_id,'')) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
 IF upper(btrim(v_batch.status)) <> 'OPEN' THEN
   RAISE EXCEPTION 'Only open Batch date windows can be corrected'; END IF;
 IF EXISTS (SELECT 1 FROM public.invoices i
   WHERE (i.batch_id=v_batch.batch_id OR i.batch_number=v_batch.batch_id)
     AND (i.invoice_date<p_from OR i.invoice_date>p_to))
 THEN RAISE EXCEPTION 'Existing Batch invoices fall outside the proposed date range'; END IF;
 UPDATE public.stock_batches
 SET selling_date_from=p_from,selling_date_to=p_to
 WHERE batch_id=v_batch.batch_id;
 INSERT INTO public.system_activity_log(
   actor_user_id,actor_staff_id,actor_name,module_key,action,
   entity_type,entity_id,location_code,summary,metadata)
 VALUES(auth.uid(),public.bb_actor_staff_id(),public.bb_actor_name(),
   'Stock Management','BATCH_SELLING_WINDOW_UPDATE',
   'stock_batches',v_batch.batch_id,v_batch.location_code,
   'Admin updated Batch selling-date window · '||v_batch.batch_id,
   jsonb_build_object('reason',p_reason,
      'oldFrom',v_batch.selling_date_from,'oldTo',v_batch.selling_date_to,
      'newFrom',p_from,'newTo',p_to));
 RETURN jsonb_build_object('success',true,'batchId',v_batch.batch_id,
   'sellingDateFrom',p_from,'sellingDateTo',p_to);
END;$func$;

REVOKE ALL ON FUNCTION public.bb_stock_issue_batch_with_selling_window_v1(jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bb_stock_admin_update_selling_window_v1(text,date,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_stock_issue_batch_with_selling_window_v1(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bb_stock_admin_update_selling_window_v1(text,date,date,text) TO authenticated;

-- Direct authenticated calls to the older internal transfer function would
-- bypass the new issue-time date window. All UI transfers use bb_stock_save_movement.
REVOKE EXECUTE ON FUNCTION public.bb_stock_save_batch_transfer_internal(jsonb) FROM authenticated;
