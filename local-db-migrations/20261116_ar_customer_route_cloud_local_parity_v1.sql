-- BIG BROTHER: 16-Nov-2026 A/R COLLECTION ROUTING BY CUSTOMER ASSIGNED LOCATION.
-- No financial rows modified. Preserve invoices.location_code as sale/batch record.
-- Dynamic A/R access follows customers.location_code; new invoice owner snapshots follow customer route.
-- Monthly sales, inventory and invoice amounts not changed.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
-- bb_ar_list
CREATE OR REPLACE FUNCTION public.bb_ar_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rows jsonb; v_access jsonb;
begin
  if not public.bb_has_module_access('accounts_receivable','view') then
    raise exception 'Accounts Receivable access denied';
  end if;

  v_access:=public.bb_ar_access_profile();

  select coalesce(jsonb_agg(q.row_json order by q.invoice_date,q.invoice_no),'[]'::jsonb)
  into v_rows
  from (
    select i.invoice_date,i.invoice_no,
      jsonb_build_object(
        'invoiceId',i.invoice_id,
        'invoiceNo',i.invoice_no,
        'invoiceDate',i.invoice_date::text,
        'dueDate',coalesce(i.due_date::text,''),
        'customerId',coalesce(i.customer_id,''),
        'customer',coalesce(i.customer_name_snapshot,''),
        'customerPhone',coalesce(c.phone,''),
        'customerAddress',coalesce(c.address,''),
        'locationCode',coalesce(c.location_code,''),
        'saleLocationCode',coalesce(i.location_code,''),
        'locationName',coalesce(l.location_name,c.location_code,''),
        'salespersonStaffId',coalesce(i.salesperson_staff_id,''),
        'salesperson',coalesce(i.salesperson_name_snapshot,''),
        'receivableOwnerStaffId',coalesce(l.salesperson_staff_id,''),
        'receivableOwner',coalesce(l.salesperson_name,''),
        'currency',coalesce(i.currency,'USD'),
        'exchangeRate',coalesce(i.exchange_rate,1),
        'grandTotal',coalesce(i.grand_total,0),
        'amountPaid',coalesce(i.amount_paid,0),
        'outstanding',coalesce(i.outstanding,0),
        'arStatus',case
          when pr.request_id is not null then 'Processing'
          when i.due_date is not null and i.due_date<current_date then 'Overdue'
          else 'Outstanding'
        end,
        'requestId',coalesce(pr.request_id,''),
        'requestedBy',coalesce(pr.requested_by_name_snapshot,'')
      ) row_json
    from public.invoices i
    left join public.customers c on c.customer_id=i.customer_id
    left join public.locations l on l.location_code=c.location_code
    left join lateral (
      select r.request_id,r.requested_by_name_snapshot
      from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=i.invoice_id and lower(coalesce(r.status,''))='processing'
      order by r.created_at desc
      limit 1
    ) pr on true
    where coalesce(i.outstanding,0)>0
      and lower(btrim(coalesce(i.payment_method,''))) in ('credit','partially paid in cash','partially paid in bank')
      and (
        public.bb_is_admin()
        or private.bb_is_current_receivable_owner(c.location_code)
      )
  ) q;

  return jsonb_build_object(
    'success',true,
    'revision',public.bb_ar_revision(),
    'receivables',v_rows,
    'access',v_access
  );
end;
$function$;

-- bb_ar_list_all
CREATE OR REPLACE FUNCTION public.bb_ar_list_all()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rows jsonb;
  v_access jsonb;
begin
  if not public.bb_has_module_access('route.ar-all','view') then
    raise exception 'All Receivable access denied';
  end if;

  if not public.bb_has_module_access('accounts_receivable','view') then
    raise exception 'Accounts Receivable access denied';
  end if;

  v_access:=public.bb_ar_access_profile_all();

  select coalesce(
    jsonb_agg(q.row_json order by q.invoice_date,q.invoice_no),
    '[]'::jsonb
  )
  into v_rows
  from (
    select
      i.invoice_date,
      i.invoice_no,
      jsonb_build_object(
        'invoiceId',i.invoice_id,
        'invoiceNo',i.invoice_no,
        'invoiceDate',i.invoice_date::text,
        'dueDate',coalesce(i.due_date::text,''),
        'customerId',coalesce(i.customer_id,''),
        'customer',coalesce(i.customer_name_snapshot,''),
        'customerPhone',coalesce(c.phone,''),
        'customerAddress',coalesce(c.address,''),
        'locationCode',coalesce(c.location_code,''),
        'saleLocationCode',coalesce(i.location_code,''),
        'locationName',coalesce(l.location_name,c.location_code,''),
        'salespersonStaffId',coalesce(i.salesperson_staff_id,''),
        'salesperson',coalesce(i.salesperson_name_snapshot,''),
        'receivableOwnerStaffId',coalesce(l.salesperson_staff_id,''),
        'receivableOwner',coalesce(l.salesperson_name,''),
        'currency',coalesce(i.currency,'USD'),
        'exchangeRate',coalesce(i.exchange_rate,1),
        'grandTotal',coalesce(i.grand_total,0),
        'amountPaid',coalesce(i.amount_paid,0),
        'outstanding',coalesce(i.outstanding,0),
        'arStatus',case
          when pr.request_id is not null then 'Processing'
          when i.due_date is not null and i.due_date<current_date then 'Overdue'
          else 'Outstanding'
        end,
        'requestId',coalesce(pr.request_id,''),
        'requestedBy',coalesce(pr.requested_by_name_snapshot,'')
      ) row_json
    from public.invoices i
    left join public.customers c
      on c.customer_id=i.customer_id
    left join public.locations l
      on l.location_code=c.location_code
    left join lateral (
      select r.request_id,r.requested_by_name_snapshot
      from public.ar_request_allocations a
      join public.ar_payment_requests r
        on r.request_id=a.request_id
      where a.invoice_id=i.invoice_id
        and lower(coalesce(r.status,''))='processing'
      order by r.created_at desc
      limit 1
    ) pr on true
    where coalesce(i.outstanding,0)>0
      and lower(btrim(coalesce(i.payment_method,''))) in ('credit','partially paid in cash','partially paid in bank')
      and public.bb_has_location_access(c.location_code)
  ) q;

  return jsonb_build_object(
    'success',true,
    'revision',public.bb_ar_revision(),
    'receivables',v_rows,
    'access',v_access,
    'scope','ASSIGNED_LOCATIONS_COMPANY_RECEIVABLE'
  );
end;
$function$;

-- bb_ar_create_request
CREATE OR REPLACE FUNCTION public.bb_ar_create_request(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nos text[]:=array[]::text[];
  v_no text;
  v_inv public.invoices%rowtype;
  v_first public.invoices%rowtype;
  v_request_id text;
  v_count int:=0;
  v_total numeric:=0;
  v_amount numeric;
  v_idx int:=0;
  v_date date:=coalesce(nullif(p_payload->>'paymentDate','')::date,current_date);
  v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
  v_actor text:=public.bb_actor_name();
  v_staff_id text:=public.bb_actor_staff_id();
  v_single_amount numeric:=greatest(coalesce(nullif(p_payload->>'amount','')::numeric,0),0);
begin
  if not public.bb_has_module_access('accounts_receivable','create') then
    raise exception 'Accounts Receivable request access denied';
  end if;

  if jsonb_typeof(p_payload->'invoiceNos')='array' then
    select coalesce(array_agg(value),array[]::text[]) into v_nos
    from jsonb_array_elements_text(p_payload->'invoiceNos');
  elsif nullif(trim(coalesce(p_payload->>'invoiceNo','')),'') is not null then
    v_nos:=array[trim(p_payload->>'invoiceNo')];
  end if;

  if coalesce(array_length(v_nos,1),0)=0 then raise exception 'No invoices selected'; end if;

  foreach v_no in array v_nos loop
    select * into v_inv from public.invoices
    where lower(invoice_no)=lower(trim(v_no))
    for update;

    if not found then raise exception 'Invoice % was not found',v_no; end if;
    if coalesce(v_inv.outstanding,0)<=0 then raise exception 'Invoice % is already fully paid',v_inv.invoice_no; end if;
    if lower(coalesce(v_inv.payment_method,''))<>'credit' then raise exception 'Invoice % is not a Credit invoice',v_inv.invoice_no; end if;

    if not public.bb_is_admin()
       and not public.bb_has_module_access('route.ar-all','create')
       and not private.bb_is_current_receivable_owner((select c.location_code from public.customers c where c.customer_id=v_inv.customer_id)) then
      raise exception 'Receivable responsibility access denied for invoice %',v_inv.invoice_no;
    end if;

    if exists(
      select 1 from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_inv.invoice_id and lower(coalesce(r.status,''))='processing'
    ) then raise exception 'Invoice % already has a Processing request',v_inv.invoice_no; end if;

    if v_count=0 then
      v_first:=v_inv;
    else
      if coalesce(v_inv.customer_id,'')<>coalesce(v_first.customer_id,'') then raise exception 'Selected invoices must belong to one customer'; end if;
      if upper(coalesce(v_inv.currency,'USD'))<>upper(coalesce(v_first.currency,'USD')) then raise exception 'Selected invoices must use one currency'; end if;
    end if;

    v_count:=v_count+1;
  end loop;

  if v_count=1 and v_single_amount>0 then
    if v_single_amount>v_first.outstanding+0.000001 then raise exception 'Requested amount cannot exceed outstanding balance'; end if;
  end if;

  v_request_id:=public.bb_next_prefixed_id('public.ar_payment_requests'::regclass,'request_id','ARR',5);

  insert into public.ar_payment_requests(
    request_id,request_date,customer_id,customer_name_snapshot,currency,request_type,payment_method,note,
    requested_by_staff_id,requested_by_name_snapshot,requested_by_user_id,status
  ) values (
    v_request_id,v_date,v_first.customer_id,v_first.customer_name_snapshot,v_first.currency,
    coalesce(nullif(trim(coalesce(p_payload->>'requestType','')),''),'Direct Request'),'Direct Request',v_note,
    v_staff_id,v_actor,auth.uid(),'Processing'
  );

  foreach v_no in array v_nos loop
    select * into v_inv from public.invoices where lower(invoice_no)=lower(trim(v_no));
    v_idx:=v_idx+1;
    v_amount:=case when v_count=1 and v_single_amount>0 then v_single_amount else v_inv.outstanding end;
    insert into public.ar_request_allocations(
      request_allocation_id,request_id,invoice_id,invoice_no_snapshot,requested_amount,currency
    ) values (
      v_request_id||'-'||lpad(v_idx::text,2,'0'),v_request_id,v_inv.invoice_id,v_inv.invoice_no,v_amount,v_inv.currency
    );
    v_total:=v_total+v_amount;
  end loop;

  return jsonb_build_object(
    'success',true,
    'requestId',v_request_id,
    'invoiceCount',v_count,
    'totalAmount',v_total,
    'currency',v_first.currency,
    'requestedBy',v_actor
  );
end;
$function$;

-- bb_ar_create_request_v2
CREATE OR REPLACE FUNCTION public.bb_ar_create_request_v2(p_payload jsonb)
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
  v_request_id text;
  v_count int:=0;
  v_total numeric:=0;
  v_amount numeric;
  v_idx int:=0;
  v_date date:=coalesce(nullif(p_payload->>'paymentDate','')::date,current_date);
  v_note text:=nullif(trim(coalesce(p_payload->>'note','')),'');
  v_actor text:=public.bb_actor_name();
  v_staff_id text:=public.bb_actor_staff_id();
  v_single_amount numeric:=greatest(coalesce(nullif(p_payload->>'amount','')::numeric,0),0);
  v_customer_count int:=0;
begin
  if not public.bb_has_module_access('accounts_receivable','create') then
    raise exception 'Accounts Receivable request access denied';
  end if;

  if jsonb_typeof(p_payload->'invoiceIds')='array' then
    select coalesce(array_agg(value),array[]::text[]) into v_ids
    from jsonb_array_elements_text(p_payload->'invoiceIds');
  elsif nullif(trim(coalesce(p_payload->>'invoiceId','')),'') is not null then
    v_ids:=array[trim(p_payload->>'invoiceId')];
  end if;

  if coalesce(array_length(v_ids,1),0)=0 then
    raise exception 'No invoices selected';
  end if;

  foreach v_id in array v_ids loop
    select * into v_inv
    from public.invoices
    where invoice_id=trim(v_id)
    for update;

    if not found then raise exception 'Invoice record % was not found',v_id; end if;
    if coalesce(v_inv.outstanding,0)<=0 then raise exception 'Invoice % is already fully paid',v_inv.invoice_no; end if;
    if lower(btrim(coalesce(v_inv.payment_method,''))) not in ('credit','partially paid in cash','partially paid in bank') then raise exception 'Invoice % is not an eligible outstanding receivable',v_inv.invoice_no; end if;

    if not public.bb_is_admin()
       and not public.bb_has_module_access('route.ar-all','create')
       and not private.bb_is_current_receivable_owner((select c.location_code from public.customers c where c.customer_id=v_inv.customer_id)) then
      raise exception 'Receivable responsibility access denied for invoice %',v_inv.invoice_no;
    end if;

    if exists(
      select 1
      from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_inv.invoice_id
        and lower(coalesce(r.status,''))='processing'
    ) then
      raise exception 'Invoice % already has a Processing request',v_inv.invoice_no;
    end if;

    if v_count=0 then
      v_first:=v_inv;
    else
      if upper(coalesce(v_inv.currency,'USD'))<>upper(coalesce(v_first.currency,'USD')) then
        raise exception 'Selected invoices must use one currency';
      end if;
    end if;

    v_count:=v_count+1;
  end loop;

  select count(distinct coalesce(customer_id,''))
    into v_customer_count
  from public.invoices
  where invoice_id=any(v_ids);

  if v_count=1 and v_single_amount>0 then
    if v_single_amount>v_first.outstanding+0.000001 then
      raise exception 'Requested amount cannot exceed outstanding balance';
    end if;
  end if;

  v_request_id:=public.bb_next_prefixed_id(
    'public.ar_payment_requests'::regclass,'request_id','ARR',5
  );

  insert into public.ar_payment_requests(
    request_id,request_date,customer_id,customer_name_snapshot,currency,
    request_type,payment_method,note,requested_by_staff_id,
    requested_by_name_snapshot,requested_by_user_id,status
  ) values (
    v_request_id,v_date,
    case when v_customer_count=1 then v_first.customer_id else null end,
    case when v_customer_count=1 then v_first.customer_name_snapshot else 'Multiple Customers' end,
    v_first.currency,
    coalesce(nullif(trim(coalesce(p_payload->>'requestType','')),''),'Direct Request'),
    'Direct Request',v_note,v_staff_id,v_actor,auth.uid(),'Processing'
  );

  foreach v_id in array v_ids loop
    select * into v_inv
    from public.invoices
    where invoice_id=trim(v_id);

    v_idx:=v_idx+1;
    v_amount:=case
      when v_count=1 and v_single_amount>0 then v_single_amount
      else v_inv.outstanding
    end;

    insert into public.ar_request_allocations(
      request_allocation_id,request_id,invoice_id,invoice_no_snapshot,
      requested_amount,currency
    ) values (
      v_request_id||'-'||lpad(v_idx::text,2,'0'),
      v_request_id,v_inv.invoice_id,v_inv.invoice_no,v_amount,v_inv.currency
    );

    v_total:=v_total+v_amount;
  end loop;

  return jsonb_build_object(
    'success',true,
    'requestId',v_request_id,
    'invoiceCount',v_count,
    'totalAmount',v_total,
    'currency',v_first.currency,
    'requestedBy',v_actor,
    'customerCount',v_customer_count
  );
end;
$function$;

-- bb_ar_detail
CREATE OR REPLACE FUNCTION public.bb_ar_detail(p_invoice_no text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_invoice public.invoices%rowtype; v_payments jsonb;
begin
  if not public.bb_has_module_access('accounts_receivable','view') then
    raise exception 'Accounts Receivable access denied';
  end if;

  select * into v_invoice
  from public.invoices
  where lower(invoice_no)=lower(trim(coalesce(p_invoice_no,'')))
  limit 1;

  if not found then raise exception 'Invoice was not found'; end if;

  if not public.bb_is_admin()
     and not public.bb_has_module_access('route.ar-all','view')
     and not private.bb_is_current_receivable_owner((select c.location_code from public.customers c where c.customer_id=v_invoice.customer_id)) then
    raise exception 'Receivable responsibility access denied';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'paymentId',p.payment_id,
    'paymentDate',coalesce(p.payment_date::text,''),
    'paymentMethod',coalesce(p.payment_method,''),
    'bankPayment',coalesce(p.bank_payment,''),
    'bankReference',coalesce(p.bank_reference,''),
    'transactionId',coalesce(p.transaction_id,''),
    'currency',p.currency,
    'amount',p.amount,
    'approvedBy',coalesce(p.approved_by_name_snapshot,p.entered_by_name_snapshot,''),
    'note',coalesce(p.note,'')
  ) order by p.payment_date,p.created_at,p.payment_id),'[]'::jsonb)
  into v_payments
  from public.payments p
  where p.invoice_id=v_invoice.invoice_id
     or exists(
       select 1 from public.payment_allocations a
       where a.payment_id=p.payment_id and a.invoice_id=v_invoice.invoice_id
     );

  return jsonb_build_object(
    'success',true,
    'invoiceNo',v_invoice.invoice_no,
    'payments',v_payments
  );
end;
$function$;

-- bb_ar_detail_by_id
CREATE OR REPLACE FUNCTION public.bb_ar_detail_by_id(p_invoice_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.invoices%rowtype;
  v_payments jsonb;
begin
  if not public.bb_has_module_access('accounts_receivable','view') then
    raise exception 'Accounts Receivable access denied';
  end if;

  select * into v_invoice
  from public.invoices
  where invoice_id=trim(coalesce(p_invoice_id,''))
  limit 1;

  if not found then raise exception 'Invoice was not found'; end if;

  if not public.bb_is_admin()
     and not public.bb_has_module_access('route.ar-all','view')
     and not private.bb_is_current_receivable_owner((select c.location_code from public.customers c where c.customer_id=v_invoice.customer_id)) then
    raise exception 'Receivable responsibility access denied';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'paymentId',p.payment_id,
    'paymentDate',coalesce(p.payment_date::text,''),
    'paymentMethod',coalesce(p.payment_method,''),
    'bankPayment',coalesce(p.bank_payment,''),
    'bankReference',coalesce(p.bank_reference,''),
    'transactionId',coalesce(p.transaction_id,''),
    'currency',p.currency,
    'amount',p.amount,
    'approvedBy',coalesce(p.approved_by_name_snapshot,p.entered_by_name_snapshot,''),
    'note',coalesce(p.note,'')
  ) order by p.payment_date,p.created_at,p.payment_id),'[]'::jsonb)
  into v_payments
  from public.payments p
  where p.invoice_id=v_invoice.invoice_id
     or exists(
       select 1 from public.payment_allocations a
       where a.payment_id=p.payment_id and a.invoice_id=v_invoice.invoice_id
     );

  return jsonb_build_object(
    'success',true,
    'invoiceId',v_invoice.invoice_id,
    'invoiceNo',v_invoice.invoice_no,
    'payments',v_payments
  );
end;
$function$;

-- bb_ar_bank_assistant_list_v1
CREATE OR REPLACE FUNCTION public.bb_ar_bank_assistant_list_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_balances jsonb;
  v_invoices jsonb;
  v_all boolean;
BEGIN
  IF auth.uid() IS NULL OR NOT public.bb_has_module_access('accounts_receivable','view') THEN
    RAISE EXCEPTION 'Accounts Receivable view access required';
  END IF;
  v_all := public.bb_has_module_access('route.ar-all','view');
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'transactionId',b.transaction_id,
    'customerId',b.customer_id,'customer',c.customer_name,'locationCode',c.location_code,
    'payer',coalesce(t.payer_name,''),'receivedDate',b.received_date,
    'bankName',coalesce(t.bank_name,''),'currency',b.currency,
    'invoiceCurrency',coalesce(b.invoice_currency,b.currency),
    'exchangeRate',coalesce(b.approved_exchange_rate,1),
    'originalAmount',b.original_amount,'usedAmount',b.used_amount,
    'remainingAmount',b.remaining_amount,
    'equivalentRemaining',case
       when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount
       when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0)
       else b.remaining_amount*b.approved_exchange_rate end
  ) ORDER BY b.received_date,b.transaction_id,b.customer_id),'[]'::jsonb)
  INTO v_balances
  FROM public.bb_bank_balance_snapshot b
  JOIN public.bb_verified_bank_transactions t ON t.transaction_id=b.transaction_id
  JOIN public.customers c ON c.customer_id=b.customer_id AND c.active=true
  WHERE b.status='AVAILABLE' AND b.remaining_amount>0 AND t.status='AVAILABLE'
    AND (public.bb_is_admin() OR
       (v_all AND public.bb_has_location_access(c.location_code)) OR
       (NOT v_all AND private.bb_is_current_receivable_owner(c.location_code)));

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'invoiceId',i.invoice_id,'invoiceNo',i.invoice_no,'invoiceDate',i.invoice_date,
    'customerId',i.customer_id,'customer',i.customer_name_snapshot,
    'locationCode',c.location_code,'saleLocationCode',i.location_code,'currency',i.currency,'outstanding',i.outstanding,
    'pendingRequestId',coalesce(pr.request_id,'')
  ) ORDER BY i.invoice_date,i.invoice_no,i.invoice_id),'[]'::jsonb)
  INTO v_invoices
  FROM public.invoices i
  JOIN public.customers c ON c.customer_id=i.customer_id
  LEFT JOIN LATERAL (
    SELECT r.request_id FROM public.ar_request_allocations a
    JOIN public.ar_payment_requests r ON r.request_id=a.request_id
    WHERE a.invoice_id=i.invoice_id AND lower(coalesce(r.status,''))='processing'
    ORDER BY r.created_at DESC LIMIT 1
  ) pr ON true
  WHERE i.outstanding>0
    AND lower(btrim(coalesce(i.payment_method,''))) IN
       ('credit','partially paid in cash','partially paid in bank')
    AND (public.bb_is_admin()
       OR (v_all AND public.bb_has_location_access(c.location_code))
       OR (NOT v_all AND private.bb_is_current_receivable_owner(c.location_code)))
    AND EXISTS (SELECT 1 FROM public.bb_bank_balance_snapshot b
       JOIN public.bb_verified_bank_transactions t ON t.transaction_id=b.transaction_id
       WHERE b.customer_id=i.customer_id AND b.status='AVAILABLE'
         AND b.remaining_amount>0 AND t.status='AVAILABLE');

  RETURN jsonb_build_object('success',true,'balances',v_balances,'invoices',v_invoices,
    'canSubmit',public.bb_has_module_access('accounts_receivable','create'),
    'canApprove',public.bb_is_admin() AND public.bb_has_module_access('accounts_receivable','approve'),
    'scope',case when public.bb_is_admin() then 'ADMIN'
       when v_all then 'ASSIGNED_LOCATIONS' else 'RECEIVABLE_OWNER' end);
END;
$function$;

-- bb_ar_bank_assistant_submit_v1
CREATE OR REPLACE FUNCTION public.bb_ar_bank_assistant_submit_v1(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tx text:=upper(btrim(coalesce(p_payload->>'transactionId','')));
  v_customer text:=btrim(coalesce(p_payload->>'customerId',''));
  v_reg public.bb_verified_bank_transactions%ROWTYPE;
  v_invoice public.invoices%ROWTYPE;
  v_item jsonb;
  v_id text;
  v_seen text[]:=array[]::text[];
  v_currency text;
  v_amount numeric;
  v_total numeric:=0;
  v_available numeric;
  v_count integer:=0;
  v_idx integer:=0;
  v_request_id text;
  v_actor text:=public.bb_actor_name();
  v_staff text:=public.bb_actor_staff_id();
  v_all boolean;
  v_precision integer;
  v_customer_name text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.bb_has_module_access('accounts_receivable','view')
     OR NOT public.bb_has_module_access('accounts_receivable','create')
  THEN RAISE EXCEPTION 'A/R recommendation submission access denied'; END IF;
  IF length(v_tx)<4 OR length(v_tx)>160 OR v_customer=''
    THEN RAISE EXCEPTION 'Select one registered bank receipt and customer'; END IF;
  IF jsonb_typeof(p_payload->'allocations') IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_payload->'allocations') NOT BETWEEN 1 AND 50
  THEN RAISE EXCEPTION 'Select 1–50 invoices for this bank receipt'; END IF;

  v_all:=public.bb_has_module_access('route.ar-all','view');
  IF NOT EXISTS(SELECT 1 FROM public.customers c
    WHERE c.customer_id=v_customer AND c.active=true
    AND (public.bb_is_admin()
      OR (v_all AND public.bb_has_location_access(c.location_code))
      OR (NOT v_all AND private.bb_is_current_receivable_owner(c.location_code))))
  THEN RAISE EXCEPTION 'Customer outside authorized A/R scope'; END IF;
  SELECT c.customer_name INTO v_customer_name FROM public.customers c WHERE c.customer_id=v_customer;
  PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tx));
  SELECT * INTO v_reg FROM public.bb_verified_bank_transactions t
     WHERE upper(btrim(t.transaction_id))=v_tx FOR UPDATE;
  IF NOT FOUND OR v_reg.status<>'AVAILABLE'
    THEN RAISE EXCEPTION 'Registered bank balance is no longer available'; END IF;
  IF v_reg.received_date IS NULL
    THEN RAISE EXCEPTION 'Bank received date is missing; correct the Bank Register before submitting'; END IF;
  IF EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s WHERE s.transaction_id=v_reg.transaction_id) THEN
    IF NOT EXISTS(SELECT 1 FROM public.bb_bank_outlet_shares s
       WHERE s.transaction_id=v_reg.transaction_id AND s.customer_id=v_customer)
    THEN RAISE EXCEPTION 'Customer has no approved share of this receipt'; END IF;
  ELSIF v_reg.customer_id<>v_customer THEN
    RAISE EXCEPTION 'Registered receipt belongs to another customer';
  END IF;

  SELECT b.invoice_currency,
    case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount
      when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0)
      else b.remaining_amount*b.approved_exchange_rate end
  INTO v_currency,v_available FROM public.bb_bank_balance_snapshot b
  WHERE b.transaction_id=v_reg.transaction_id AND b.customer_id=v_customer
    AND b.status='AVAILABLE' AND b.remaining_amount>0;
  IF NOT FOUND OR v_available IS NULL OR v_available<=0
    THEN RAISE EXCEPTION 'Registered balance was consumed or not allocated to this customer'; END IF;
  v_currency:=upper(v_currency);
  v_precision:=case when v_currency='KHR' then 0 else 2 end;

  FOR v_item IN SELECT x.value FROM jsonb_array_elements(p_payload->'allocations') x(value)
      ORDER BY x.value->>'invoiceId' LOOP
    v_id:=btrim(coalesce(v_item->>'invoiceId',''));
    IF v_id='' OR v_id=ANY(v_seen)
       THEN RAISE EXCEPTION 'Duplicate or missing invoice in recommendation'; END IF;
    v_seen:=array_append(v_seen,v_id);
    IF coalesce(v_item->>'amount','') !~ '^[0-9]+([.][0-9]+)?$'
       THEN RAISE EXCEPTION 'Invalid invoice allocation amount'; END IF;
    v_amount:=(v_item->>'amount')::numeric;
    IF v_amount<=0 OR v_amount<>round(v_amount,v_precision)
       THEN RAISE EXCEPTION 'Invoice amount must use valid currency precision'; END IF;
    SELECT * INTO v_invoice FROM public.invoices WHERE invoice_id=v_id FOR UPDATE;
    IF NOT FOUND OR v_invoice.customer_id<>v_customer
       THEN RAISE EXCEPTION 'Invoice is not assigned to this bank customer'; END IF;
    IF NOT (public.bb_is_admin()
       OR (v_all AND public.bb_has_location_access((SELECT c.location_code FROM public.customers c WHERE c.customer_id=v_invoice.customer_id)))
       OR (NOT v_all AND private.bb_is_current_receivable_owner((SELECT c.location_code FROM public.customers c WHERE c.customer_id=v_invoice.customer_id))))
       THEN RAISE EXCEPTION 'Invoice outside authorized A/R scope'; END IF;
    IF v_invoice.outstanding<=0 OR
       lower(btrim(coalesce(v_invoice.payment_method,''))) NOT IN
          ('credit','partially paid in cash','partially paid in bank')
       THEN RAISE EXCEPTION 'Selected invoice is not an active A/R invoice'; END IF;
    IF upper(v_invoice.currency)<>v_currency
       THEN RAISE EXCEPTION 'Registered balance and invoice currencies differ'; END IF;
    IF v_amount>v_invoice.outstanding+0.000001
       THEN RAISE EXCEPTION 'Selected invoice amount exceeds its outstanding balance'; END IF;
    IF EXISTS(SELECT 1 FROM public.ar_request_allocations a
       JOIN public.ar_payment_requests r ON r.request_id=a.request_id
       WHERE a.invoice_id=v_invoice.invoice_id AND lower(coalesce(r.status,''))='processing')
       THEN RAISE EXCEPTION 'Invoice % already has a pending payment request',v_invoice.invoice_no; END IF;
    v_total:=v_total+v_amount;
    v_count:=v_count+1;
  END LOOP;
  IF v_total>v_available+0.000001
  THEN RAISE EXCEPTION 'Receipt balance changed: only % % remains for this customer',round(v_available,v_precision),v_currency; END IF;

  v_request_id:=public.bb_next_prefixed_id('public.ar_payment_requests'::regclass,'request_id','ARR',5);
  INSERT INTO public.ar_payment_requests(
    request_id,request_date,customer_id,customer_name_snapshot,currency,
    request_type,payment_method,bank_payment,bank_reference,transaction_id,note,
    requested_by_staff_id,requested_by_name_snapshot,requested_by_user_id,status)
  VALUES(v_request_id,(now() AT TIME ZONE 'Asia/Phnom_Penh')::date,
    v_customer,v_customer_name,v_currency,'Bank Assistant','Bank',
    v_reg.bank_name,NULL,v_reg.transaction_id,
    'Registered bank recommendation. Received '||v_reg.received_date::text||
      '. '||left(btrim(coalesce(p_payload->>'note','')),300),
    v_staff,v_actor,auth.uid(),'Processing');

  FOR v_item IN SELECT x.value FROM jsonb_array_elements(p_payload->'allocations') x(value)
     ORDER BY x.value->>'invoiceId' LOOP
    v_idx:=v_idx+1;
    INSERT INTO public.ar_request_allocations(
       request_allocation_id,request_id,invoice_id,invoice_no_snapshot,requested_amount,currency)
    SELECT v_request_id||'-'||lpad(v_idx::text,2,'0'),
      v_request_id,i.invoice_id,i.invoice_no,(v_item->>'amount')::numeric,i.currency
    FROM public.invoices i WHERE i.invoice_id=btrim(v_item->>'invoiceId');
  END LOOP;
  RETURN jsonb_build_object('success',true,'requestId',v_request_id,
     'totalAmount',v_total,'invoiceCount',v_count,'currency',v_currency,
     'transactionId',v_reg.transaction_id,'status','Processing');
END;
$function$;

-- bb_sales_support_ar_cash_candidates_v1
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
     c.location_code as "locationCode",
     i.location_code as "saleLocationCode",
     coalesce(l.location_name,c.location_code,'') as "locationName",
     i.salesperson_staff_id as "salespersonStaffId",
     i.salesperson_name_snapshot as "salesperson",
     upper(coalesce(i.currency,'USD')) as currency,
     i.exchange_rate as "exchangeRate",i.outstanding as outstanding,
     i.payment_method as "paymentMethod"
   from public.invoices i
   join public.customers c on c.customer_id=i.customer_id
   left join public.locations l on l.location_code=c.location_code
   where i.outstanding>0.000001
     and lower(trim(coalesce(i.payment_method,''))) in ('credit','partially paid in cash','partially paid in bank')
     and (public.bb_is_admin() or public.bb_has_module_access('route.ar-all','create')
          or private.bb_is_current_receivable_owner(coalesce(c.location_code,'')))
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
$function$;

-- bb_dcc_combined_cash_request_v1
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
 v_ar_locations text[]:=ARRAY[]::text[];
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
   select nullif(trim(c.location_code),'') into v_expected_location
   from public.customers c where c.customer_id=v_inv.customer_id;
   if v_expected_location is null then
     raise exception 'Customer location is missing for invoice %; update the Customer directory first',v_inv.invoice_no;
   end if;
   if not public.bb_is_admin() and not public.bb_has_module_access('route.ar-all','create')
     and not private.bb_is_current_receivable_owner(v_expected_location)
   then raise exception 'Receivable responsibility access denied for %',v_inv.invoice_no;end if;
   if exists(select 1 from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_invoice_id and lower(coalesce(r.status,''))='processing')
   then raise exception 'Receivable invoice % already has a pending request',v_inv.invoice_no;end if;
   -- Keep sale location independent of the A/R customer collection route.
   if v_location is null then v_location:=v_expected_location;end if;
   if not (v_expected_location=any(v_ar_locations)) then
     v_ar_locations:=array_append(v_ar_locations,v_expected_location);
   end if;
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
   'locationCode',v_location,'sourceMode',v_mode,'arCustomerLocationCodes',to_jsonb(v_ar_locations),'sales',v_sale_result,'receivables',v_ar_results,
   'salesInvoiceCount',v_sale_count,'arInvoiceCount',v_ar_count,
   'arAmountUSD',v_total_usd,'arAmountKHR',v_total_khr,
   'salesStatus',case when v_sale_count>0 then 'Pending' else 'Not requested' end,
   'receivableStatus',case when v_ar_count>0 then 'Processing' else 'Not requested' end,
   'message','Combined handover split into existing Daily Cash and A/R pending request workflows. No A/R payment, cash vault, or bank balance was created.');
 insert into public.bb_salesman_combined_cash_submissions(request_id,actor_user_id,actor_staff_id,payload_fingerprint,result)
 values(v_request_id,v_actor,v_staff,v_fingerprint,v_result);
 return v_result;
end;
$function$;

-- bb_sales_support_combined_cash_request_v1
CREATE OR REPLACE FUNCTION public.bb_sales_support_combined_cash_request_v1(p_payload jsonb)
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
 v_ar_locations text[]:=ARRAY[]::text[];
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
   select nullif(trim(c.location_code),'') into v_expected_location
   from public.customers c where c.customer_id=v_inv.customer_id;
   if v_expected_location is null then
     raise exception 'Customer location is missing for invoice %; update the Customer directory first',v_inv.invoice_no;
   end if;
   if not public.bb_is_admin() and not public.bb_has_module_access('route.ar-all','create')
     and not private.bb_is_current_receivable_owner(v_expected_location)
   then raise exception 'Receivable responsibility access denied for %',v_inv.invoice_no;end if;
   if exists(select 1 from public.ar_request_allocations a
      join public.ar_payment_requests r on r.request_id=a.request_id
      where a.invoice_id=v_invoice_id and lower(coalesce(r.status,''))='processing')
   then raise exception 'Receivable invoice % already has a pending request',v_inv.invoice_no;end if;
   -- Keep sale location independent of the A/R customer collection route.
   if v_location is null then v_location:=v_expected_location;end if;
   if not (v_expected_location=any(v_ar_locations)) then
     v_ar_locations:=array_append(v_ar_locations,v_expected_location);
   end if;
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
   'locationCode',v_location,'arCustomerLocationCodes',to_jsonb(v_ar_locations),'sales',v_sale_result,'receivables',v_ar_results,
   'salesInvoiceCount',v_sale_count,'arInvoiceCount',v_ar_count,
   'arAmountUSD',v_total_usd,'arAmountKHR',v_total_khr,
   'salesStatus',case when v_sale_count>0 then 'Pending' else 'Not requested' end,
   'receivableStatus',case when v_ar_count>0 then 'Processing' else 'Not requested' end,
   'message','Combined handover split into existing Daily Cash and A/R pending request workflows. No A/R payment, cash vault, or bank balance was created.');
 insert into public.bb_salesman_combined_cash_submissions(request_id,actor_user_id,actor_staff_id,payload_fingerprint,result)
 values(v_request_id,v_actor,v_staff,v_fingerprint,v_result);
 return v_result;
end;
$function$;

-- bb_set_invoice_receivable_owner
CREATE OR REPLACE FUNCTION private.bb_set_invoice_receivable_owner()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner_staff_id text;
  v_owner_name text;
begin
  select
    nullif(trim(coalesce(l.salesperson_staff_id,'')),''),
    nullif(trim(coalesce(l.salesperson_name,'')),'')
  into
    v_owner_staff_id,
    v_owner_name
  from public.locations l
  where l.location_code = (select c.location_code from public.customers c where c.customer_id=new.customer_id)
  limit 1;

  if v_owner_staff_id is not null then
    new.receivable_owner_staff_id := v_owner_staff_id;
    new.receivable_owner_name_snapshot := coalesce(v_owner_name, v_owner_staff_id);
  else
    -- Safety fallback only when the Customer Location has no permanent salesperson.
    -- Do not block invoice creation; preserve the invoice salesman as owner.
    new.receivable_owner_staff_id := new.salesperson_staff_id;
    new.receivable_owner_name_snapshot := new.salesperson_name_snapshot;
  end if;

  return new;
end;
$function$;
NOTIFY pgrst, 'reload schema';
COMMIT;
