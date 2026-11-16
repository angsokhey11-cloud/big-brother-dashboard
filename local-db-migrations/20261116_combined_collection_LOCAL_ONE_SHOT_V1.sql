-- BIG BROTHER Local Brain V5/V6 | Combined Cash + Old A/R, PRECHECKED ONE-SHOT V1
-- SCHEMA/RPC ONLY. DOES NOT create Daily Cash requests, A/R requests, payments or vault entries.
-- This must run ONLY against a verified local Docker PostgreSQL instance.

-- Fail closed on missing local prerequisites. Do not use this SQL against Live/Cloud.
-- Run only inside the verified LOCAL Docker PostgreSQL container.
BEGIN;
SET LOCAL lock_timeout='12s';
SET LOCAL statement_timeout='120s';
DO $bb_local_preflight$
DECLARE
 v_missing text[];
BEGIN
 SELECT array_agg(item) INTO v_missing
 FROM unnest(ARRAY[
    'public.bb_is_active_user()',
    'public.bb_is_admin()',
    'public.bb_has_module_access(text,text)',
    'public.bb_dcc_mobile_has_access(text)',
    'private.bb_is_current_receivable_owner(text)',
    'public.bb_sales_support_your_collection_create_request(jsonb)',
    'public.bb_dcc_create_request(jsonb)',
    'public.bb_dcc_mobile_create_request(jsonb)',
    'public.bb_ar_create_request_v2(jsonb)'
 ]) item WHERE to_regprocedure(item) IS NULL;
 IF v_missing IS NOT NULL THEN
   RAISE EXCEPTION 'LOCAL COMBINED COLLECTION BLOCKED: missing RPC prerequisite(s): %',array_to_string(v_missing,', ');
 END IF;
 SELECT array_agg(item) INTO v_missing
 FROM unnest(ARRAY[
    'public.app_users',
    'public.invoices',
    'public.locations',
    'public.ar_payment_requests',
    'public.ar_request_allocations',
    'public.daily_cash_closes',
    'public.daily_cash_close_invoices',
    'public.payments'
 ]) item WHERE to_regclass(item) IS NULL;
 IF v_missing IS NOT NULL THEN
   RAISE EXCEPTION 'LOCAL COMBINED COLLECTION BLOCKED: missing table(s): %',array_to_string(v_missing,', ');
 END IF;
 IF (SELECT count(*) FROM information_schema.columns
     WHERE table_schema='public' AND table_name='invoices'
       AND column_name IN ('invoice_id','invoice_no','outstanding','location_code','customer_id',
       'customer_name_snapshot','invoice_date','salesperson_staff_id','exchange_rate','payment_method'))<>10 THEN
   RAISE EXCEPTION 'LOCAL COMBINED COLLECTION BLOCKED: invoices schema mismatch';
 END IF;
END $bb_local_preflight$;

-- BIG BROTHER LOCAL BRAIN - STAGED ONLY - combined Sales Cash + old A/R cash request, across Sales Support and Daily Cash Collection.
-- Requires existing local DCC desktop/mobile and A/R RPC dependencies before installation.
-- CLOUD LIVE, LOCAL BRAIN NOT APPLIED. Audit local schema before deployment.

-- SOURCE: sql/20261116_combined_sales_ar_cash_request_v1.sql
-- BIG BROTHER 16-Nov-2026: Sales Support combined cash handover without changing either approval workflow.
create table if not exists public.bb_salesman_combined_cash_submissions(
  request_id uuid primary key,
  actor_user_id uuid not null,
  actor_staff_id text not null,
  payload_fingerprint text not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.bb_salesman_combined_cash_submissions enable row level security;
revoke all on public.bb_salesman_combined_cash_submissions from public, anon, authenticated;

create or replace function public.bb_sales_support_ar_cash_candidates_v1()
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare v_rows jsonb;
begin
 if not public.bb_is_active_user() or
    not (public.bb_is_admin() or public.bb_has_module_access('accounts_receivable','create')) then
   raise exception 'Receivable request access required';
 end if;
 select coalesce(jsonb_agg(to_jsonb(z) order by z.invoice_date,z.invoice_no,z.invoice_id),'[]'::jsonb)
 into v_rows from (
   select i.invoice_id as "invoiceId",i.invoice_no as "invoiceNo",i.invoice_date as invoice_date,
     i.customer_id as "customerId",i.customer_name_snapshot as "customer",
     i.location_code as "locationCode",
     coalesce(l.location_name,i.location_code,'') as "locationName",
     i.salesperson_staff_id as "salespersonStaffId",
     i.salesperson_name_snapshot as "salesperson",
     upper(coalesce(i.currency,'USD')) as currency,
     i.exchange_rate as "exchangeRate",i.outstanding as outstanding,
     i.payment_method as "paymentMethod"
   from public.invoices i
   left join public.locations l on l.location_code=i.location_code
   where i.outstanding>0.000001
     and lower(trim(coalesce(i.payment_method,''))) in ('credit','partially paid in cash','partially paid in bank')
     and (public.bb_is_admin() or public.bb_has_module_access('route.ar-all','create')
          or private.bb_is_current_receivable_owner(coalesce(i.location_code,'')))
     and not exists(
       select 1 from public.ar_request_allocations a
       join public.ar_payment_requests r on r.request_id=a.request_id
       where a.invoice_id=i.invoice_id and lower(coalesce(r.status,''))='processing'
     )
   order by i.invoice_date,i.invoice_no,i.invoice_id
   limit 500
 ) z;
 return jsonb_build_object('success',true,'invoices',v_rows,'count',jsonb_array_length(v_rows),
   'note','Open receivable invoices not yet in Processing requests. No payment is registered by selection.');
end;
$$;
revoke all on function public.bb_sales_support_ar_cash_candidates_v1() from public,anon;
grant execute on function public.bb_sales_support_ar_cash_candidates_v1() to authenticated;

create or replace function public.bb_sales_support_combined_cash_request_v1(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
 v_request_id uuid;
 v_request_text text:=trim(coalesce(p_payload->>'requestId',''));
 v_actor uuid:=auth.uid();
 v_staff text;
 v_existing public.bb_salesman_combined_cash_submissions%rowtype;
 v_fingerprint text:=md5(p_payload::text);
 v_sales jsonb:=coalesce(p_payload->'sales','{}'::jsonb);
 v_sale_ids jsonb:=coalesce(v_sales->'invoiceIds','[]'::jsonb);
 v_ar jsonb:=coalesce(p_payload->'arEntries','[]'::jsonb);
 v_ar_entry jsonb;
 v_inv public.invoices%rowtype;
 v_invoice_id text;
 v_invoice_ids text[]:='{}'::text[];
 v_amount numeric;
 v_sale_count integer;
 v_ar_count integer;
 v_location text;
 v_expected_location text;
 v_full_usd text[]:='{}'::text[];
 v_full_khr text[]:='{}'::text[];
 v_partial jsonb:='[]'::jsonb;
 v_partial_item jsonb;
 v_result jsonb;
 v_sale_result jsonb:=null;
 v_ar_result jsonb;
 v_ar_results jsonb:='[]'::jsonb;
 v_total_usd numeric:=0;
 v_total_khr numeric:=0;
 v_report_date date:=(now() at time zone 'Asia/Phnom_Penh')::date;
 v_note text;
begin
 if v_actor is null or not public.bb_is_active_user() then raise exception 'Signed-in active BIG BROTHER staff required'; end if;
 if v_request_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 then raise exception 'Combined cash submission requires a valid unique request ID';end if;
 v_request_id:=v_request_text::uuid;
 if jsonb_typeof(v_sale_ids)<>'array' or jsonb_typeof(v_ar)<>'array' then raise exception 'Invalid combined cash list';end if;
 v_sale_count:=jsonb_array_length(v_sale_ids);
 v_ar_count:=jsonb_array_length(v_ar);
 if v_sale_count>150 or v_ar_count>40 or (v_sale_count=0 and v_ar_count=0)
 then raise exception 'Select at least one cash item (maximum 150 sales and 40 receivables)'; end if;
 if v_ar_count>0 and
   (not public.bb_has_module_access('accounts_receivable','create') and not public.bb_is_admin())
 then raise exception 'Accounts Receivable request access required';end if;
 select au.staff_id into v_staff from public.app_users au where au.user_id=v_actor and au.active=true;
 if coalesce(trim(v_staff),'')='' then raise exception 'Staff profile is required';end if;
 perform pg_advisory_xact_lock(hashtext('BB_COMBINED_CASH:'||v_request_text));
 select * into v_existing from public.bb_salesman_combined_cash_submissions where request_id=v_request_id;
 if found then
   if v_existing.actor_user_id<>v_actor or v_existing.payload_fingerprint<>v_fingerprint
   then raise exception 'This combined cash request ID was already used for different details';end if;
   return v_existing.result || jsonb_build_object('duplicate',true);
 end if;
 if v_sale_count>0 then
   select min(coalesce(i.location_code,'')) into v_location
   from public.invoices i
   where i.invoice_id in (select jsonb_array_elements_text(v_sale_ids));
   if v_location is null or v_location='' then raise exception 'Sale location missing';end if;
 end if;
 if v_ar_count>0 and coalesce(v_sales->>'closeMethod','Hand Cash to Accountant')<>'Hand Cash to Accountant' then
   raise exception 'Combined A/R cash handover must be handed to Accountant; use the separate deposit workflow for bank deposits';
 end if;
 for v_ar_entry in select value from jsonb_array_elements(v_ar) loop
   if jsonb_typeof(v_ar_entry)<>'object' then raise exception 'Invalid receivable cash item';end if;
   v_invoice_id:=trim(coalesce(v_ar_entry->>'invoiceId',''));
   if v_invoice_id='' or v_invoice_id=any(v_invoice_ids) then raise exception 'Missing or repeated receivable invoice';end if;
   v_invoice_ids:=array_append(v_invoice_ids,v_invoice_id);
   select * into v_inv from public.invoices where invoice_id=v_invoice_id for update;
   if not found or v_inv.outstanding<=0 or
     lower(trim(coalesce(v_inv.payment_method,''))) not in ('credit','partially paid in cash','partially paid in bank')
   then raise exception 'Receivable % is not outstanding',v_invoice_id;end if;
   if not public.bb_is_admin() and not public.bb_has_module_access('route.ar-all','create')
     and not private.bb_is_current_receivable_owner(v_inv.location_code)
   then raise exception 'Receivable responsibility access denied for %',v_inv.invoice_no;end if;
   if exists(select 1 from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_invoice_id and lower(coalesce(r.status,''))='processing')
   then raise exception 'Receivable invoice % already has a pending request',v_inv.invoice_no;end if;
   v_expected_location:=coalesce(v_inv.location_code,'');
   if v_location is null then v_location:=v_expected_location;end if;
   if v_location<>v_expected_location then raise exception 'Combined cash items must belong to one location';end if;
   if nullif(trim(coalesce(v_ar_entry->>'amount','')),'') is null
   then raise exception 'Collected receivable amount required for invoice %',v_inv.invoice_no;end if;
   v_amount:=(v_ar_entry->>'amount')::numeric;
   if v_amount<=0 or v_amount>v_inv.outstanding+0.000001 or v_amount<>round(v_amount,4)
   then raise exception 'Invalid collected receivable amount for invoice %',v_inv.invoice_no;end if;
   if upper(coalesce(v_inv.currency,'')) not in ('USD','KHR') then raise exception 'Invalid receivable currency';end if;
   if upper(v_inv.currency)='USD' then v_total_usd:=v_total_usd+v_amount;
   else v_total_khr:=v_total_khr+v_amount;end if;
   if abs(v_amount-v_inv.outstanding)<=0.000001 then
     if upper(v_inv.currency)='USD' then v_full_usd:=array_append(v_full_usd,v_invoice_id);
     else v_full_khr:=array_append(v_full_khr,v_invoice_id);end if;
   else
     v_partial:=v_partial||jsonb_build_array(jsonb_build_object(
       'invoiceId',v_invoice_id,'amount',v_amount,'currency',upper(v_inv.currency)));
   end if;
 end loop;
 v_note:='Sales Support combined CASH handover '||v_request_text||'. Cash receivables remain subject to A/R Admin review.';
 if v_sale_count>0 then
   v_sale_result:=public.bb_sales_support_your_collection_create_request(
      v_sales||jsonb_build_object('note',
        left(trim(concat_ws(' | ',nullif(v_sales->>'note',''),v_note)),1000))
   );
 end if;
 if array_length(v_full_usd,1)>0 then
   v_ar_result:=public.bb_ar_create_request_v2(jsonb_build_object('invoiceIds',to_jsonb(v_full_usd),
       'paymentDate',v_report_date,'requestType','Direct Request','note',v_note));
   v_ar_results:=v_ar_results||jsonb_build_array(v_ar_result);
 end if;
 if array_length(v_full_khr,1)>0 then
   v_ar_result:=public.bb_ar_create_request_v2(jsonb_build_object('invoiceIds',to_jsonb(v_full_khr),
       'paymentDate',v_report_date,'requestType','Direct Request','note',v_note));
   v_ar_results:=v_ar_results||jsonb_build_array(v_ar_result);
 end if;
 for v_partial_item in select value from jsonb_array_elements(v_partial) loop
   v_ar_result:=public.bb_ar_create_request_v2(jsonb_build_object(
       'invoiceId',v_partial_item->>'invoiceId','amount',(v_partial_item->>'amount')::numeric,
       'paymentDate',v_report_date,'requestType','Direct Request','note',v_note));
   v_ar_results:=v_ar_results||jsonb_build_array(v_ar_result);
 end loop;
 v_result:=jsonb_build_object('success',true,'requestId',v_request_text,
   'locationCode',v_location,'sales',v_sale_result,'receivables',v_ar_results,
   'salesInvoiceCount',v_sale_count,'arInvoiceCount',v_ar_count,
   'arAmountUSD',v_total_usd,'arAmountKHR',v_total_khr,
   'salesStatus',case when v_sale_count>0 then 'Pending' else 'Not requested' end,
   'receivableStatus',case when v_ar_count>0 then 'Processing' else 'Not requested' end,
   'message','Combined handover split into existing Daily Cash and A/R pending request workflows. No A/R payment, cash vault, or bank balance was created.');
 insert into public.bb_salesman_combined_cash_submissions(request_id,actor_user_id,actor_staff_id,payload_fingerprint,result)
 values(v_request_id,v_actor,v_staff,v_fingerprint,v_result);
 return v_result;
end;
$$;
revoke all on function public.bb_sales_support_combined_cash_request_v1(jsonb) from public,anon;
grant execute on function public.bb_sales_support_combined_cash_request_v1(jsonb) to authenticated;


-- SOURCE: sql/20261116_combined_ar_cash_candidate_alias_fix_v1.sql
CREATE OR REPLACE FUNCTION public.bb_sales_support_ar_cash_candidates_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rows jsonb;
begin
 if not public.bb_is_active_user() or
    not (public.bb_is_admin() or public.bb_has_module_access('accounts_receivable','create')) then
   raise exception 'Receivable request access required';
 end if;
 select coalesce(jsonb_agg(to_jsonb(z) order by z."invoiceDate",z."invoiceNo",z."invoiceId"),'[]'::jsonb)
 into v_rows from (
   select i.invoice_id as "invoiceId",i.invoice_no as "invoiceNo",i.invoice_date as "invoiceDate",
     i.customer_id as "customerId",i.customer_name_snapshot as "customer",
     i.location_code as "locationCode",
     coalesce(l.location_name,i.location_code,'') as "locationName",
     i.salesperson_staff_id as "salespersonStaffId",
     i.salesperson_name_snapshot as "salesperson",
     upper(coalesce(i.currency,'USD')) as currency,
     i.exchange_rate as "exchangeRate",i.outstanding as outstanding,
     i.payment_method as "paymentMethod"
   from public.invoices i
   left join public.locations l on l.location_code=i.location_code
   where i.outstanding>0.000001
     and lower(trim(coalesce(i.payment_method,''))) in ('credit','partially paid in cash','partially paid in bank')
     and (public.bb_is_admin() or public.bb_has_module_access('route.ar-all','create')
          or private.bb_is_current_receivable_owner(coalesce(i.location_code,'')))
     and not exists(
       select 1 from public.ar_request_allocations a
       join public.ar_payment_requests r on r.request_id=a.request_id
       where a.invoice_id=i.invoice_id and lower(coalesce(r.status,''))='processing'
     )
   order by i.invoice_date,i.invoice_no,i.invoice_id
   limit 500
 ) z;
 return jsonb_build_object('success',true,'invoices',v_rows,'count',jsonb_array_length(v_rows),
   'note','Open receivable invoices not yet in Processing requests. No payment is registered by selection.');
end;
$function$
;


-- SOURCE: sql/20261116_combined_ar_cash_candidate_limit_2500.sql
-- Combined Sales/AR picker: show current authorized receivables across all locations, up to safety limit.
CREATE OR REPLACE FUNCTION public.bb_sales_support_ar_cash_candidates_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rows jsonb;
begin
 if not public.bb_is_active_user() or
    not (public.bb_is_admin() or public.bb_has_module_access('accounts_receivable','create')) then
   raise exception 'Receivable request access required';
 end if;
 select coalesce(jsonb_agg(to_jsonb(z) order by z."invoiceDate",z."invoiceNo",z."invoiceId"),'[]'::jsonb)
 into v_rows from (
   select i.invoice_id as "invoiceId",i.invoice_no as "invoiceNo",i.invoice_date as "invoiceDate",
     i.customer_id as "customerId",i.customer_name_snapshot as "customer",
     i.location_code as "locationCode",
     coalesce(l.location_name,i.location_code,'') as "locationName",
     i.salesperson_staff_id as "salespersonStaffId",
     i.salesperson_name_snapshot as "salesperson",
     upper(coalesce(i.currency,'USD')) as currency,
     i.exchange_rate as "exchangeRate",i.outstanding as outstanding,
     i.payment_method as "paymentMethod"
   from public.invoices i
   left join public.locations l on l.location_code=i.location_code
   where i.outstanding>0.000001
     and lower(trim(coalesce(i.payment_method,''))) in ('credit','partially paid in cash','partially paid in bank')
     and (public.bb_is_admin() or public.bb_has_module_access('route.ar-all','create')
          or private.bb_is_current_receivable_owner(coalesce(i.location_code,'')))
     and not exists(
       select 1 from public.ar_request_allocations a
       join public.ar_payment_requests r on r.request_id=a.request_id
       where a.invoice_id=i.invoice_id and lower(coalesce(r.status,''))='processing'
     )
   order by i.invoice_date,i.invoice_no,i.invoice_id
   limit 2500
 ) z;
 return jsonb_build_object('success',true,'invoices',v_rows,'count',jsonb_array_length(v_rows),
   'note','Open receivable invoices not yet in Processing requests. No payment is registered by selection.');
end;
$function$
;


-- SOURCE: sql/20261116_daily_cash_collection_combined_ar_split_v1.sql
-- BIG BROTHER: Combined Daily Cash Collection + Old A/R Cash, preserve desktop/mobile original DCC engine.
-- All request creation stays atomic; no receipt, payment or Cash Vault writes are added.
CREATE OR REPLACE FUNCTION public.bb_dcc_combined_cash_request_v1(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_request_id uuid;
 v_request_text text:=trim(coalesce(p_payload->>'requestId',''));
 v_actor uuid:=auth.uid();
 v_staff text;
 v_mode text:=lower(trim(coalesce(p_payload->>'sourceMode','desktop')));
 v_existing public.bb_salesman_combined_cash_submissions%rowtype;
 v_fingerprint text:=md5(p_payload::text);
 v_sales jsonb:=coalesce(p_payload->'sales','{}'::jsonb);
 v_sale_ids jsonb:=coalesce(v_sales->'invoiceIds','[]'::jsonb);
 v_ar jsonb:=coalesce(p_payload->'arEntries','[]'::jsonb);
 v_ar_entry jsonb;
 v_inv public.invoices%rowtype;
 v_invoice_id text;
 v_invoice_ids text[]:='{}'::text[];
 v_amount numeric;
 v_sale_count integer;
 v_ar_count integer;
 v_location text;
 v_expected_location text;
 v_full_usd text[]:='{}'::text[];
 v_full_khr text[]:='{}'::text[];
 v_partial jsonb:='[]'::jsonb;
 v_partial_item jsonb;
 v_result jsonb;
 v_sale_result jsonb:=null;
 v_ar_result jsonb;
 v_ar_results jsonb:='[]'::jsonb;
 v_total_usd numeric:=0;
 v_total_khr numeric:=0;
 v_report_date date:=(now() at time zone 'Asia/Phnom_Penh')::date;
 v_note text;
begin
 if v_actor is null or not public.bb_is_active_user() then raise exception 'Signed-in active BIG BROTHER staff required'; end if;
 if v_request_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 then raise exception 'Combined cash submission requires a valid unique request ID';end if;
 v_request_id:=v_request_text::uuid;
 if jsonb_typeof(v_sale_ids)<>'array' or jsonb_typeof(v_ar)<>'array' then raise exception 'Invalid combined cash list';end if;
 v_sale_count:=jsonb_array_length(v_sale_ids);
 v_ar_count:=jsonb_array_length(v_ar);
 if v_sale_count>150 or v_ar_count>40 or (v_sale_count=0 and v_ar_count=0)
 then raise exception 'Select at least one cash item (maximum 150 sales and 40 receivables)'; end if;
 if v_mode not in ('desktop','mobile') then raise exception 'Invalid Daily Cash mode';end if;
 if v_sale_count>0 and ((v_mode='desktop' and not public.bb_has_module_access('daily_cash_collection','create'))
   or (v_mode='mobile' and not public.bb_dcc_mobile_has_access('create')))
 then raise exception 'Daily Cash Collection create access required';end if;
 if v_ar_count>0 and
   (not public.bb_has_module_access('accounts_receivable','create') and not public.bb_is_admin())
 then raise exception 'Accounts Receivable request access required';end if;
 select au.staff_id into v_staff from public.app_users au where au.user_id=v_actor and au.active=true;
 if coalesce(trim(v_staff),'')='' then raise exception 'Staff profile is required';end if;
 perform pg_advisory_xact_lock(hashtext('BB_COMBINED_CASH:'||v_request_text));
 select * into v_existing from public.bb_salesman_combined_cash_submissions where request_id=v_request_id;
 if found then
   if v_existing.actor_user_id<>v_actor or v_existing.payload_fingerprint<>v_fingerprint
   then raise exception 'This combined cash request ID was already used for different details';end if;
   return v_existing.result || jsonb_build_object('duplicate',true);
 end if;
 if v_sale_count>0 then
   select min(coalesce(i.location_code,'')) into v_location
   from public.invoices i
   where i.invoice_id in (select jsonb_array_elements_text(v_sale_ids));
   if v_location is null or v_location='' then raise exception 'Sale location missing';end if;
 end if;
 if v_ar_count>0 and coalesce(v_sales->>'closeMethod','Hand Cash to Accountant')<>'Hand Cash to Accountant' then
   raise exception 'Combined A/R cash handover must be handed to Accountant; use the separate deposit workflow for bank deposits';
 end if;
 for v_ar_entry in select value from jsonb_array_elements(v_ar) loop
   if jsonb_typeof(v_ar_entry)<>'object' then raise exception 'Invalid receivable cash item';end if;
   v_invoice_id:=trim(coalesce(v_ar_entry->>'invoiceId',''));
   if v_invoice_id='' or v_invoice_id=any(v_invoice_ids) then raise exception 'Missing or repeated receivable invoice';end if;
   v_invoice_ids:=array_append(v_invoice_ids,v_invoice_id);
   select * into v_inv from public.invoices where invoice_id=v_invoice_id for update;
   if not found or v_inv.outstanding<=0 or
     lower(trim(coalesce(v_inv.payment_method,''))) not in ('credit','partially paid in cash','partially paid in bank')
   then raise exception 'Receivable % is not outstanding',v_invoice_id;end if;
   if not public.bb_is_admin() and not public.bb_has_module_access('route.ar-all','create')
     and not private.bb_is_current_receivable_owner(v_inv.location_code)
   then raise exception 'Receivable responsibility access denied for %',v_inv.invoice_no;end if;
   if exists(select 1 from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_invoice_id and lower(coalesce(r.status,''))='processing')
   then raise exception 'Receivable invoice % already has a pending request',v_inv.invoice_no;end if;
   v_expected_location:=coalesce(v_inv.location_code,'');
   if v_location is null then v_location:=v_expected_location;end if;
   if v_location<>v_expected_location then raise exception 'Combined cash items must belong to one location';end if;
   if nullif(trim(coalesce(v_ar_entry->>'amount','')),'') is null
   then raise exception 'Collected receivable amount required for invoice %',v_inv.invoice_no;end if;
   v_amount:=(v_ar_entry->>'amount')::numeric;
   if v_amount<=0 or v_amount>v_inv.outstanding+0.000001 or v_amount<>round(v_amount,4)
   then raise exception 'Invalid collected receivable amount for invoice %',v_inv.invoice_no;end if;
   if upper(coalesce(v_inv.currency,'')) not in ('USD','KHR') then raise exception 'Invalid receivable currency';end if;
   if upper(v_inv.currency)='USD' then v_total_usd:=v_total_usd+v_amount;
   else v_total_khr:=v_total_khr+v_amount;end if;
   if abs(v_amount-v_inv.outstanding)<=0.000001 then
     if upper(v_inv.currency)='USD' then v_full_usd:=array_append(v_full_usd,v_invoice_id);
     else v_full_khr:=array_append(v_full_khr,v_invoice_id);end if;
   else
     v_partial:=v_partial||jsonb_build_array(jsonb_build_object(
       'invoiceId',v_invoice_id,'amount',v_amount,'currency',upper(v_inv.currency)));
   end if;
 end loop;
 v_note:='Daily Cash Collection combined CASH handover '||v_request_text||'. Cash receivables remain subject to A/R Admin review.';
 if v_sale_count>0 then
   if v_mode='mobile' then
     v_sale_result:=public.bb_dcc_mobile_create_request(
       v_sales||jsonb_build_object('note',left(trim(concat_ws(' | ',nullif(v_sales->>'note',''),v_note)),1000))
     );
   else
     v_sale_result:=public.bb_dcc_create_request(
       v_sales||jsonb_build_object('note',left(trim(concat_ws(' | ',nullif(v_sales->>'note',''),v_note)),1000))
     );
   end if;
 end if;
 if array_length(v_full_usd,1)>0 then
   v_ar_result:=public.bb_ar_create_request_v2(jsonb_build_object('invoiceIds',to_jsonb(v_full_usd),
       'paymentDate',v_report_date,'requestType','Direct Request','note',v_note));
   v_ar_results:=v_ar_results||jsonb_build_array(v_ar_result);
 end if;
 if array_length(v_full_khr,1)>0 then
   v_ar_result:=public.bb_ar_create_request_v2(jsonb_build_object('invoiceIds',to_jsonb(v_full_khr),
       'paymentDate',v_report_date,'requestType','Direct Request','note',v_note));
   v_ar_results:=v_ar_results||jsonb_build_array(v_ar_result);
 end if;
 for v_partial_item in select value from jsonb_array_elements(v_partial) loop
   v_ar_result:=public.bb_ar_create_request_v2(jsonb_build_object(
       'invoiceId',v_partial_item->>'invoiceId','amount',(v_partial_item->>'amount')::numeric,
       'paymentDate',v_report_date,'requestType','Direct Request','note',v_note));
   v_ar_results:=v_ar_results||jsonb_build_array(v_ar_result);
 end loop;
 v_result:=jsonb_build_object('success',true,'requestId',v_request_text,
   'locationCode',v_location,'sourceMode',v_mode,'sales',v_sale_result,'receivables',v_ar_results,
   'salesInvoiceCount',v_sale_count,'arInvoiceCount',v_ar_count,
   'arAmountUSD',v_total_usd,'arAmountKHR',v_total_khr,
   'salesStatus',case when v_sale_count>0 then 'Pending' else 'Not requested' end,
   'receivableStatus',case when v_ar_count>0 then 'Processing' else 'Not requested' end,
   'message','Combined handover split into existing Daily Cash and A/R pending request workflows. No A/R payment, cash vault, or bank balance was created.');
 insert into public.bb_salesman_combined_cash_submissions(request_id,actor_user_id,actor_staff_id,payload_fingerprint,result)
 values(v_request_id,v_actor,v_staff,v_fingerprint,v_result);
 return v_result;
end;
$function$
;
revoke all on function public.bb_dcc_combined_cash_request_v1(jsonb) from public,anon;
grant execute on function public.bb_dcc_combined_cash_request_v1(jsonb) to authenticated;


-- Deployment validation: no accounting rows created; only functions and idempotency table.
DO $bb_local_verify$
BEGIN
 IF to_regprocedure('public.bb_dcc_combined_cash_request_v1(jsonb)') IS NULL
    OR to_regprocedure('public.bb_sales_support_combined_cash_request_v1(jsonb)') IS NULL
    OR to_regprocedure('public.bb_sales_support_ar_cash_candidates_v1()') IS NULL
    OR to_regclass('public.bb_salesman_combined_cash_submissions') IS NULL THEN
   RAISE EXCEPTION 'LOCAL COMBINED COLLECTION BLOCKED: deployed routines missing';
 END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class
          WHERE oid='public.bb_salesman_combined_cash_submissions'::regclass) THEN
   RAISE EXCEPTION 'LOCAL COMBINED COLLECTION BLOCKED: idempotency RLS disabled';
 END IF;
END $bb_local_verify$;
COMMIT;
