-- BIG BROTHER Report Damage — one read-only, permission-scoped count request per page.
-- One report transaction is one unique request_id, irrespective of product lines.
-- Code Sync migration for Local Brain V5/V6; no business-data writes.
create or replace function public.bb_sales_support_batch_damage_report_counts(p_batch_ids text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_staff_id text;
  v_is_admin boolean;
  v_counts jsonb;
begin
  if not public.bb_is_active_user() then
    raise exception 'Active BIG BROTHER user required';
  end if;
  v_is_admin := public.bb_is_admin();
  if not v_is_admin and not public.bb_has_module_access('route.sales-support-your-stock','view') then
    raise exception 'Your Stock access denied';
  end if;
  if coalesce(array_length(p_batch_ids, 1),0) > 500 then
    raise exception 'Too many batch IDs';
  end if;
  select staff_id into v_staff_id
  from public.app_users
  where user_id = auth.uid() and active = true
  limit 1;

  select coalesce(jsonb_object_agg(x.batch_id, x.reported_count),'{}'::jsonb)
    into v_counts
  from (
    select b.batch_id,
           count(distinct r.request_id)::integer as reported_count
    from public.stock_batches b
    left join public.bb_batch_damage_reports r
      on r.batch_id = b.batch_id
    where b.batch_id = any(coalesce(p_batch_ids, array[]::text[]))
      and (v_is_admin or b.salesman_staff_id = v_staff_id)
    group by b.batch_id
  ) x;
  return v_counts;
end;
$function$;

revoke all on function public.bb_sales_support_batch_damage_report_counts(text[]) from public, anon;
grant execute on function public.bb_sales_support_batch_damage_report_counts(text[]) to authenticated;
