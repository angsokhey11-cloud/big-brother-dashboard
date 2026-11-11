-- Maintain original Cash, staff request, manual Bank, and single-customer A/R behavior.
-- Delegate only registered Bank transactions spanning >1 customer to new, admin-guarded route.
CREATE OR REPLACE FUNCTION public.bb_ar_receive_batch_payment_v2(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ids text[]:=array[]::text[];
  v_id text;
  v_inv public.invoices%rowtype;
  v_first public.invoices%rowtype;
  v_count int:=0;
  v_total numeric:=0;
  v_idx int:=0;
  v_method text:=case when lower(trim(coalesce(p_payload->>'paymentMethod','cash')))='bank' then 'Bank' else 'Cash' end;
  v_bank text:=nullif(trim(coalesce(p_payload->>'bankPayment','')),'');
  v_tx text:=nullif(trim(coalesce(p_payload->>'transactionId','')),'');
  v_ref text:=nullif(trim(coalesce(p_payload->>'bankReference','')),'');
  v_cash_usd numeric:=greatest(coalesce(nullif(p_payload->>'physicalCashUSD','')::numeric,0),0);
  v_cash_khr numeric:=greatest(coalesce(nullif(p_payload->>'physicalCashKHR','')::numeric,0),0);
  v_rate_min numeric;
  v_rate_max numeric;
  v_rate numeric;
  v_actual numeric;
  v_payment_id text;
  v_actor text:=public.bb_actor_name();
  v_staff_id text:=public.bb_actor_staff_id();
  v_vault_id text;
  v_usd_eq numeric:=0;
  v_share numeric;
  v_invoice_list text;
  v_customer_count int:=0;
  v_salesperson_count int:=0;
begin
  if not public.bb_has_module_access('accounts_receivable','edit') then
    raise exception 'Accounts Receivable receive access denied';
  end if;

  if jsonb_typeof(p_payload->'invoiceIds')<>'array' then
    raise exception 'No invoices selected';
  end if;

  select coalesce(array_agg(value),array[]::text[]) into v_ids
  from jsonb_array_elements_text(p_payload->'invoiceIds');

  if coalesce(array_length(v_ids,1),0)=0 then
    raise exception 'No invoices selected';
  end if;

  foreach v_id in array v_ids loop
    select * into v_inv
    from public.invoices
    where invoice_id=trim(v_id)
    for update;

    if not found then raise exception 'Invoice record % was not found',v_id; end if;
    if v_inv.outstanding<=0 then raise exception 'Invoice % is already fully paid',v_inv.invoice_no; end if;
    if not public.bb_is_admin() and not public.bb_has_location_access(v_inv.location_code) then
      raise exception 'Location access denied for invoice %',v_inv.invoice_no;
    end if;

    if exists(
      select 1
      from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_inv.invoice_id
        and lower(coalesce(r.status,''))='processing'
    ) then
      raise exception 'Invoice % has a Processing request',v_inv.invoice_no;
    end if;

    if v_count=0 then
      v_first:=v_inv;
    else
      if upper(coalesce(v_inv.currency,'USD'))<>upper(coalesce(v_first.currency,'USD')) then
        raise exception 'Selected invoices must use one currency';
      end if;
    end if;

    v_count:=v_count+1;
    v_total:=v_total+v_inv.outstanding;
  end loop;

  select count(distinct coalesce(customer_id,'')),
         count(distinct coalesce(salesperson_staff_id,''))
    into v_customer_count,v_salesperson_count
  from public.invoices
  where invoice_id=any(v_ids);

  -- An Admin-registered receipt shared across multiple outlets must create
  -- separately customer-owned payments. Never use the legacy NULL-customer
  -- single payment, which bypasses per-outlet wallet allocation semantics.
  if v_method='Bank' and v_customer_count>1
     and exists(select 1 from public.bb_verified_bank_transactions b
       where upper(btrim(b.transaction_id))=upper(btrim(coalesce(v_tx,'')))) then
    return public.bb_ar_receive_batch_registered_outlets_v1(p_payload);
  end if;

  if v_method='Bank' then
    if v_bank is null then raise exception 'Bank Name is required'; end if;
    if v_tx is null then raise exception 'Transaction ID is required'; end if;
  else
    if v_cash_usd<=0 and v_cash_khr<=0 then
      raise exception 'Enter physical cash received';
    end if;

    select min(exchange_rate),max(exchange_rate)
    into v_rate_min,v_rate_max
    from public.invoices
    where invoice_id=any(v_ids);

    v_rate:=coalesce(v_rate_max,0);

    if upper(v_first.currency)='USD' then
      if v_cash_khr>0 and
         (v_rate<=0 or abs(coalesce(v_rate_max,0)-coalesce(v_rate_min,0))>0.000001) then
        raise exception 'Selected invoices must use one Exchange Rate when KHR cash is received';
      end if;
      v_actual:=v_cash_usd+case when v_cash_khr>0 then v_cash_khr/v_rate else 0 end;
      if abs(v_actual-v_total)>0.05 then
        raise exception 'Physical cash does not match selected outstanding total';
      end if;
    else
      if v_cash_usd>0 and
         (v_rate<=0 or abs(coalesce(v_rate_max,0)-coalesce(v_rate_min,0))>0.000001) then
        raise exception 'Selected invoices must use one Exchange Rate when USD cash is received';
      end if;
      v_actual:=v_cash_khr+case when v_cash_usd>0 then v_cash_usd*v_rate else 0 end;
      if abs(v_actual-v_total)>1 then
        raise exception 'Physical cash does not match selected outstanding total';
      end if;
    end if;
  end if;

  select string_agg(invoice_no,', ' order by invoice_date,invoice_no)
  into v_invoice_list
  from public.invoices
  where invoice_id=any(v_ids);

  v_payment_id:=public.bb_next_prefixed_id(
    'public.payments'::regclass,'payment_id','PAY',4
  );

  insert into public.payments(
    payment_id,invoice_id,invoice_no_snapshot,payment_date,customer_id,
    customer_name_snapshot,location_code,salesperson_staff_id,
    salesperson_name_snapshot,payment_method,bank_payment,bank_reference,
    currency,exchange_rate,amount,physical_cash_usd,physical_cash_khr,
    note,transaction_id,entered_by_staff_id,entered_by_name_snapshot,
    approved_by_name_snapshot,payment_source,entered_by_user_id,approved_by_user_id
  ) values (
    v_payment_id,null,v_invoice_list,
    coalesce(nullif(p_payload->>'paymentDate','')::date,current_date),
    case when v_customer_count=1 then v_first.customer_id else null end,
    case when v_customer_count=1 then v_first.customer_name_snapshot else 'Multiple Customers' end,
    null,
    case when v_salesperson_count=1 then v_first.salesperson_staff_id else null end,
    case when v_salesperson_count=1 then v_first.salesperson_name_snapshot else 'Multiple Salespeople' end,
    v_method,case when v_method='Bank' then v_bank else null end,
    case when v_method='Bank' then v_ref else null end,
    v_first.currency,coalesce(v_first.exchange_rate,1),v_total,
    case when v_method='Cash' then v_cash_usd else 0 end,
    case when v_method='Cash' then v_cash_khr else 0 end,
    nullif(trim(coalesce(p_payload->>'note','')),''),
    case when v_method='Bank' then v_tx else null end,
    v_staff_id,v_actor,v_actor,'Receivable',auth.uid(),auth.uid()
  );

  foreach v_id in array v_ids loop
    select * into v_inv
    from public.invoices
    where invoice_id=trim(v_id);

    v_idx:=v_idx+1;

    insert into public.payment_allocations(
      allocation_id,payment_id,invoice_id,invoice_no_snapshot,applied_amount,currency
    ) values (
      v_payment_id||'-'||lpad(v_idx::text,2,'0'),
      v_payment_id,v_inv.invoice_id,v_inv.invoice_no,v_inv.outstanding,v_inv.currency
    );

    if v_method='Cash' then
      v_share:=case when v_total>0 then v_inv.outstanding/v_total else 0 end;

      insert into public.daily_receivable_cash_collections(
        collection_line_id,payment_id,receive_date,invoice_id,invoice_no_snapshot,
        invoice_date,customer_id,customer_name_snapshot,salesperson_staff_id,
        salesman_name_snapshot,location_code,payment_method,invoice_currency,
        receivable_applied,cash_received_usd,cash_received_khr,
        approved_by_name_snapshot,approved_by_user_id
      ) values (
        v_payment_id||'-'||lpad(v_idx::text,2,'0'),
        v_payment_id,
        coalesce(nullif(p_payload->>'paymentDate','')::date,current_date),
        v_inv.invoice_id,v_inv.invoice_no,v_inv.invoice_date,v_inv.customer_id,
        v_inv.customer_name_snapshot,v_inv.salesperson_staff_id,
        v_inv.salesperson_name_snapshot,v_inv.location_code,'Cash',v_inv.currency,
        v_inv.outstanding,v_cash_usd*v_share,v_cash_khr*v_share,v_actor,auth.uid()
      );
    end if;

    update public.invoices
    set amount_paid=grand_total,
        outstanding=0,
        credit_amount=0,
        status='Paid'
    where invoice_id=v_inv.invoice_id;
  end loop;

  if v_method='Cash' then
    v_vault_id:=public.bb_next_prefixed_id(
      'public.cash_vault_ledger'::regclass,'vault_entry_id','VLT',6
    );
    if coalesce(v_rate,0)>0 then
      v_usd_eq:=v_cash_usd+(v_cash_khr/v_rate);
    end if;

    insert into public.cash_vault_ledger(
      vault_entry_id,entry_at,entry_type,source,salesperson_staff_id,
      salesperson_name_snapshot,usd_amount,khr_amount,exchange_rate,
      usd_equivalent,note,admin_name_snapshot,admin_user_id
    ) values (
      v_vault_id,now(),'IN','Receivable Cash',
      case when v_salesperson_count=1 then v_first.salesperson_staff_id else null end,
      case when v_salesperson_count=1 then v_first.salesperson_name_snapshot else 'Multiple Salespeople' end,
      v_cash_usd,v_cash_khr,coalesce(v_rate,0),v_usd_eq,
      'Receivable cash collection',v_actor,auth.uid()
    );
  end if;

  return jsonb_build_object(
    'success',true,
    'paymentId',v_payment_id,
    'approvedBy',v_actor,
    'invoiceCount',v_count,
    'totalAmount',v_total,
    'currency',v_first.currency,
    'customerCount',v_customer_count
  );
end;
$function$;
