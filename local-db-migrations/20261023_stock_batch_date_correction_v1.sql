-- BIG BROTHER LOCAL BRAIN V5/V6: Batch Date editor support.
-- Deployment source: local-db-migrations/manifest.json (Code SQL Migration V3.4).
-- Schema/function-only; never changes existing Batch, Invoice, Stock or Audit data.
-- Abort safely if prerequisite SQL or revision of the local correction RPC does not match.
-- Run with Local Code SQL Migration helper (back up the local PostgreSQL database first).
DO $bb_local_batch_date$
DECLARE
  v_wrapper text;
  v_new_date_function text:=$batch_date_fn$
CREATE OR REPLACE FUNCTION public.bb_stock_edit_batch_date(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_batch_id text:=trim(coalesce(p_payload->>'batchId',''));
  v_date_text text:=trim(coalesce(p_payload->>'batchDate',''));
  v_date date;
  v_reason text:=nullif(trim(coalesce(p_payload->>'reason','')),'');
  v_request_id text:=nullif(trim(coalesce(p_payload->>'requestId','')),'');
  v_batch public.stock_batches%rowtype;
  v_existing public.stock_batch_edit_audit%rowtype;
  v_editor_user uuid:=auth.uid();
  v_editor_staff_id text;
  v_editor_name text;
  v_audit_id bigint;
  v_revision text;
BEGIN
  IF NOT public.bb_is_active_user() OR NOT public.bb_has_module_access('Stock Management','edit') THEN
    RAISE EXCEPTION 'Batch Edit access denied';
  END IF;
  IF NOT public.bb_stock_ready_internal() THEN RAISE EXCEPTION 'Stock Supabase cutover is not ready'; END IF;
  IF v_batch_id='' THEN RAISE EXCEPTION 'Batch ID is required'; END IF;
  IF v_reason IS NULL OR length(v_reason)<3 THEN RAISE EXCEPTION 'Correction Reason is required'; END IF;
  IF v_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Batch Date must be YYYY-MM-DD'; END IF;
  BEGIN
    v_date:=v_date_text::date;
  EXCEPTION WHEN others THEN RAISE EXCEPTION 'Invalid Batch Date';
  END;
  IF to_char(v_date,'YYYY-MM-DD')<>v_date_text THEN RAISE EXCEPTION 'Invalid Batch Date'; END IF;
  IF v_request_id IS NULL THEN
    v_request_id:='BATCHDATE-'||to_char(clock_timestamp() at time zone 'Asia/Phnom_Penh','YYYYMMDDHH24MISSMS')||'-'||substr(md5(random()::text),1,8);
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('BB_STOCK_WRITE'));
  SELECT * INTO v_existing FROM public.stock_batch_edit_audit WHERE request_id=v_request_id;
  IF found THEN
    IF v_existing.batch_id<>v_batch_id THEN RAISE EXCEPTION 'Correction request ID belongs to another Batch'; END IF;
    RETURN jsonb_build_object('success',true,'duplicate',true,'batchId',v_batch_id,'editId',v_existing.edit_id,'requestId',v_request_id);
  END IF;
  SELECT * INTO v_batch FROM public.stock_batches WHERE batch_id=v_batch_id FOR UPDATE;
  IF NOT found THEN RAISE EXCEPTION 'Batch % was not found',v_batch_id; END IF;
  IF upper(coalesce(v_batch.status,'')) IN ('CLOSED','CANCELLED','CANCELED') THEN RAISE EXCEPTION 'Closed/cancelled Batch cannot be edited'; END IF;
  IF NOT public.bb_has_location_access(v_batch.location_code) THEN RAISE EXCEPTION 'Batch Location access denied'; END IF;
  IF EXISTS (SELECT 1 FROM public.invoices i WHERE i.batch_id=v_batch_id)
    OR EXISTS (
      SELECT 1 FROM public.stock_batch_items i WHERE i.batch_id=v_batch_id
      AND (
        greatest(coalesce(i.issued_qty,0)-coalesce(i.pending_qty_snapshot,0),0)>0.000001
        OR coalesce(i.sold_qty_snapshot,0)>0.000001
        OR coalesce(i.back_sale_qty,0)>0.000001
        OR coalesce(i.damaged_qty,0)>0.000001
        OR coalesce(i.other_out_qty,0)>0.000001
      )
    ) THEN
    RAISE EXCEPTION 'Batch Date is locked after an Invoice or stock usage';
  END IF;
  IF v_date=v_batch.batch_date THEN RAISE EXCEPTION 'No Batch Date change was made'; END IF;
  SELECT u.staff_id INTO v_editor_staff_id FROM public.app_users u WHERE u.user_id=v_editor_user AND u.active=true LIMIT 1;
  IF v_editor_staff_id IS NOT NULL THEN
    SELECT s.staff_name INTO v_editor_name FROM public.staff s WHERE s.staff_id=v_editor_staff_id LIMIT 1;
  END IF;
  v_editor_name:=coalesce(v_editor_name,'BIG BROTHER Admin');
  UPDATE public.stock_batches SET batch_date=v_date,updated_at=now(),source_updated_at=now() WHERE batch_id=v_batch_id;
  INSERT INTO public.stock_batch_edit_audit(
    request_id,batch_id,reason,edited_by_user_id,edited_by_staff_id,edited_by_name,before_payload,after_payload
  ) VALUES (
    v_request_id,v_batch_id,v_reason,v_editor_user,v_editor_staff_id,v_editor_name,
    jsonb_build_object('changeType','BATCH_DATE','batchDate',v_batch.batch_date::text),
    jsonb_build_object('changeType','BATCH_DATE','batchDate',v_date::text)
  ) RETURNING edit_id INTO v_audit_id;
  v_revision:=public.bb_stock_touch_revision_internal();
  RETURN jsonb_build_object(
    'success',true,'version','BATCH-DATE-EDIT-V1','batchId',v_batch_id,'batchDate',v_date::text,
    'previousBatchDate',v_batch.batch_date::text,'editId',v_audit_id,'requestId',v_request_id,'revision',v_revision
  );
END;
$function$
$batch_date_fn$;
BEGIN
  IF to_regclass('public.stock_batches') IS NULL
     OR to_regclass('public.stock_batch_edit_audit') IS NULL
     OR to_regprocedure('public.bb_stock_edit_batch_correction(jsonb)') IS NULL
     OR to_regprocedure('public.bb_stock_batch_edit_header_options(text)') IS NULL
     OR to_regprocedure('public.bb_stock_touch_revision_internal()') IS NULL THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: required Local Brain batch schema/functions missing. Run schema guard first.';
  END IF;
  IF position('canEditRouting' in pg_get_functiondef('public.bb_stock_batch_edit_header_options(text)'::regprocedure))=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: Local routing lock support missing. Apply earlier local migrations first.';
  END IF;
  SELECT pg_get_functiondef('public.bb_stock_edit_batch_correction(jsonb)'::regprocedure) INTO v_wrapper;
  IF position('BATCH-CORRECTION-V4' in v_wrapper)>0 THEN
    IF to_regprocedure('public.bb_stock_edit_batch_date(jsonb)') IS NULL THEN
      RAISE EXCEPTION 'BATCH DATE SAFE STOP: V4 correction found without Batch Date RPC';
    END IF;
    RAISE NOTICE 'BATCH DATE: already installed; existing V4 functions retained';
    RETURN;
  END IF;
  IF position('BATCH-CORRECTION-V3' in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: expected V3 correction wrapper not found. Do not overwrite local custom changes.';
  END IF;
  IF position($part$  v_items_changed boolean:=coalesce((p_payload->>'itemsChanged')::boolean,false);$part$ in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: local correction function does not match expected V3 patch points';
  END IF;
  IF position($part$  v_items_result jsonb:='{}'::jsonb;$part$ in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: local correction function does not match expected V3 patch points';
  END IF;
  IF position($part$if not v_header_changed and not v_items_changed then$part$ in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: local correction function does not match expected V3 patch points';
  END IF;
  IF position($part$  return jsonb_build_object(
    'success',true,'version','BATCH-CORRECTION-V3',$part$ in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: local correction function does not match expected V3 patch points';
  END IF;
  IF position($part$    'itemsChanged',v_items_changed,$part$ in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: local correction function does not match expected V3 patch points';
  END IF;
  IF position($part$    'itemsResult',v_items_result
$part$ in v_wrapper)=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: local correction function does not match expected V3 patch points';
  END IF;
  v_wrapper:=replace(v_wrapper,$part$  v_items_changed boolean:=coalesce((p_payload->>'itemsChanged')::boolean,false);$part$,$part$  v_items_changed boolean:=coalesce((p_payload->>'itemsChanged')::boolean,false);
  v_date_changed boolean:=coalesce((p_payload->>'dateChanged')::boolean,false);$part$);
  v_wrapper:=replace(v_wrapper,$part$  v_items_result jsonb:='{}'::jsonb;$part$,$part$  v_items_result jsonb:='{}'::jsonb;
  v_date_result jsonb:='{}'::jsonb;$part$);
  v_wrapper:=replace(v_wrapper,$part$if not v_header_changed and not v_items_changed then$part$,$part$if not v_header_changed and not v_items_changed and not v_date_changed then$part$);
  v_wrapper:=replace(v_wrapper,$part$  return jsonb_build_object(
    'success',true,'version','BATCH-CORRECTION-V3',$part$,$part$  if v_date_changed then
    v_date_result:=public.bb_stock_edit_batch_date(jsonb_build_object(
      'batchId',v_batch_id,'batchDate',p_payload->>'batchDate',
      'reason',v_reason,'requestId',v_request_id||'-DATE'
    ));
  end if;

  return jsonb_build_object(
    'success',true,'version','BATCH-CORRECTION-V4',$part$);
  v_wrapper:=replace(v_wrapper,$part$    'itemsChanged',v_items_changed,$part$,$part$    'itemsChanged',v_items_changed,
    'dateChanged',v_date_changed,$part$);
  v_wrapper:=replace(v_wrapper,$part$    'itemsResult',v_items_result
$part$,$part$    'itemsResult',v_items_result,
    'dateResult',v_date_result
$part$);
  EXECUTE v_new_date_function;
  EXECUTE 'REVOKE ALL ON FUNCTION public.bb_stock_edit_batch_date(jsonb) FROM PUBLIC, anon';
  EXECUTE 'GRANT EXECUTE ON FUNCTION public.bb_stock_edit_batch_date(jsonb) TO authenticated';
  EXECUTE v_wrapper;
  IF position('BATCH-CORRECTION-V4' in pg_get_functiondef('public.bb_stock_edit_batch_correction(jsonb)'::regprocedure))=0
     OR position('dateChanged' in pg_get_functiondef('public.bb_stock_edit_batch_correction(jsonb)'::regprocedure))=0
     OR position('BATCH-DATE-EDIT-V1' in pg_get_functiondef('public.bb_stock_edit_batch_date(jsonb)'::regprocedure))=0 THEN
    RAISE EXCEPTION 'BATCH DATE SAFE STOP: post-install verification failed';
  END IF;
  RAISE NOTICE 'BATCH DATE VERIFIED: RPC installed with audit/permission lock; existing business data unchanged.';
END;
$bb_local_batch_date$;
