CREATE OR REPLACE FUNCTION public.bb_sales_support_batch_adjustment_totals(p_batch_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_staff_id text;
  v_payload jsonb;
  v_history jsonb;
  v_damage jsonb;
  v_pending_damage jsonb;
begin
  if not public.bb_is_active_user() or (
    not public.bb_is_admin()
    and not public.bb_has_module_access('route.sales-support-your-stock','view')
  ) then
    raise exception 'Your Stock access denied';
  end if;
  select staff_id into v_staff_id from public.app_users
  where user_id=auth.uid() and active=true;
  if nullif(trim(coalesce(p_batch_id,'')),'') is null
     or not exists(
       select 1 from public.stock_batches b
       where b.batch_id=p_batch_id
       and (public.bb_is_admin() or
            (b.salesman_staff_id=v_staff_id and v_staff_id is not null))
     ) then
    raise exception 'This batch is not assigned to your stock';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'productCode',a.product_code,
    'adjustmentInQty',round(a.adjustment_in_qty,6),
    'adjustmentOutQty',round(a.adjustment_out_qty,6),
    'borrowClearOutQty',round(a.borrow_clear_out_qty,6),
    'lastAdjustmentAt',a.last_adjustment_at,
    'productName',coalesce(p.product_name,i.product_name_snapshot,a.product_code),
    'unit',coalesce(p.unit,i.unit_snapshot,''),
    'assignedQty',round(coalesce(i.issued_qty,0),6),
    'soldQty',round(coalesce(i.sold_qty_snapshot,0),6),
    'damagedQty',round(coalesce(i.damaged_qty,0),6),
    'currentQty',round(greatest(coalesce(i.pending_qty_snapshot,0),0),6)
  ) order by a.product_code),'[]'::jsonb)
  into v_payload
  from (
    select sa.product_code,
      sum(case
           when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
             and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
             and upper(coalesce(sa.from_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
           then sa.qty
           when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW'
             and upper(coalesce(sa.from_bucket,''))='CUSTOMER_BORROW'
             and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
           then sa.qty
           else 0 end)::numeric as adjustment_in_qty,
      sum(case
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
           then sa.qty else 0 end)::numeric as borrow_clear_out_qty,
      max(sa.created_at) as last_adjustment_at
    from public.stock_activity sa
    where sa.batch_id=p_batch_id
      and upper(coalesce(sa.movement_type,'')) in ('BATCH_EDIT','CUSTOMER_BORROW','CUSTOMER_BORROW_CLEAR')
      and sa.product_code is not null
    group by sa.product_code
  ) a
  left join public.stock_batch_items i
    on i.batch_id=p_batch_id and i.product_code=a.product_code
  left join public.products p on p.product_code=a.product_code;

  select coalesce(jsonb_agg(jsonb_build_object(
    'productCode',h.product_code,
    'productName',h.product_name,
    'unit',h.unit,
    'adjustmentInQty',round(h.adjustment_in_qty,6),
    'adjustmentOutQty',round(h.adjustment_out_qty,6),
    'movementType',h.movement_type,
    'referenceNo',h.reference_no,
    'activityDate',h.activity_date,
    'reason',h.reason,
    'createdAt',h.created_at,
    'movementId',h.movement_id
  ) order by h.created_at desc,h.movement_id desc,h.product_name),'[]'::jsonb)
  into v_history
  from (
    select sa.movement_id,sa.product_code,
      coalesce(p.product_name,sa.product_name_snapshot,sa.product_code) product_name,
      coalesce(p.unit,sa.unit_snapshot,'') unit,
      max(case
        when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR' then
          'Borrow Clear · '||coalesce(nullif(trim(sa.reference_no),''),sa.movement_id)
          || case when nullif(trim(coalesce(sa.customer_name_snapshot,'')),'') is not null
             then ' · '||trim(sa.customer_name_snapshot) else '' end
        when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW' then
          'Borrow In · '||coalesce(nullif(trim(sa.reference_no),''),sa.movement_id)
          || case when nullif(trim(coalesce(sa.customer_name_snapshot,'')),'') is not null
             then ' · '||trim(sa.customer_name_snapshot) else '' end
        else coalesce(sa.note,'Batch correction') end) reason,
      max(sa.activity_date)::text activity_date,
      max(sa.reference_no) reference_no,
      max(sa.movement_type) movement_type,
      max(sa.created_at) created_at,
      sum(case
            when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
              and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
              and upper(coalesce(sa.from_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
            then sa.qty
            when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW'
              and upper(coalesce(sa.from_bucket,''))='CUSTOMER_BORROW'
              and upper(coalesce(sa.to_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
            then sa.qty
            else 0 end)::numeric adjustment_in_qty,
      sum(case
            when upper(coalesce(sa.movement_type,''))='BATCH_EDIT'
              and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
              and upper(coalesce(sa.to_bucket,'')) in ('WAREHOUSE_GOOD','WAREHOUSE_ZERO_COST')
            then sa.qty
            when upper(coalesce(sa.movement_type,''))='CUSTOMER_BORROW_CLEAR'
              and upper(coalesce(sa.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST')
              and upper(coalesce(sa.to_bucket,''))='CUSTOMER_BORROW_RETURN'
            then sa.qty
            else 0 end)::numeric adjustment_out_qty
    from public.stock_activity sa
    left join public.products p on p.product_code=sa.product_code
    where sa.batch_id=p_batch_id and upper(coalesce(sa.movement_type,'')) in ('BATCH_EDIT','CUSTOMER_BORROW','CUSTOMER_BORROW_CLEAR')
      and sa.product_code is not null
    group by sa.movement_id,sa.product_code,p.product_name,p.unit,sa.product_name_snapshot,sa.unit_snapshot
    order by max(sa.created_at) desc,sa.movement_id desc
    limit 150
  ) h;
  select coalesce(jsonb_agg(jsonb_build_object(
    'productCode',d.product_code,
    'damageReturnQty',round(d.damage_return_qty,6),
    'productName',coalesce(p.product_name,i.product_name_snapshot,d.product_code),
    'unit',coalesce(p.unit,i.unit_snapshot,''),
    'assignedQty',coalesce(i.issued_qty,0),
    'soldQty',coalesce(i.sold_qty_snapshot,0),
    'damagedQty',coalesce(i.damaged_qty,0),
    'currentQty',greatest(coalesce(i.pending_qty_snapshot,0),0)
  ) order by d.product_code),'[]'::jsonb)
  into v_damage
  from (
    select a.product_code,sum(a.qty)::numeric as damage_return_qty
    from public.stock_activity a
    where a.batch_id=p_batch_id
      and upper(coalesce(a.movement_type,''))='STOCK_DAMAGE'
      and (
        (upper(coalesce(a.damage_source,''))='BATCH' and upper(coalesce(a.from_bucket,'')) in ('BATCH_PENDING','BATCH_ZERO_COST'))
        or (upper(coalesce(a.damage_source,''))='BATCH_RECEIPT' and upper(coalesce(a.from_bucket,''))='BATCH_DAMAGE_HELD')
      )
      and upper(coalesce(a.to_bucket,''))='DAMAGED'
    group by a.product_code
  ) d
  left join public.stock_batch_items i on i.batch_id=p_batch_id and i.product_code=d.product_code
  left join public.products p on p.product_code=d.product_code;
  select coalesce(jsonb_agg(jsonb_build_object(
   'productCode',t.product_code,
   'productName',coalesce(p.product_name,i.product_name_snapshot,t.product_code),
   'unit',coalesce(p.unit,i.unit_snapshot,''),
   'assignedQty',coalesce(i.issued_qty,0),
   'soldQty',coalesce(i.sold_qty_snapshot,0),
   'damagedQty',coalesce(i.damaged_qty,0),
   'currentQty',greatest(coalesce(i.pending_qty_snapshot,0),0),
   'currentDamageQty',t.pending_qty
  ) order by t.product_code),'[]'::jsonb)
  into v_pending_damage from (
   select product_code,sum(reported_qty-received_qty)::numeric pending_qty
   from public.bb_batch_damage_reports
   where batch_id=p_batch_id group by product_code
   having sum(reported_qty-received_qty)>0
  ) t
  left join public.stock_batch_items i on i.batch_id=p_batch_id and i.product_code=t.product_code
  left join public.products p on p.product_code=t.product_code;
  return jsonb_build_object('success',true,'batchId',p_batch_id,
    'items',v_payload,'history',v_history,
    'damageReturns',v_damage,'damagePending',v_pending_damage);
end;
$function$;
