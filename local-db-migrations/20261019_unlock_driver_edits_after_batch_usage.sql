-- BIG BROTHER V3.4: Local-only Driver 1/2 correction unlock (2026-10-19)
-- No existing data is changed by installation; batch edits still create audit records.
-- Allow corrections to drivers on OPEN/used batches. Preserve Salesman and Location locks.
-- Local Code SQL Migration helper supplies an automatic backup and transaction.
DO $bb_local_driver_unlock$
DECLARE
 v_header text; v_options text;
 v_old_invoice text := $old_invoice$
  if exists(select 1 from public.invoices i where i.batch_id=v_batch_id) then
    raise exception 'Batch routing cannot be changed after an Invoice has been created for this Batch.';
  end if;$old_invoice$;
 v_new_invoice text := $new_invoice$
  if exists(select 1 from public.invoices i where i.batch_id=v_batch_id)
     and (v_salesman_id is distinct from coalesce(v_batch.salesman_staff_id,'')
          or v_new_location is distinct from coalesce(v_batch.location_code,'')) then
    raise exception 'Salesman and Location cannot be changed after an Invoice has been created for this Batch. Driver corrections remain allowed.';
  end if;$new_invoice$;
 v_old_used text := $old_used$
  ) then
    raise exception 'Batch routing cannot be changed after stock from this Batch has been used.';
  end if;$old_used$;
 v_new_used text := $new_used$
  ) and (v_salesman_id is distinct from coalesce(v_batch.salesman_staff_id,'')
          or v_new_location is distinct from coalesce(v_batch.location_code,'')) then
    raise exception 'Salesman and Location cannot be changed after stock has been used. Driver corrections remain allowed.';
  end if;$new_used$;
 v_old_reason text := $old_reason$when v_has_invoice then 'Batch routing cannot be changed after an Invoice has been created for this Batch.'
      when v_has_used then 'Batch routing cannot be changed after stock from this Batch has been used.'$old_reason$;
 v_new_reason text := $new_reason$when v_has_invoice then 'Salesman and Location are locked after an Invoice; Driver 1 and Driver 2 may still be corrected.'
      when v_has_used then 'Salesman and Location are locked after stock usage; Driver 1 and Driver 2 may still be corrected.'$new_reason$;
BEGIN
 IF to_regprocedure('public.bb_stock_edit_batch_header(jsonb)') IS NULL
    OR to_regprocedure('public.bb_stock_batch_edit_header_options(text)') IS NULL THEN
   RAISE EXCEPTION 'DRIVER UNLOCK SAFE STOP: required batch edit functions missing';
 END IF;
 SELECT pg_get_functiondef('public.bb_stock_edit_batch_header(jsonb)'::regprocedure) INTO v_header;
 SELECT pg_get_functiondef('public.bb_stock_batch_edit_header_options(text)'::regprocedure) INTO v_options;
 IF position('Batch Edit access denied' in v_header)=0
    OR position('Batch Location access denied' in v_header)=0
    OR position('Correction Reason is required' in v_header)=0
    OR position('Driver 2 must be different from Driver 1' in v_header)=0
    OR position('stock_batch_edit_audit' in v_header)=0
    OR position('v_has_invoice' in v_options)=0
    OR position('v_has_used' in v_options)=0 THEN
   RAISE EXCEPTION 'DRIVER UNLOCK SAFE STOP: baseline permission, driver, or audit checks changed';
 END IF;
 IF position(v_new_invoice in v_header)>0 AND position(v_new_used in v_header)>0
    AND position('''canEditDrivers'',true' in v_options)>0 THEN
   RAISE NOTICE 'DRIVER UNLOCK already installed; no changes required';
 ELSE
   IF position(v_old_invoice in v_header)=0 OR position(v_old_used in v_header)=0
      OR position('''canEditHeader'',not v_has_invoice and not v_has_used,' in v_options)=0
      OR position(v_old_reason in v_options)=0 THEN
     RAISE EXCEPTION 'DRIVER UNLOCK SAFE STOP: Local functions differ from reviewed version';
   END IF;
   v_header:=replace(v_header,v_old_invoice,v_new_invoice);
   v_header:=replace(v_header,v_old_used,v_new_used);
   v_options:=replace(v_options,
     '''canEditHeader'',not v_has_invoice and not v_has_used,',
     '''canEditHeader'',true,'||E'\n    '||
     '''canEditRouting'',not v_has_invoice and not v_has_used,'||E'\n    '||
     '''canEditDrivers'',true,');
   v_options:=replace(v_options,v_old_reason,v_new_reason);
   EXECUTE v_header;
   EXECUTE v_options;
 END IF;
 IF position(v_new_invoice in pg_get_functiondef('public.bb_stock_edit_batch_header(jsonb)'::regprocedure))=0
    OR position(v_new_used in pg_get_functiondef('public.bb_stock_edit_batch_header(jsonb)'::regprocedure))=0
    OR position('''canEditDrivers'',true' in pg_get_functiondef('public.bb_stock_batch_edit_header_options(text)'::regprocedure))=0 THEN
   RAISE EXCEPTION 'DRIVER UNLOCK SAFE STOP: post-install verification failed';
 END IF;
 RAISE NOTICE 'DRIVER UNLOCK VERIFIED: Drivers editable; routing safeguards and audit preserved';
END
$bb_local_driver_unlock$;
