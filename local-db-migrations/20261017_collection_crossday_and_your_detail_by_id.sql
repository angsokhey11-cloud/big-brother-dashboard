-- BIG BROTHER 2026-10-17: cross-day close requests + exact Invoice ID detail in Your Collection.
-- No invoice/payment/close data mutation. Keep location, salesman, amount, duplicate and cash-match checks.
DO $bb_collection_guard$
BEGIN
  IF to_regprocedure('public.bb_dcc_create_request(jsonb)') IS NULL
     OR to_regprocedure('public.bb_dcc_mobile_create_request(jsonb)') IS NULL
     OR to_regprocedure('public.bb_sales_support_your_collection_create_request(jsonb)') IS NULL
     OR to_regprocedure('public.bb_dcc_invoice_detail_by_id(text)') IS NULL THEN
    RAISE EXCEPTION 'CASH CLOSE SAFE STOP: existing function dependency is missing';
  END IF;
  IF position('daily_cash_close_invoices' IN pg_get_functiondef('public.bb_dcc_create_request(jsonb)'::regprocedure))=0
     OR position('daily_cash_close_invoices' IN pg_get_functiondef('public.bb_dcc_mobile_create_request(jsonb)'::regprocedure))=0
     OR position('private.bb_is_current_permanent_salesman' IN pg_get_functiondef('public.bb_sales_support_your_collection_create_request(jsonb)'::regprocedure))=0
     OR position('invoice_lines' IN pg_get_functiondef('public.bb_dcc_invoice_detail_by_id(text)'::regprocedure))=0 THEN
    RAISE EXCEPTION 'CASH CLOSE SAFE STOP: Local cash collection safeguards differ from reviewed version';
  END IF;
END $bb_collection_guard$;

CREATE OR REPLACE FUNCTION public.bb_dcc_create_request(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ids text[];
  v_count integer;
  v_expected numeric:=0;
  v_actual_usd numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'actualCashUSD','')),'')::numeric,0),0);
  v_actual_khr numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'actualCashKHR','')),'')::numeric,0),0);
  v_closing_rate numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'closingRate','')),'')::numeric,0),0);
  v_actual_equiv numeric:=0;
  v_diff numeric:=0;
  v_method text:=trim(coalesce(p_payload->>'closeMethod','Hand Cash to Accountant'));
  v_bank text:=nullif(trim(coalesce(p_payload->>'bankAccount','')),'');
  v_tx text:=nullif(trim(coalesce(p_payload->>'transactionId','')),'');
  v_deposit_rate numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'depositRate','')),'')::numeric,0),0);
  v_bank_usd numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'bankDepositUSD','')),'')::numeric,0),0);
  v_expected_bank numeric:=0;
  v_bank_diff numeric:=0;
  v_close_id text;
  v_staff_id text;
  v_user_name text;
  v_sale_date date;
  v_location text;
  v_sales_staff text;
  v_sales_name text;
  v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
  r record;
begin
  if not public.bb_has_module_access('daily_cash_collection','create') then
    raise exception 'Daily Cash Collection create access denied';
  end if;

  select array_agg(distinct trim(value))
  into v_ids
  from jsonb_array_elements_text(coalesce(p_payload->'invoiceIds','[]'::jsonb))
  where nullif(trim(value),'') is not null;

  if coalesce(array_length(v_ids,1),0)=0 then raise exception 'Select at least one Cash transaction'; end if;

  with cp as (
    select p.invoice_id,min(p.payment_date) cash_date
    from public.payments p
    where p.invoice_id=any(v_ids)
      and lower(trim(coalesce(p.payment_method,'')))='cash'
      and lower(trim(coalesce(p.payment_source,'')))='invoice'
      and coalesce(p.amount,0)>0
      and upper(coalesce(p.currency,'USD')) in ('USD','KHR')
    group by p.invoice_id
  )
  select count(*),min(cp.cash_date),min(coalesce(i.location_code,'')),
         min(coalesce(i.salesperson_staff_id,'')),min(coalesce(i.salesperson_name_snapshot,''))
  into v_count,v_sale_date,v_location,v_sales_staff,v_sales_name
  from cp
  join public.invoices i on i.invoice_id=cp.invoice_id;

  if v_count<>array_length(v_ids,1) then
    raise exception 'One or more selected records do not contain an initial Cash payment';
  end if;

  if exists(
    select 1
    from public.invoices i
    where i.invoice_id=any(v_ids)
      and not public.bb_has_location_access(coalesce(i.location_code,''))
  ) then
    raise exception 'One or more invoice locations are not allowed for this user';
  end if;

  if (select count(distinct coalesce(i.location_code,'')) from public.invoices i where i.invoice_id=any(v_ids))<>1
  or (select count(distinct coalesce(i.salesperson_staff_id,'')) from public.invoices i where i.invoice_id=any(v_ids))<>1 then
    raise exception 'Selected Cash transactions must have the same Location and Salesperson';
  end if;

  if exists(
    select 1
    from public.daily_cash_close_invoices ci
    join public.daily_cash_closes c on c.close_id=ci.close_id
    where ci.invoice_id=any(v_ids)
      and lower(coalesce(c.status,'')) not in ('rejected','cancelled','canceled')
  ) or exists(
    select 1
    from public.daily_cash_request_invoices ri
    join public.daily_cash_requests rq on rq.request_id=ri.request_id
    where ri.invoice_id=any(v_ids)
      and lower(coalesce(rq.status,'')) not in ('rejected','cancelled','canceled')
  ) then
    raise exception 'One or more selected Cash transactions are already pending or closed';
  end if;

  for r in
    with cp as (
      select
        p.invoice_id,
        upper(coalesce(max(nullif(trim(p.currency),'')),'USD')) cash_currency,
        max(coalesce(p.exchange_rate,0)) cash_exchange_rate,
        sum(coalesce(p.amount,0)) cash_amount
      from public.payments p
      where p.invoice_id=any(v_ids)
        and lower(trim(coalesce(p.payment_method,'')))='cash'
        and lower(trim(coalesce(p.payment_source,'')))='invoice'
        and coalesce(p.amount,0)>0
        and upper(coalesce(p.currency,'USD')) in ('USD','KHR')
      group by p.invoice_id
    )
    select i.invoice_id,i.invoice_no,cp.cash_currency,cp.cash_exchange_rate,cp.cash_amount
    from cp
    join public.invoices i on i.invoice_id=cp.invoice_id
    order by i.invoice_no
    for update of i
  loop
    if r.cash_currency='KHR' then
      if coalesce(r.cash_exchange_rate,0)<=0 then
        raise exception 'Cash transaction for invoice % is missing Exchange Rate',r.invoice_no;
      end if;
      v_expected:=v_expected+(r.cash_amount/r.cash_exchange_rate);
    else
      v_expected:=v_expected+r.cash_amount;
    end if;
  end loop;

  if v_actual_khr>0 and v_closing_rate<=0 then raise exception 'Closing Exchange Rate is required'; end if;
  v_actual_equiv:=v_actual_usd+case when v_actual_khr>0 then v_actual_khr/v_closing_rate else 0 end;
  v_diff:=v_actual_equiv-v_expected;
  if abs(v_diff)>0.05 then raise exception 'Actual USD + KHR does not match selected Cash transaction value'; end if;

  if v_method not in ('Hand Cash to Accountant','Deposit to Company Bank') then raise exception 'Unsupported close method'; end if;
  if v_method='Deposit to Company Bank' then
    if v_bank is null or v_tx is null then raise exception 'Company Bank Account and Transaction ID are required'; end if;
    if exists(select 1 from public.daily_cash_closes where lower(trim(coalesce(bank_transaction_id,'')))=lower(v_tx)) then
      raise exception 'Transaction ID already exists';
    end if;
    if v_actual_khr>0 and v_deposit_rate<=0 then raise exception 'Deposit Exchange Rate is required'; end if;
    v_expected_bank:=v_actual_usd+case when v_actual_khr>0 then v_actual_khr/v_deposit_rate else 0 end;
    v_bank_diff:=v_bank_usd-v_expected_bank;
    if v_bank_usd<=0 or abs(v_bank_diff)>0.05 then
      raise exception 'Bank Deposit USD does not match collected cash at Deposit Exchange Rate';
    end if;
  end if;

  select au.staff_id,coalesce(s.staff_name,au.email)
  into v_staff_id,v_user_name
  from public.app_users au
  left join public.staff s on s.staff_id=au.staff_id
  where au.user_id=auth.uid() and au.active=true;

  v_close_id:=public.bb_next_prefixed_id('public.daily_cash_closes'::regclass,'close_id','DCC',6);

  insert into public.daily_cash_closes(
    close_id,close_date,requested_by_staff_id,requested_by_name_snapshot,requested_by_user_id,
    close_method,invoice_count,expected_usd,actual_cash_usd,actual_cash_khr,closing_exchange_rate,
    actual_equivalent_usd,difference_usd,company_bank_account,bank_transaction_id,deposit_exchange_rate,
    bank_deposit_usd,expected_bank_usd,bank_difference_usd,status,note
  ) values (
    v_close_id,now(),v_staff_id,v_user_name,auth.uid(),
    v_method,v_count,v_expected,v_actual_usd,v_actual_khr,v_closing_rate,
    v_actual_equiv,v_diff,case when v_method='Deposit to Company Bank' then v_bank else null end,
    case when v_method='Deposit to Company Bank' then v_tx else null end,
    case when v_method='Deposit to Company Bank' then v_deposit_rate else 0 end,
    case when v_method='Deposit to Company Bank' then v_bank_usd else 0 end,
    case when v_method='Deposit to Company Bank' then v_expected_bank else 0 end,
    case when v_method='Deposit to Company Bank' then v_bank_diff else 0 end,
    'Pending',v_note
  );

  insert into public.daily_cash_close_invoices(
    close_invoice_id,close_id,invoice_id,invoice_no_snapshot,invoice_date,customer_id,customer_name_snapshot,
    location_code,salesperson_staff_id,salesperson_name_snapshot,invoice_currency,invoice_exchange_rate,
    invoice_cash_amount,expected_usd
  )
  with cp as (
    select
      p.invoice_id,
      min(p.payment_date) cash_date,
      upper(coalesce(max(nullif(trim(p.currency),'')),'USD')) cash_currency,
      max(coalesce(p.exchange_rate,0)) cash_exchange_rate,
      sum(coalesce(p.amount,0)) cash_amount
    from public.payments p
    where p.invoice_id=any(v_ids)
      and lower(trim(coalesce(p.payment_method,'')))='cash'
      and lower(trim(coalesce(p.payment_source,'')))='invoice'
      and coalesce(p.amount,0)>0
      and upper(coalesce(p.currency,'USD')) in ('USD','KHR')
    group by p.invoice_id
  )
  select
    v_close_id||'-I'||lpad(row_number() over(order by i.invoice_no,i.invoice_id)::text,4,'0'),
    v_close_id,i.invoice_id,i.invoice_no,cp.cash_date,i.customer_id,i.customer_name_snapshot,
    i.location_code,i.salesperson_staff_id,i.salesperson_name_snapshot,cp.cash_currency,
    case when cp.cash_exchange_rate>0 then cp.cash_exchange_rate else i.exchange_rate end,
    cp.cash_amount,
    case when cp.cash_currency='KHR'
      then cp.cash_amount/nullif(case when cp.cash_exchange_rate>0 then cp.cash_exchange_rate else i.exchange_rate end,0)
      else cp.cash_amount
    end
  from cp
  join public.invoices i on i.invoice_id=cp.invoice_id;

  return jsonb_build_object(
    'success',true,
    'closeId',v_close_id,
    'requestId',v_close_id,
    'invoiceCount',v_count,
    'expectedUSD',v_expected,
    'actualEquivalentUSD',v_actual_equiv,
    'differenceUSD',v_diff,
    'status','Pending'
  );
end;
$function$

CREATE OR REPLACE FUNCTION public.bb_dcc_mobile_create_request(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ids text[];
  v_count integer;
  v_expected numeric:=0;
  v_actual_usd numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'actualCashUSD','')),'')::numeric,0),0);
  v_actual_khr numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'actualCashKHR','')),'')::numeric,0),0);
  v_closing_rate numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'closingRate','')),'')::numeric,0),0);
  v_actual_equiv numeric:=0;
  v_diff numeric:=0;
  v_method text:=trim(coalesce(p_payload->>'closeMethod','Hand Cash to Accountant'));
  v_bank text:=nullif(trim(coalesce(p_payload->>'bankAccount','')),'');
  v_tx text:=nullif(trim(coalesce(p_payload->>'transactionId','')),'');
  v_deposit_rate numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'depositRate','')),'')::numeric,0),0);
  v_bank_usd numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'bankDepositUSD','')),'')::numeric,0),0);
  v_expected_bank numeric:=0;
  v_bank_diff numeric:=0;
  v_close_id text;
  v_staff_id text;
  v_user_name text;
  v_sale_date date;
  v_location text;
  v_sales_staff text;
  v_sales_name text;
  v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
  r record;
begin
  if not public.bb_dcc_mobile_has_access('create') then
    raise exception 'Daily Cash Collection create access denied';
  end if;

  select array_agg(distinct trim(value))
  into v_ids
  from jsonb_array_elements_text(coalesce(p_payload->'invoiceIds','[]'::jsonb))
  where nullif(trim(value),'') is not null;

  if coalesce(array_length(v_ids,1),0)=0 then raise exception 'Select at least one Cash invoice'; end if;

  select count(*),min(i.invoice_date),min(coalesce(i.location_code,'')),min(coalesce(i.salesperson_staff_id,'')),min(coalesce(i.salesperson_name_snapshot,''))
  into v_count,v_sale_date,v_location,v_sales_staff,v_sales_name
  from public.invoices i
  where i.invoice_id=any(v_ids);

  if v_count<>array_length(v_ids,1) then raise exception 'One or more selected invoices were not found'; end if;

  if exists(
    select 1 from public.invoices i
    where i.invoice_id=any(v_ids)
      and (lower(trim(coalesce(i.payment_method,'')))<>'cash' or coalesce(i.amount_paid,0)<=0 or upper(coalesce(i.currency,'USD')) not in ('USD','KHR'))
  ) then raise exception 'Daily Cash can contain only paid Cash invoices'; end if;

  if (select count(distinct coalesce(i.location_code,'')) from public.invoices i where i.invoice_id=any(v_ids))<>1
     or (select count(distinct coalesce(i.salesperson_staff_id,'')) from public.invoices i where i.invoice_id=any(v_ids))<>1 then
    raise exception 'Selected invoices must have the same Location and Salesperson';
  end if;

  if exists(
    select 1
    from public.daily_cash_close_invoices ci
    join public.daily_cash_closes c on c.close_id=ci.close_id
    where ci.invoice_id=any(v_ids)
      and lower(coalesce(c.status,'')) not in ('rejected','cancelled','canceled')
  ) or exists(
    select 1
    from public.daily_cash_request_invoices ri
    join public.daily_cash_requests rq on rq.request_id=ri.request_id
    where ri.invoice_id=any(v_ids)
      and lower(coalesce(rq.status,'')) not in ('rejected','cancelled','canceled')
  ) then raise exception 'One or more selected invoices are already pending or closed'; end if;

  for r in
    select i.* from public.invoices i where i.invoice_id=any(v_ids) order by i.invoice_no for update
  loop
    if upper(coalesce(r.currency,'USD'))='KHR' then
      if coalesce(r.exchange_rate,0)<=0 then raise exception 'Invoice % is missing Exchange Rate',r.invoice_no; end if;
      v_expected:=v_expected+(r.amount_paid/r.exchange_rate);
    else
      v_expected:=v_expected+r.amount_paid;
    end if;
  end loop;

  if v_actual_khr>0 and v_closing_rate<=0 then raise exception 'Closing Exchange Rate is required'; end if;
  v_actual_equiv:=v_actual_usd+case when v_actual_khr>0 then v_actual_khr/v_closing_rate else 0 end;
  v_diff:=v_actual_equiv-v_expected;
  if abs(v_diff)>0.05 then raise exception 'Actual USD + KHR does not match selected invoice value'; end if;

  if v_method not in ('Hand Cash to Accountant','Deposit to Company Bank') then raise exception 'Unsupported close method'; end if;
  if v_method='Deposit to Company Bank' then
    if v_bank is null or v_tx is null then raise exception 'Company Bank Account and Transaction ID are required'; end if;
    if exists(select 1 from public.daily_cash_closes where lower(trim(coalesce(bank_transaction_id,'')))=lower(v_tx)) then raise exception 'Transaction ID already exists'; end if;
    if v_actual_khr>0 and v_deposit_rate<=0 then raise exception 'Deposit Exchange Rate is required'; end if;
    v_expected_bank:=v_actual_usd+case when v_actual_khr>0 then v_actual_khr/v_deposit_rate else 0 end;
    v_bank_diff:=v_bank_usd-v_expected_bank;
    if v_bank_usd<=0 or abs(v_bank_diff)>0.05 then raise exception 'Bank Deposit USD does not match collected cash at Deposit Exchange Rate'; end if;
  end if;

  select au.staff_id,coalesce(s.staff_name,au.email)
  into v_staff_id,v_user_name
  from public.app_users au
  left join public.staff s on s.staff_id=au.staff_id
  where au.user_id=auth.uid() and au.active=true;

  v_close_id:=public.bb_next_prefixed_id('public.daily_cash_closes'::regclass,'close_id','DCC',6);

  insert into public.daily_cash_closes(
    close_id,close_date,requested_by_staff_id,requested_by_name_snapshot,requested_by_user_id,
    close_method,invoice_count,expected_usd,actual_cash_usd,actual_cash_khr,closing_exchange_rate,
    actual_equivalent_usd,difference_usd,company_bank_account,bank_transaction_id,deposit_exchange_rate,
    bank_deposit_usd,expected_bank_usd,bank_difference_usd,status,note
  ) values (
    v_close_id,now(),v_staff_id,v_user_name,auth.uid(),
    v_method,v_count,v_expected,v_actual_usd,v_actual_khr,v_closing_rate,
    v_actual_equiv,v_diff,case when v_method='Deposit to Company Bank' then v_bank else null end,
    case when v_method='Deposit to Company Bank' then v_tx else null end,
    case when v_method='Deposit to Company Bank' then v_deposit_rate else 0 end,
    case when v_method='Deposit to Company Bank' then v_bank_usd else 0 end,
    case when v_method='Deposit to Company Bank' then v_expected_bank else 0 end,
    case when v_method='Deposit to Company Bank' then v_bank_diff else 0 end,
    'Pending',v_note
  );

  insert into public.daily_cash_close_invoices(
    close_invoice_id,close_id,invoice_id,invoice_no_snapshot,invoice_date,customer_id,customer_name_snapshot,
    location_code,salesperson_staff_id,salesperson_name_snapshot,invoice_currency,invoice_exchange_rate,
    invoice_cash_amount,expected_usd
  )
  select
    v_close_id||'-I'||lpad(row_number() over(order by i.invoice_no)::text,4,'0'),
    v_close_id,i.invoice_id,i.invoice_no,i.invoice_date,i.customer_id,i.customer_name_snapshot,
    i.location_code,i.salesperson_staff_id,i.salesperson_name_snapshot,i.currency,i.exchange_rate,
    i.amount_paid,
    case when upper(coalesce(i.currency,'USD'))='KHR' then i.amount_paid/i.exchange_rate else i.amount_paid end
  from public.invoices i
  where i.invoice_id=any(v_ids);

  return jsonb_build_object(
    'success',true,
    'closeId',v_close_id,
    'requestId',v_close_id,
    'invoiceCount',v_count,
    'expectedUSD',v_expected,
    'actualEquivalentUSD',v_actual_equiv,
    'differenceUSD',v_diff,
    'status','Pending'
  );
end;
$function$

CREATE OR REPLACE FUNCTION public.bb_sales_support_your_collection_create_request(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ids text[];
  v_count integer;
  v_expected numeric:=0;
  v_actual_usd numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'actualCashUSD','')),'')::numeric,0),0);
  v_actual_khr numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'actualCashKHR','')),'')::numeric,0),0);
  v_closing_rate numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'closingRate','')),'')::numeric,0),0);
  v_actual_equiv numeric:=0;
  v_diff numeric:=0;
  v_method text:=trim(coalesce(p_payload->>'closeMethod','Hand Cash to Accountant'));
  v_bank text:=nullif(trim(coalesce(p_payload->>'bankAccount','')),'');
  v_tx text:=nullif(trim(coalesce(p_payload->>'transactionId','')),'');
  v_deposit_rate numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'depositRate','')),'')::numeric,0),0);
  v_bank_usd numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'bankDepositUSD','')),'')::numeric,0),0);
  v_expected_bank numeric:=0;
  v_bank_diff numeric:=0;
  v_close_id text;
  v_staff_id text;
  v_user_name text;
  v_sale_date date;
  v_location text;
  v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
  r record;
begin
  if not public.bb_is_active_user() then
    raise exception 'BIG BROTHER access denied';
  end if;

  if not public.bb_is_admin()
     and not public.bb_has_module_access('route.sales-support-your-collection','create') then
    raise exception 'Your Collection create access denied';
  end if;

  select au.staff_id,coalesce(s.staff_name,au.email)
  into v_staff_id,v_user_name
  from public.app_users au
  left join public.staff s on s.staff_id=au.staff_id
  where au.user_id=auth.uid()
    and au.active=true;

  if coalesce(trim(v_staff_id),'')='' then
    raise exception 'Staff profile is required for Your Collection';
  end if;

  select array_agg(distinct trim(value))
  into v_ids
  from jsonb_array_elements_text(coalesce(p_payload->'invoiceIds','[]'::jsonb))
  where nullif(trim(value),'') is not null;

  if coalesce(array_length(v_ids,1),0)=0 then
    raise exception 'Select at least one Cash invoice';
  end if;

  select
    count(*),
    min(i.invoice_date),
    min(coalesce(i.location_code,''))
  into
    v_count,
    v_sale_date,
    v_location
  from public.invoices i
  where i.invoice_id=any(v_ids);

  if v_count<>array_length(v_ids,1) then
    raise exception 'One or more selected invoices were not found';
  end if;

  if exists(
    select 1
    from public.invoices i
    where i.invoice_id=any(v_ids)
      and (
        lower(trim(coalesce(i.payment_method,'')))<>'cash'
        or coalesce(i.amount_paid,0)<=0
        or upper(coalesce(i.currency,'USD')) not in ('USD','KHR')
      )
  ) then
    raise exception 'Your Collection can contain only paid Cash invoices';
  end if;

  if exists(
    select 1
    from public.invoices i
    where i.invoice_id=any(v_ids)
      and not private.bb_is_current_permanent_salesman(coalesce(i.location_code,''))
  ) then
    raise exception 'One or more selected invoices are outside your current Permanent Salesman responsibility';
  end if;

  if (select count(distinct coalesce(i.location_code,''))
      from public.invoices i
      where i.invoice_id=any(v_ids))<>1 then
    raise exception 'Selected invoices must have the same Location';
  end if;

  if exists(
    select 1
    from public.daily_cash_close_invoices ci
    join public.daily_cash_closes c on c.close_id=ci.close_id
    where ci.invoice_id=any(v_ids)
      and lower(coalesce(c.status,'')) not in ('rejected','cancelled','canceled')
  ) or exists(
    select 1
    from public.daily_cash_request_invoices ri
    join public.daily_cash_requests rq on rq.request_id=ri.request_id
    where ri.invoice_id=any(v_ids)
      and lower(coalesce(rq.status,'')) not in ('rejected','cancelled','canceled')
  ) then
    raise exception 'One or more selected invoices are already pending or closed';
  end if;

  for r in
    select i.*
    from public.invoices i
    where i.invoice_id=any(v_ids)
    order by i.invoice_no
    for update
  loop
    if upper(coalesce(r.currency,'USD'))='KHR' then
      if coalesce(r.exchange_rate,0)<=0 then
        raise exception 'Invoice % is missing Exchange Rate',r.invoice_no;
      end if;
      v_expected:=v_expected+(r.amount_paid/r.exchange_rate);
    else
      v_expected:=v_expected+r.amount_paid;
    end if;
  end loop;

  if v_actual_khr>0 and v_closing_rate<=0 then
    raise exception 'Closing Exchange Rate is required';
  end if;

  v_actual_equiv:=v_actual_usd
    + case when v_actual_khr>0 then v_actual_khr/v_closing_rate else 0 end;

  v_diff:=v_actual_equiv-v_expected;

  if abs(v_diff)>0.05 then
    raise exception 'Actual USD + KHR does not match selected invoice value';
  end if;

  if v_method not in ('Hand Cash to Accountant','Deposit to Company Bank') then
    raise exception 'Unsupported close method';
  end if;

  if v_method='Deposit to Company Bank' then
    if v_bank is null or v_tx is null then
      raise exception 'Company Bank Account and Transaction ID are required';
    end if;

    if exists(
      select 1
      from public.daily_cash_closes
      where lower(trim(coalesce(bank_transaction_id,'')))=lower(v_tx)
    ) then
      raise exception 'Transaction ID already exists';
    end if;

    if v_actual_khr>0 and v_deposit_rate<=0 then
      raise exception 'Deposit Exchange Rate is required';
    end if;

    v_expected_bank:=v_actual_usd
      + case when v_actual_khr>0 then v_actual_khr/v_deposit_rate else 0 end;

    v_bank_diff:=v_bank_usd-v_expected_bank;

    if v_bank_usd<=0 or abs(v_bank_diff)>0.05 then
      raise exception 'Bank Deposit USD does not match collected cash at Deposit Exchange Rate';
    end if;
  end if;

  v_close_id:=public.bb_next_prefixed_id(
    'public.daily_cash_closes'::regclass,
    'close_id',
    'DCC',
    6
  );

  insert into public.daily_cash_closes(
    close_id,
    close_date,
    requested_by_staff_id,
    requested_by_name_snapshot,
    requested_by_user_id,
    close_method,
    invoice_count,
    expected_usd,
    actual_cash_usd,
    actual_cash_khr,
    closing_exchange_rate,
    actual_equivalent_usd,
    difference_usd,
    company_bank_account,
    bank_transaction_id,
    deposit_exchange_rate,
    bank_deposit_usd,
    expected_bank_usd,
    bank_difference_usd,
    status,
    note
  ) values (
    v_close_id,
    now(),
    v_staff_id,
    v_user_name,
    auth.uid(),
    v_method,
    v_count,
    v_expected,
    v_actual_usd,
    v_actual_khr,
    v_closing_rate,
    v_actual_equiv,
    v_diff,
    case when v_method='Deposit to Company Bank' then v_bank else null end,
    case when v_method='Deposit to Company Bank' then v_tx else null end,
    case when v_method='Deposit to Company Bank' then v_deposit_rate else 0 end,
    case when v_method='Deposit to Company Bank' then v_bank_usd else 0 end,
    case when v_method='Deposit to Company Bank' then v_expected_bank else 0 end,
    case when v_method='Deposit to Company Bank' then v_bank_diff else 0 end,
    'Pending',
    v_note
  );

  insert into public.daily_cash_close_invoices(
    close_invoice_id,
    close_id,
    invoice_id,
    invoice_no_snapshot,
    invoice_date,
    customer_id,
    customer_name_snapshot,
    location_code,
    salesperson_staff_id,
    salesperson_name_snapshot,
    invoice_currency,
    invoice_exchange_rate,
    invoice_cash_amount,
    expected_usd
  )
  select
    v_close_id||'-I'||lpad(row_number() over(order by i.invoice_no)::text,4,'0'),
    v_close_id,
    i.invoice_id,
    i.invoice_no,
    i.invoice_date,
    i.customer_id,
    i.customer_name_snapshot,
    i.location_code,
    i.salesperson_staff_id,
    i.salesperson_name_snapshot,
    i.currency,
    i.exchange_rate,
    i.amount_paid,
    case
      when upper(coalesce(i.currency,'USD'))='KHR'
        then i.amount_paid/i.exchange_rate
      else i.amount_paid
    end
  from public.invoices i
  where i.invoice_id=any(v_ids);

  return jsonb_build_object(
    'success',true,
    'closeId',v_close_id,
    'requestId',v_close_id,
    'invoiceCount',v_count,
    'expectedUSD',v_expected,
    'actualEquivalentUSD',v_actual_equiv,
    'differenceUSD',v_diff,
    'status','Pending'
  );
end;
$function$

CREATE OR REPLACE FUNCTION public.bb_sales_support_your_collection_invoice_detail_by_id(p_invoice_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_location text;
  v_invoice jsonb;
  v_items jsonb;
  v_payments jsonb;
  v_returns jsonb;
begin
  if not public.bb_is_active_user() then
    raise exception 'BIG BROTHER access denied';
  end if;
  if not public.bb_is_admin()
     and not public.bb_has_module_access('route.sales-support-your-collection','view') then
    raise exception 'Your Collection access denied';
  end if;
  if not exists (
    select 1 from public.app_users au
    where au.user_id=auth.uid() and au.active=true and nullif(trim(coalesce(au.staff_id,'')),'') is not null
  ) then
    raise exception 'Staff profile is required for Your Collection';
  end if;

  select coalesce(i.location_code,c.location_code,'')
  into v_location
  from public.invoices i
  left join public.customers c on c.customer_id=i.customer_id
  where i.invoice_id=trim(coalesce(p_invoice_id,''))
  limit 1;

  if not found then raise exception 'Invoice was not found'; end if;
  if not private.bb_is_current_permanent_salesman(v_location) then raise exception 'Invoice is outside your current Permanent Salesman responsibility'; end if;

  select jsonb_build_object(
    'invoiceId',i.invoice_id,'invoiceNo',i.invoice_no,'invoiceDate',i.invoice_date::text,
    'customerId',coalesce(i.customer_id,''),'customer',coalesce(i.customer_name_snapshot,''),
    'phone',coalesce(c.phone,''),'address',coalesce(c.address,''),
    'locationCode',coalesce(i.location_code,c.location_code,''),
    'salespersonStaffId',coalesce(i.salesperson_staff_id,''),'salesperson',coalesce(i.salesperson_name_snapshot,''),
    'paymentMethod',coalesce(i.payment_method,''),'currency',coalesce(i.currency,'USD'),
    'exchangeRate',coalesce(i.exchange_rate,1),'subtotal',coalesce(i.subtotal,0),'discount',coalesce(i.discount,0),
    'grandTotal',coalesce(i.grand_total,0),'amountPaid',coalesce(i.amount_paid,0),'change',coalesce(i.change_amount,0),
    'outstanding',coalesce(i.outstanding,0),'creditAmount',coalesce(i.credit_amount,0),'status',coalesce(i.status,''),
    'invoiceType',case when coalesce(i.outstanding,0)>0 then 'Credit' else 'Paid' end,
    'note',coalesce(i.note,''),'dueDate',coalesce(i.due_date::text,''),'bankPayment',coalesce(i.bank_payment,''),
    'bankReference',coalesce(i.bank_reference,''),'batchNumber',coalesce(i.batch_number,''),
    'shippingTo',coalesce(i.shipping_to_legacy,'')
  )
  into v_invoice
  from public.invoices i
  left join public.customers c on c.customer_id=i.customer_id
  where i.invoice_id=trim(coalesce(p_invoice_id,''))
  limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'lineId',il.line_id,'lineNo',il.line_no,'entryType',il.entry_type,
    'productCode',coalesce(il.display_product_code,il.product_code,il.product_group_code,''),
    'exactProductCode',coalesce(il.product_code,''),'productGroupCode',coalesce(il.product_group_code,''),
    'productName',coalesce(il.product_name_snapshot,''),'productBarcode',coalesce(il.product_barcode_snapshot,''),
    'barcode',coalesce(il.product_barcode_snapshot,''),'productNote',coalesce(il.product_note,''),
    'qty',coalesce(il.qty,0),'unit',coalesce(il.unit_snapshot,''),'price',coalesce(il.unit_price,0),
    'unitPrice',coalesce(il.unit_price,0),'total',coalesce(il.line_total,0),'amount',coalesce(il.line_total,0),
    'stockAllocation',il.stock_allocation_json
  ) order by il.line_no),'[]'::jsonb)
  into v_items
  from public.invoice_lines il
  where il.invoice_id=trim(coalesce(p_invoice_id,''));

  select coalesce(jsonb_agg(jsonb_build_object(
    'paymentId',p.payment_id,'paymentDate',coalesce(p.payment_date::text,''),'paymentMethod',coalesce(p.payment_method,''),
    'bankPayment',coalesce(p.bank_payment,''),'bankReference',coalesce(p.bank_reference,''),'currency',p.currency,
    'amount',p.amount,'note',coalesce(p.note,''),'transactionId',coalesce(p.transaction_id,''),
    'paymentSource',coalesce(p.payment_source,'')
  ) order by p.payment_date,p.payment_id),'[]'::jsonb)
  into v_payments
  from public.payments p
  where p.invoice_id=trim(coalesce(p_invoice_id,''));

  select coalesce(jsonb_agg(jsonb_build_object(
    'returnId',r.return_id,'returnDate',r.return_date::text,'productCode',coalesce(r.product_code,''),
    'productName',coalesce(r.product_name_snapshot,''),'qty',r.qty,'unitPrice',r.unit_price,
    'returnAmount',r.return_amount,'returnType',coalesce(r.return_type,''),'reason',coalesce(r.reason,''),
    'note',coalesce(r.note,'')
  ) order by r.return_date,r.return_id),'[]'::jsonb)
  into v_returns
  from public.sales_returns r
  where r.invoice_id=trim(coalesce(p_invoice_id,''));

  v_invoice:=v_invoice || jsonb_build_object('items',v_items,'payments',v_payments,'returns',v_returns);
  return jsonb_build_object('success',true,'revision',public.bb_sales_support_your_collection_revision(),'invoice',v_invoice);
end;
$function$

REVOKE ALL ON FUNCTION public.bb_sales_support_your_collection_invoice_detail_by_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bb_sales_support_your_collection_invoice_detail_by_id(text) TO authenticated;
