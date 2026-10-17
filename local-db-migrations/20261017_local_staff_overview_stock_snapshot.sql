-- BIG BROTHER — Local PC Staff Overview stock snapshot correction
-- Based on the 2026-10-17 read-only Local inspection.
-- SR-01 batches: BAT-000021=1, BAT-000032=247, BAT-000037=477 (total 725).
-- No business row changes. Preserve all existing permission/sales/A-R/month logic.
DO $bb_local_stock_guard$
BEGIN
  IF to_regprocedure('public.bb_mobile_overview_filtered(integer,integer,text)') IS NULL
     OR to_regclass('public.stock_batch_items') IS NULL
     OR to_regclass('public.stock_batches') IS NULL
     OR to_regclass('public.app_user_location_access') IS NULL THEN
    RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: required function or tables missing';
  END IF;
  IF position('left join public.stock_activity sa' IN pg_get_functiondef('public.bb_mobile_overview_filtered(integer,integer,text)'::regprocedure))=0
     OR position('batch_product as (' IN pg_get_functiondef('public.bb_mobile_overview_filtered(integer,integer,text)'::regprocedure))=0
     OR position('bp.purchased_pending+bp.zero_cost_pending' IN pg_get_functiondef('public.bb_mobile_overview_filtered(integer,integer,text)'::regprocedure))=0
     OR position('public.app_user_location_access' IN pg_get_functiondef('public.bb_mobile_overview_filtered(integer,integer,text)'::regprocedure))=0 THEN
    RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: old Local stock formula differs from inspected version';
  END IF;
END
$bb_local_stock_guard$;

CREATE OR REPLACE FUNCTION public.bb_mobile_overview_filtered(p_year integer, p_month integer, p_location_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user public.app_users%rowtype;
  v_locations jsonb := '[]'::jsonb;
  v_selected_location text := nullif(trim(coalesce(p_location_code,'')),'');
  v_start date;
  v_end date;

  v_sales_gross_usd numeric := 0;
  v_sales_return_usd numeric := 0;
  v_sales_net_usd numeric := 0;
  v_sales_invoice_count integer := 0;
  v_sales_location_count integer := 0;

  v_ar_usd numeric := 0;
  v_ar_khr numeric := 0;
  v_ar_equiv_usd numeric := 0;
  v_ar_count integer := 0;

  v_stock_value_usd numeric := 0;
  v_stock_purchased_qty numeric := 0;
  v_stock_zero_cost_qty numeric := 0;
  v_stock_physical_qty numeric := 0;
  v_open_batch_count integer := 0;

  v_pending_staff integer := 0;
begin
  if not public.bb_is_active_user() then
    raise exception 'Active BIG BROTHER user required';
  end if;

  select *
  into v_user
  from public.app_users
  where user_id=auth.uid()
    and active=true;

  if not found then
    raise exception 'BIG BROTHER access denied';
  end if;

  if p_year is null or p_year < 2000 or p_year > 2100
     or p_month is null or p_month < 1 or p_month > 12 then
    raise exception 'Invalid overview month';
  end if;

  if upper(coalesce(v_selected_location,''))='ALL' then
    v_selected_location:=null;
  end if;

  if v_selected_location is not null then
    if not exists(
      select 1
      from public.app_user_location_access ula
      join public.locations l
        on lower(l.location_code)=lower(ula.location_code)
      where ula.user_id=v_user.user_id
        and lower(ula.location_code)=lower(v_selected_location)
        and coalesce(l.active,true)=true
    ) then
      raise exception 'Selected Location is not assigned to this user';
    end if;

    select l.location_code
    into v_selected_location
    from public.locations l
    where lower(l.location_code)=lower(v_selected_location)
    limit 1;
  end if;

  v_start:=make_date(p_year,p_month,1);
  v_end:=(v_start+interval '1 month')::date;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'locationCode',l.location_code,
        'locationName',coalesce(l.location_name,l.location_code)
      )
      order by l.location_code
    ),
    '[]'::jsonb
  )
  into v_locations
  from public.app_user_location_access ula
  join public.locations l
    on lower(l.location_code)=lower(ula.location_code)
  where ula.user_id=v_user.user_id
    and coalesce(l.active,true)=true;

  -- Monthly Sales: selected month + selected assigned location (or all assigned).
  select
    coalesce(sum(
      case
        when upper(coalesce(i.currency,'USD'))='KHR'
          then coalesce(i.grand_total,0)/nullif(i.exchange_rate,0)
        else coalesce(i.grand_total,0)
      end
    ),0),
    count(*),
    count(distinct i.location_code)
  into
    v_sales_gross_usd,
    v_sales_invoice_count,
    v_sales_location_count
  from public.invoices i
  where i.invoice_date>=v_start
    and i.invoice_date<v_end
    and upper(trim(coalesce(i.status,''))) not in ('VOID','CANCELLED','CANCELED','REVERSED')
    and exists(
      select 1
      from public.app_user_location_access ula
      where ula.user_id=v_user.user_id
        and lower(ula.location_code)=lower(i.location_code)
    )
    and (
      v_selected_location is null
      or lower(i.location_code)=lower(v_selected_location)
    );

  select coalesce(sum(
    case
      when upper(coalesce(i.currency,'USD'))='KHR'
        then coalesce(sr.return_amount,0)/nullif(i.exchange_rate,0)
      else coalesce(sr.return_amount,0)
    end
  ),0)
  into v_sales_return_usd
  from public.sales_returns sr
  join public.invoices i
    on i.invoice_id=sr.invoice_id
  where sr.return_date>=v_start
    and sr.return_date<v_end
    and exists(
      select 1
      from public.app_user_location_access ula
      where ula.user_id=v_user.user_id
        and lower(ula.location_code)=lower(coalesce(sr.location_code,i.location_code))
    )
    and (
      v_selected_location is null
      or lower(coalesce(sr.location_code,i.location_code))=lower(v_selected_location)
    );

  v_sales_net_usd:=v_sales_gross_usd-v_sales_return_usd;

  -- Receivable remains a live snapshot across ALL assigned locations.
  select
    coalesce(sum(ar.outstanding) filter(
      where upper(coalesce(ar.currency,'USD'))='USD'
    ),0),
    coalesce(sum(ar.outstanding) filter(
      where upper(coalesce(ar.currency,'USD'))='KHR'
    ),0),
    coalesce(sum(
      case
        when upper(coalesce(ar.currency,'USD'))='KHR'
          then ar.outstanding/nullif(ar.exchange_rate,0)
        else ar.outstanding
      end
    ),0),
    count(*)
  into
    v_ar_usd,
    v_ar_khr,
    v_ar_equiv_usd,
    v_ar_count
  from public.v_accounts_receivable ar
  where coalesce(ar.outstanding,0)>0
    and exists(
      select 1
      from public.app_user_location_access ula
      where ula.user_id=v_user.user_id
        and lower(ula.location_code)=lower(ar.location_code)
    );

  -- Stock remains a live snapshot across ALL assigned locations.
  select count(*)
  into v_open_batch_count
  from public.stock_batches b
  where upper(coalesce(b.status,'OPEN')) not in ('CLOSED','CANCELLED','CANCELED')
    and exists(
      select 1
      from public.app_user_location_access ula
      where ula.user_id=v_user.user_id
        and lower(ula.location_code)=lower(b.location_code)
    );

  -- Reconciled batch item snapshots reflect cross-batch transfers.
  with assigned_batches as (
    select b.batch_id
    from public.stock_batches b
    where upper(coalesce(b.status,'OPEN')) not in ('CLOSED','CANCELLED','CANCELED')
      and exists (
        select 1 from public.app_user_location_access ula
        where ula.user_id=v_user.user_id
          and lower(ula.location_code)=lower(b.location_code)
      )
  )
  select
    coalesce(sum(coalesce(bi.purchased_pending_qty_snapshot,0)
      * public.bb_stock_average_cost_internal(bi.product_code)),0),
    coalesce(sum(bi.purchased_pending_qty_snapshot),0),
    coalesce(sum(bi.zero_cost_pending_qty_snapshot),0),
    coalesce(sum(bi.pending_qty_snapshot),0)
  into
    v_stock_value_usd,
    v_stock_purchased_qty,
    v_stock_zero_cost_qty,
    v_stock_physical_qty
  from assigned_batches ab
  join public.stock_batch_items bi on bi.batch_id=ab.batch_id;

  if lower(coalesce(v_user.role,''))='admin' then
    select
        (select count(*) from public.staff_payment_requests r
         where upper(trim(coalesce(r.status,''))) in ('REQUESTED','PENDING','SUBMITTED'))
      + (select count(*) from public.staff_leave_requests r
         where upper(trim(coalesce(r.status,''))) in ('REQUESTED','PENDING','SUBMITTED'))
      + (select count(*) from public.staff_salary_advance_requests r
         where upper(trim(coalesce(r.status,''))) in ('REQUESTED','PENDING','SUBMITTED'))
    into v_pending_staff;
  end if;

  return jsonb_build_object(
    'success',true,
    'version','MOBILE-OVERVIEW-FILTERED-V2',
    'generatedAt',to_char(clock_timestamp() at time zone 'Asia/Phnom_Penh','YYYY-MM-DD HH24:MI:SS'),
    'year',p_year,
    'month',p_month,
    'periodLabel',to_char(v_start,'FMMonth YYYY'),
    'selectedLocationCode',coalesce(v_selected_location,''),
    'saleLocations',v_locations,
    'saleLocationCount',jsonb_array_length(v_locations),
    'monthlySales',jsonb_build_object(
      'grossUSD',round(v_sales_gross_usd,2),
      'returnsUSD',round(v_sales_return_usd,2),
      'netUSD',round(v_sales_net_usd,2),
      'invoiceCount',v_sales_invoice_count,
      'activeLocationCount',v_sales_location_count
    ),
    'receivable',jsonb_build_object(
      'USD',round(v_ar_usd,2),
      'KHR',round(v_ar_khr,0),
      'equivalentUSD',round(v_ar_equiv_usd,2),
      'count',v_ar_count
    ),
    'stock',jsonb_build_object(
      'valueUSD',round(v_stock_value_usd,2),
      'purchasedQty',round(v_stock_purchased_qty,6),
      'zeroCostQty',round(v_stock_zero_cost_qty,6),
      'physicalQty',round(v_stock_physical_qty,6),
      'openBatchCount',v_open_batch_count
    ),
    'pendingStaffRequests',v_pending_staff
  );
end;
$function$;
