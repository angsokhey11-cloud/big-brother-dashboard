-- BIG BROTHER LOCAL BRAIN — Borrow Clear becomes visible under Your Stock Adjustment OUT.
-- Source: Cloud movement ledger already records CUSTOMER_BORROW_CLEAR as OUTFLOW.
-- Reporting-only function patch. No new stock movements, no COGS or batch quantity writes.
-- Each old fragment must match exactly once. If Local differs, safe-stop without edits.
DO $bb_borrow_report_patch$
DECLARE
  v_fn regprocedure := to_regprocedure('public.bb_sales_support_batch_adjustment_totals(text)');
  v_def text;
  v_old text;
  v_new text;
BEGIN
  IF v_fn IS NULL THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: Your Stock adjustment function missing';
  END IF;
  SELECT pg_get_functiondef(v_fn) INTO v_def;
  IF position('borrowClearOutQty' IN v_def)>0 THEN
    RAISE NOTICE 'Borrow Clear is already visible in Adjustment OUT. No changes.';
    RETURN;
  END IF;
  IF position('route.sales-support-your-stock' IN v_def)=0
    OR position('public.bb_is_admin()' IN v_def)=0
    OR position('private.' IN v_def)>0
    OR position('v_pending_damage' IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: Your Stock permission/function structure differs from audited version';
  END IF;
  v_old := $bb_old1$'adjustmentOutQty',round(a.adjustment_out_qty,6),$bb_old1$;
  v_new := $bb_new1$'adjustmentOutQty',round(a.adjustment_out_qty,6),
    'borrowClearOutQty',round(a.borrow_clear_out_qty,6),$bb_new1$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 1';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := $bb_old2$sum(case when upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
           and upper(coalesce(sa.to_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
           then sa.qty else 0 end)::numeric as adjustment_out_qty,$bb_old2$;
  v_new := $bb_new2$sum(case
           when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
             and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
             and upper(coalesce(sa.to_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
           then sa.qty
           when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR'
             and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
             and upper(coalesce(sa.to_bucket,''))='CUSTOMER_BORROW_RETURN'
           then sa.qty
           else 0 end)::numeric as adjustment_out_qty,
      sum(case when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR'
           and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
           and upper(coalesce(sa.to_bucket,''))='CUSTOMER_BORROW_RETURN'
           then sa.qty else 0 end)::numeric as borrow_clear_out_qty,$bb_new2$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 2';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := $bb_old3$and upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
      and sa.product_code is not null$bb_old3$;
  v_new := $bb_new3$and upper(coalesce(sa.movement_type,'')) in ('BATCH_EDIT','CUSTOMER_BORROW_CLEAR')
      and sa.product_code is not null$bb_new3$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 3';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := $bb_old4$'adjustmentOutQty',round(h.adjustment_out_qty,6),$bb_old4$;
  v_new := $bb_new4$'adjustmentOutQty',round(h.adjustment_out_qty,6),
    'movementType',h.movement_type,
    'referenceNo',h.reference_no,
    'activityDate',h.activity_date,$bb_new4$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 4';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := $bb_old5$max(coalesce(sa.note,'Batch correction')) reason,$bb_old5$;
  v_new := $bb_new5$max(case when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR' then
        'Borrow Clear · '||coalesce(nullif(trim(sa.reference_no),''),sa.movement_id)
        || case when nullif(trim(coalesce(sa.customer_name_snapshot,'')),'') is not null
           then ' · '||trim(sa.customer_name_snapshot) else '' end
        else coalesce(sa.note,'Batch correction') end) reason,
      max(sa.activity_date)::text activity_date,
      max(sa.reference_no) reference_no,
      max(sa.movement_type) movement_type,$bb_new5$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 5';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := $bb_old6$sum(case when upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
            and upper(coalesce(sa.to_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
            then sa.qty else 0 end)::numeric adjustment_out_qty$bb_old6$;
  v_new := $bb_new6$sum(case
            when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
              and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
              and upper(coalesce(sa.to_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
            then sa.qty
            when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR'
              and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
              and upper(coalesce(sa.to_bucket,''))='CUSTOMER_BORROW_RETURN'
            then sa.qty
            else 0 end)::numeric adjustment_out_qty$bb_new6$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 6';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := $bb_old7$where sa.batch_id=p_batch_id and upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
      and sa.product_code is not null$bb_old7$;
  v_new := $bb_new7$where sa.batch_id=p_batch_id and upper(coalesce(sa.movement_type,'')) in ('BATCH_EDIT','CUSTOMER_BORROW_CLEAR')
      and sa.product_code is not null$bb_new7$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: missing audited source fragment 7';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
  IF position('borrowClearOutQty' IN
    pg_get_functiondef('public.bb_sales_support_batch_adjustment_totals(text)'::regprocedure))=0 THEN
    RAISE EXCEPTION 'BORROW VISIBILITY SAFE STOP: result verification failed';
  END IF;
  RAISE NOTICE 'Borrow Clear added to Your Stock Adjustment OUT history: source records unchanged';
END
$bb_borrow_report_patch$;
