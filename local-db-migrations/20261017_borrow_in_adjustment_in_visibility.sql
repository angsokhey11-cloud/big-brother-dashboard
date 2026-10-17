-- BIG BROTHER Local Brain: include recorded Customer Borrow Inflow in Your Stock Adjustment IN.
-- Depends on prior queued Borrow Clear OUT reporting migration.
-- Read-only data reporting change. No new stock_activity rows, no qty changes, no COGS edits.
DO $bb_borrow_in_report$
DECLARE
  v_fn regprocedure:=to_regprocedure('public.bb_sales_support_batch_adjustment_totals(text)');
  v_def text;
  v_old text;
  v_new text;
  v_occurrences integer;
BEGIN
  IF v_fn IS NULL THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: missing Your Stock adjustment function';
  END IF;
  v_def:=pg_get_functiondef(v_fn);
  IF position('Borrow In · ' IN v_def)>0 THEN
    RAISE NOTICE 'Borrow In already included in Your Stock Adjustment IN; no update needed';
    RETURN;
  END IF;
  IF position('borrowClearOutQty' IN v_def)=0
     OR position('route.sales-support-your-stock' IN v_def)=0
     OR position('v_pending_damage' IN v_def)=0 THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: prerequisite Borrow Clear reporting/permission structure differs';
  END IF;
  -- Audited total-in.
  v_old:=$bb_old_1$sum(case when upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
           and upper(coalesce(sa.from_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
           then sa.qty else 0 end)::numeric as adjustment_in_qty,$bb_old_1$;
  v_new:=$bb_new_1$sum(case
           when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
             and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
             and upper(coalesce(sa.from_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
           then sa.qty
           when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW'
             and upper(coalesce(sa.from_bucket,''))='CUSTOMER_BORROW'
             and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
           then sa.qty
           else 0 end)::numeric as adjustment_in_qty,$bb_new_1$;
  v_occurrences:=(length(v_def)-length(replace(v_def,v_old,'')))/length(v_old);
  IF v_occurrences<>1 THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: % source matches for total-in, expected 1',v_occurrences;
  END IF;
  v_def:=replace(v_def,v_old,v_new);
  -- Audited history-in.
  v_old:=$bb_old_2$sum(case when upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
            and upper(coalesce(sa.from_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
            then sa.qty else 0 end)::numeric adjustment_in_qty,$bb_old_2$;
  v_new:=$bb_new_2$sum(case
            when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
              and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
              and upper(coalesce(sa.from_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
            then sa.qty
            when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW'
              and upper(coalesce(sa.from_bucket,''))='CUSTOMER_BORROW'
              and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
            then sa.qty
            else 0 end)::numeric adjustment_in_qty,$bb_new_2$;
  v_occurrences:=(length(v_def)-length(replace(v_def,v_old,'')))/length(v_old);
  IF v_occurrences<>1 THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: % source matches for history-in, expected 1',v_occurrences;
  END IF;
  v_def:=replace(v_def,v_old,v_new);
  -- Audited borrow-identity.
  v_old:=$bb_old_3$max(case when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR' then
        'Borrow Clear · '||coalesce(nullif(trim(sa.reference_no),''),sa.movement_id)
        || case when nullif(trim(coalesce(sa.customer_name_snapshot,'')),'') is not null
           then ' · '||trim(sa.customer_name_snapshot) else '' end
        else coalesce(sa.note,'Batch correction') end) reason,$bb_old_3$;
  v_new:=$bb_new_3$max(case
        when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR' then
          'Borrow Clear · '||coalesce(nullif(trim(sa.reference_no),''),sa.movement_id)
          || case when nullif(trim(coalesce(sa.customer_name_snapshot,'')),'') is not null
             then ' · '||trim(sa.customer_name_snapshot) else '' end
        when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW' then
          'Borrow In · '||coalesce(nullif(trim(sa.reference_no),''),sa.movement_id)
          || case when nullif(trim(coalesce(sa.customer_name_snapshot,'')),'') is not null
             then ' · '||trim(sa.customer_name_snapshot) else '' end
        else coalesce(sa.note,'Batch correction') end) reason,$bb_new_3$;
  v_occurrences:=(length(v_def)-length(replace(v_def,v_old,'')))/length(v_old);
  IF v_occurrences<>1 THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: % source matches for borrow-identity, expected 1',v_occurrences;
  END IF;
  v_def:=replace(v_def,v_old,v_new);
  -- Audited movement-filter.
  v_old:=$bb_old_4$upper(coalesce(sa.movement_type,'')) in ('BATCH_EDIT','CUSTOMER_BORROW_CLEAR')$bb_old_4$;
  v_new:=$bb_new_4$upper(coalesce(sa.movement_type,'')) in ('BATCH_EDIT','CUSTOMER_BORROW','CUSTOMER_BORROW_CLEAR')$bb_new_4$;
  v_occurrences:=(length(v_def)-length(replace(v_def,v_old,'')))/length(v_old);
  IF v_occurrences<>2 THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: % source matches for movement-filter, expected 2',v_occurrences;
  END IF;
  v_def:=replace(v_def,v_old,v_new);
  EXECUTE v_def;
  IF position('Borrow In · ' IN pg_get_functiondef(v_fn))=0 THEN
    RAISE EXCEPTION 'BORROW IN SAFE STOP: post-migration verification failed';
  END IF;
  RAISE NOTICE 'Your Stock Borrow In added to Adjustment IN; stock records unchanged';
END
$bb_borrow_in_report$;
