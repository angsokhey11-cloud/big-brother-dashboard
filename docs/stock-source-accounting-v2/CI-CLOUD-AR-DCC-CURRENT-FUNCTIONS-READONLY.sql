-- BIG BROTHER Stock Source V2 A/R and Daily Cash audit: exact read-only copies of the current production function definitions.
-- TEST REFERENCE ONLY: do not deploy this file to Cloud, production or real Local.
-- Source: Cloud pg_catalog.pg_get_functiondef (read-only) on 01-Nov-2026. Check drift before release.

-- Current Cloud function: public.bb_credit_invoice_net_balance_guard
CREATE OR REPLACE FUNCTION public.bb_credit_invoice_net_balance_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_effective_total numeric;
  v_reversal_increased boolean := false;
begin
  new.reversal_amount := greatest(coalesce(new.reversal_amount,0),0);

  if lower(coalesce(new.payment_method,'')) <> 'credit' then
    return new;
  end if;

  v_effective_total := greatest(
    coalesce(new.grand_total,0) - new.reversal_amount,
    0
  );

  if tg_op='UPDATE' then
    v_reversal_increased :=
      new.reversal_amount > coalesce(old.reversal_amount,0) + 0.000001;
  end if;

  new.amount_paid := greatest(coalesce(new.amount_paid,0),0);

  if v_reversal_increased
     and coalesce(old.amount_paid,0) > v_effective_total + 0.000001 then
    raise exception
      'Invoice % has already collected % but would be worth only % after this reversal. Process the customer refund/credit before reversing this amount.',
      coalesce(new.invoice_no,new.invoice_id),
      old.amount_paid,
      v_effective_total;
  end if;

  /* Payment functions are validated against current outstanding first.
     Cap their stored cumulative amount at the post-reversal net invoice value. */
  new.amount_paid := least(new.amount_paid,v_effective_total);
  new.outstanding := greatest(v_effective_total - new.amount_paid,0);
  new.credit_amount := new.outstanding;

  if coalesce(new.grand_total,0) > 0
     and new.reversal_amount >= coalesce(new.grand_total,0) - 0.000001 then
    new.status := 'Reversed';
  elsif new.outstanding <= 0.000001 then
    new.status := 'Paid';
  elsif new.amount_paid > 0.000001 then
    new.status := 'Processing';
  else
    new.status := 'Unpaid';
  end if;

  return new;
end;
$function$

-- Current Cloud function: public.bb_dcc_invoice_list
CREATE OR REPLACE FUNCTION public.bb_dcc_invoice_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rows jsonb;
begin
  if not public.bb_has_module_access('daily_cash_collection','view') then
    raise exception 'Daily Cash Collection access denied';
  end if;

  with cash_payments as (
    select
      p.invoice_id,
      min(p.payment_date) as cash_date,
      upper(coalesce(max(nullif(trim(p.currency),'')),'USD')) as cash_currency,
      max(coalesce(p.exchange_rate,0)) as cash_exchange_rate,
      sum(coalesce(p.amount,0)) as cash_amount,
      jsonb_agg(p.payment_id order by p.payment_date,p.created_at,p.payment_id) as cash_payment_ids
    from public.payments p
    where lower(trim(coalesce(p.payment_method,'')))='cash'
      and lower(trim(coalesce(p.payment_source,'')))='invoice'
      and coalesce(p.amount,0)>0
      and upper(coalesce(p.currency,'USD')) in ('USD','KHR')
    group by p.invoice_id
  )
  select coalesce(jsonb_agg(row_json order by sort_date desc, invoice_no desc),'[]'::jsonb)
  into v_rows
  from (
    select
      coalesce(cp.cash_date,i.invoice_date) as sort_date,
      i.invoice_no,
      jsonb_build_object(
        'invoiceId',i.invoice_id,
        'invoiceNo',i.invoice_no,
        'invoiceDate',coalesce(cp.cash_date,i.invoice_date)::text,
        'customerId',coalesce(i.customer_id,''),
        'customer',coalesce(i.customer_name_snapshot,''),
        'phone',coalesce(c.phone,''),
        'address',coalesce(c.address,''),
        'locationCode',coalesce(i.location_code,c.location_code,''),
        'salespersonStaffId',coalesce(i.salesperson_staff_id,''),
        'salesperson',coalesce(i.salesperson_name_snapshot,''),
        'paymentMethod','Cash',
        'currency',cp.cash_currency,
        'exchangeRate',case when cp.cash_exchange_rate>0 then cp.cash_exchange_rate else coalesce(i.exchange_rate,1) end,
        'subtotal',coalesce(i.subtotal,0),
        'discount',coalesce(i.discount,0),
        'grandTotal',coalesce(i.grand_total,0),
        'amountPaid',coalesce(cp.cash_amount,0),
        'cashAmount',coalesce(cp.cash_amount,0),
        'cashPaymentIds',coalesce(cp.cash_payment_ids,'[]'::jsonb),
        'outstanding',coalesce(i.outstanding,0),
        'status',coalesce(i.status,''),
        'invoiceType',case when coalesce(i.outstanding,0)>0 then 'Credit' else 'Paid' end,
        'dueDate',coalesce(i.due_date::text,''),
        'bankPayment','',
        'bankReference','',
        'batchNumber',coalesce(i.batch_number,''),
        'shippingTo',coalesce(i.shipping_to_legacy,''),
        'note',coalesce(i.note,'')
      ) row_json
    from cash_payments cp
    join public.invoices i on i.invoice_id=cp.invoice_id
    left join public.customers c on c.customer_id=i.customer_id
    where public.bb_has_location_access(coalesce(i.location_code,c.location_code,''))
      and lower(trim(coalesce(i.status,''))) <> 'reversed'
      and not (coalesce(i.grand_total,0)>0 and (select coalesce(sum(sr.return_amount),0) from public.sales_returns sr where sr.invoice_id=i.invoice_id)>=coalesce(i.grand_total,0)-0.005)
  ) q;

  return jsonb_build_object(
    'success',true,
    'revision',public.bb_dcc_revision(),
    'invoices',v_rows,
    'access',public.bb_dcc_access_profile()
  );
end;
$function$

-- Current Cloud function: public.bb_sync_invoice_reversal_receivable
CREATE OR REPLACE FUNCTION public.bb_sync_invoice_reversal_receivable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice_id text;
  v_invoice public.invoices%rowtype;
  v_gross_return numeric := 0;
  v_financial_return numeric := 0;
  v_ratio numeric := 1;
begin
  v_invoice_id := coalesce(new.invoice_id,old.invoice_id);

  select * into v_invoice
  from public.invoices
  where invoice_id=v_invoice_id
  for update;

  if not found then
    return coalesce(new,old);
  end if;

  select coalesce(sum(sr.return_amount),0)
  into v_gross_return
  from public.sales_returns sr
  where sr.invoice_id=v_invoice_id;

  if coalesce(v_invoice.subtotal,0) > 0 then
    v_ratio := coalesce(v_invoice.grand_total,0) / v_invoice.subtotal;
  end if;

  v_financial_return := least(
    coalesce(v_invoice.grand_total,0),
    greatest(v_gross_return * v_ratio,0)
  );

  update public.invoices
  set reversal_amount=v_financial_return
  where invoice_id=v_invoice_id;

  if tg_op <> 'DELETE'
     and lower(coalesce(v_invoice.payment_method,''))='credit' then
    update public.ar_payment_requests r
    set status='Rejected',
        reviewed_by_name_snapshot='System',
        reviewed_by_user_id=null,
        reviewed_at=now(),
        reject_reason='Invoice reversal changed the receivable balance. Submit a new request using the updated outstanding amount.',
        updated_at=now()
    where lower(coalesce(r.status,''))='processing'
      and exists (
        select 1
        from public.ar_request_allocations a
        where a.request_id=r.request_id
          and a.invoice_id=v_invoice_id
      );
  end if;

  return coalesce(new,old);
end;
$function$
