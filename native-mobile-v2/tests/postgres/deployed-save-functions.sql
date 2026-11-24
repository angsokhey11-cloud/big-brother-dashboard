-- Read-only catalog snapshot of deployed functions, 2026-11-24. Disposable fixture ONLY.
CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_bundle_core_v1(p_invoice jsonb, p_payment jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice_id text:=trim(coalesce(p_invoice->>'invoiceId',''));
  v_invoice_no text:=trim(coalesce(p_invoice->>'invoiceNo',''));
  v_invoice_date date:=coalesce(nullif(p_invoice->>'invoiceDate','')::date,current_date);
  v_due_date date:=nullif(p_invoice->>'dueDate','')::date;
  v_location_code text:=trim(coalesce(p_invoice->>'locationCode',''));
  v_customer_id text:=nullif(trim(coalesce(p_invoice->>'customerId','')),'');
  v_customer_name text:=trim(coalesce(p_invoice->>'customer',''));
  v_salesperson_staff_id text:=nullif(trim(coalesce(p_invoice->>'salespersonStaffId','')),'');
  v_salesperson_name text:=trim(coalesce(p_invoice->>'salesperson',''));
  v_payment_method text:=trim(coalesce(p_invoice->>'paymentMethod',''));
  v_currency text:=upper(trim(coalesce(p_invoice->>'currency','USD')));
  v_exchange_rate numeric:=greatest(coalesce(nullif(p_invoice->>'exchangeRate','')::numeric,1),0);
  v_discount numeric:=greatest(coalesce(nullif(p_invoice->>'discount','')::numeric,0),0);
  v_amount_paid numeric:=greatest(coalesce(nullif(p_invoice->>'amountPaid','')::numeric,0),0);
  v_batch text:=nullif(trim(coalesce(p_invoice->>'batchNumber','')),'');
  v_shipping text:=nullif(trim(coalesce(p_invoice->>'shippingTo','')),'');
  v_note text:=nullif(trim(coalesce(p_invoice->>'note','')),'');
  v_bank text:=nullif(trim(coalesce(p_invoice->>'paymentBank','')),'');
  v_tx text:=nullif(trim(coalesce(p_invoice->>'transactionId','')),'');
  v_subtotal numeric:=0;
  v_grand numeric:=0;
  v_outstanding numeric:=0;
  v_status text;
  v_items jsonb:=coalesce(p_invoice->'items','[]'::jsonb);
  v_item jsonb;
  v_line_no integer:=0;
  v_line_id text;
  v_entry text;
  v_product_code text;
  v_group_code text;
  v_display_code text;
  v_product_name text;
  v_barcode text;
  v_unit text;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_alloc jsonb;
  v_need numeric;
  v_take numeric;
  v_r record;
  v_count integer;
  v_payment_id text:='';
  v_payment_amount numeric:=0;
  v_payment_method_normalized text;
  v_client_line_id text;
begin
  if not public.bb_has_sales_write() then
    raise exception 'BIG BROTHER sales write access denied';
  end if;

  if v_invoice_no='' then raise exception 'Invoice No. is required'; end if;
  if v_location_code='' then raise exception 'Main Location is required'; end if;
  if v_customer_name='' then raise exception 'Customer is required'; end if;
  if v_salesperson_name='' then raise exception 'Sale Person is required'; end if;
  if v_payment_method='' then raise exception 'Payment Method is required'; end if;
  if v_currency not in ('USD','KHR') then raise exception 'Currency must be USD or KHR'; end if;
  if jsonb_typeof(v_items)<>'array' or jsonb_array_length(v_items)=0 then raise exception 'At least one Product is required'; end if;

  if not exists(select 1 from public.locations where location_code=v_location_code and active=true) then
    raise exception 'Main Location % is not active',v_location_code;
  end if;


  if v_invoice_id='' then
    v_invoice_id := 'BB-' || to_char(clock_timestamp() at time zone 'Asia/Phnom_Penh','YYYYMMDD-HH24MISSMS') || '-' || substr(md5(random()::text),1,5);
  end if;
  if exists(select 1 from public.invoices where invoice_id=v_invoice_id) then
    raise exception 'Invoice ID already exists. Please retry.';
  end if;

  if v_customer_id is not null then
    if not exists(select 1 from public.customers c where c.customer_id=v_customer_id and coalesce(c.active,true)=true) then
      v_customer_id:=null;
    end if;
  end if;
  if v_customer_id is null then
    select count(*),min(c.customer_id)
    into v_count,v_customer_id
    from public.customers c
    where lower(trim(coalesce(c.customer_name,'')))=lower(v_customer_name)
      and coalesce(c.location_code,'')=v_location_code
      and coalesce(c.active,true)=true;
    if v_count<>1 then v_customer_id:=null; end if;
  end if;

  if v_salesperson_staff_id is not null and not exists(
    select 1 from public.staff s where s.staff_id=v_salesperson_staff_id and lower(coalesce(s.status,'active'))='active'
  ) then
    v_salesperson_staff_id:=null;
  end if;
  if v_salesperson_staff_id is null then
    select count(*),min(s.staff_id)
    into v_count,v_salesperson_staff_id
    from public.staff s
    where lower(trim(s.staff_name))=lower(v_salesperson_name)
      and lower(coalesce(s.status,'active'))='active';
    if v_count<>1 then v_salesperson_staff_id:=null; end if;
  end if;

  if v_batch is not null then
    if not exists(
      select 1 from public.stock_batches b
      where b.batch_id=v_batch
        and upper(coalesce(b.status,'OPEN')) not in ('CLOSED','CANCELLED','CANCELED')
    ) then raise exception 'Batch % is not open',v_batch; end if;
    if exists(select 1 from public.stock_batches b where b.batch_id=v_batch and b.location_code<>v_location_code) then
      raise exception 'Batch % belongs to a different Location',v_batch;
    end if;
  end if;

  -- Validate products and calculate authoritative subtotal from line quantities/prices.
  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_entry:=upper(trim(coalesce(v_item->>'entryType','EXACT')));
    v_qty:=greatest(coalesce(nullif(v_item->>'qty','')::numeric,0),0);
    v_unit_price:=greatest(coalesce(nullif(v_item->>'unitPrice','')::numeric,0),0);
    if v_qty<=0 then continue; end if;

    if v_entry='GROUP' then
      v_group_code:=nullif(trim(coalesce(v_item->>'productGroupCode',v_item->>'productCode')),'');
      if v_group_code is null or not exists(select 1 from public.product_groups g where g.group_code=v_group_code and g.active=true) then
        raise exception 'Product Group % is invalid',coalesce(v_group_code,'');
      end if;
      if v_batch is null then raise exception 'Product Group % requires a Batch',v_group_code; end if;
    elsif v_entry='EXACT' then
      v_product_code:=nullif(trim(coalesce(v_item->>'productCode','')),'');
      if v_product_code is null or not exists(select 1 from public.products p where p.product_code=v_product_code and p.active=true) then
        raise exception 'Product % is invalid',coalesce(v_product_code,'');
      end if;
    else
      raise exception 'Invalid line Entry Type: %',v_entry;
    end if;

    v_subtotal:=v_subtotal+(v_qty*v_unit_price);
    v_line_no:=v_line_no+1;
  end loop;

  if v_line_no=0 then raise exception 'Purchase quantities are empty'; end if;
  v_discount:=least(v_discount,v_subtotal);
  v_grand:=greatest(v_subtotal-v_discount,0);
  v_amount_paid:=least(v_amount_paid,v_grand);

  if v_payment_method in ('Cash','Bank') then v_amount_paid:=v_grand; end if;
  if v_payment_method='Credit' then v_amount_paid:=0; end if;
  v_outstanding:=greatest(v_grand-v_amount_paid,0);
  v_status:=case when v_outstanding<=0 then 'Paid' when v_amount_paid>0 then 'Processing' else 'Unpaid' end;

  if v_payment_method in ('Bank','Partially Paid in Bank') then
    if v_bank is null then raise exception 'Payment Bank is required'; end if;
    if v_tx is null then raise exception 'Transaction ID is required for Bank payment'; end if;
  end if;
  -- A registered transfer can fund multiple invoices until its balance is
  -- consumed. Manual/unregistered transaction IDs remain strictly unique.
  if v_tx is not null
     and exists(select 1 from public.payments p where lower(trim(p.transaction_id))=lower(v_tx))
     and not (v_payment_method in ('Bank','Partially Paid in Bank')
       and v_customer_id is not null and exists(
         select 1 from public.bb_verified_bank_transactions r
         join public.bb_bank_balance_snapshot b on b.transaction_id=r.transaction_id
         where lower(trim(r.transaction_id))=lower(v_tx)
           and b.customer_id=v_customer_id
           and r.status='AVAILABLE' and b.remaining_amount>0
       ))
  then
    raise exception 'Transaction ID already exists';
  end if;

  insert into public.invoices(
    invoice_id,invoice_no,invoice_date,customer_id,customer_name_snapshot,
    salesperson_staff_id,salesperson_name_snapshot,payment_method,currency,exchange_rate,
    subtotal,discount,grand_total,amount_paid,change_amount,outstanding,status,note,due_date,
    bank_payment,bank_reference,credit_amount,batch_number,location_code,shipping_to_legacy
  ) values (
    v_invoice_id,v_invoice_no,v_invoice_date,v_customer_id,v_customer_name,
    v_salesperson_staff_id,v_salesperson_name,v_payment_method,v_currency,v_exchange_rate,
    v_subtotal,v_discount,v_grand,v_amount_paid,0,v_outstanding,v_status,v_note,v_due_date,
    v_bank,v_tx,v_outstanding,v_batch,v_location_code,v_shipping
  );

  v_line_no:=0;
  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_entry:=upper(trim(coalesce(v_item->>'entryType','EXACT')));
    v_qty:=greatest(coalesce(nullif(v_item->>'qty','')::numeric,0),0);
    if v_qty<=0 then continue; end if;
    v_unit_price:=greatest(coalesce(nullif(v_item->>'unitPrice','')::numeric,0),0);
    v_line_total:=v_qty*v_unit_price;
    v_line_no:=v_line_no+1;
    v_client_line_id:=trim(coalesce(v_item->>'lineId',''));
    v_line_id:=case when v_client_line_id<>'' and not exists(select 1 from public.invoice_lines where line_id=v_client_line_id)
                    then v_client_line_id
                    else 'LINE-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' || v_line_no::text || '-' || substr(md5(random()::text),1,5)
               end;
    v_product_name:=nullif(trim(coalesce(v_item->>'productName','')),'');
    v_barcode:=nullif(trim(coalesce(v_item->>'productBarcode','')),'');
    v_unit:=nullif(trim(coalesce(v_item->>'unit','')),'');
    v_alloc:=null;

    /* ========================================================
       DIRECT SALE SOURCE ALLOCATION V1
       ======================================================== */

    if

      v_batch is null

      and

      jsonb_typeof(
        v_item->'stockAllocations'
      )
      =
      'array'

      and

      jsonb_array_length(
        v_item->'stockAllocations'
      )
      >
      0

    then

      v_alloc :=
        v_item->'stockAllocations';

    end if;

    -- Batch Exact stock source allocations preserve the operator's explicit split.
    -- Direct Sale retains its existing handling; Group lines remain legacy allocated.
    if v_batch is not null and v_entry='EXACT' and v_item ? 'stockAllocations' then
      if jsonb_typeof(v_item->'stockAllocations') <> 'array'
         or jsonb_array_length(v_item->'stockAllocations') = 0 then
        raise exception 'Batch line requires Purchased or Zero-Cost allocation';
      end if;
      v_alloc := (
        select jsonb_agg(jsonb_build_object(
          'productCode',trim(coalesce(v_item->>'productCode','')),
          'source',upper(trim(coalesce(e.value->>'source',''))),
          'qty',e.value->'qty'))
        from jsonb_array_elements(v_item->'stockAllocations') e
      );
    end if;

    if v_entry='EXACT' then
      v_product_code:=trim(coalesce(v_item->>'productCode',''));
      v_group_code:=null;
      v_display_code:=v_product_code;
      if v_product_name is null or v_barcode is null or v_unit is null then
        select coalesce(v_product_name,p.product_name),coalesce(v_barcode,p.barcode),coalesce(v_unit,p.unit)
        into v_product_name,v_barcode,v_unit
        from public.products p where p.product_code=v_product_code;
      end if;
    else
      v_product_code:=null;
      v_group_code:=trim(coalesce(v_item->>'productGroupCode',v_item->>'productCode'));
      v_display_code:=v_group_code;
      if v_product_name is null then select g.group_name into v_product_name from public.product_groups g where g.group_code=v_group_code; end if;

      v_alloc:='[]'::jsonb;
      v_need:=v_qty;
      for v_r in
        select r.product_code,greatest(r.difference_qty,0) as available
        from public.v_batch_reconciliation r
        join public.product_group_mapping m
          on m.product_code=r.product_code
         and m.group_code=v_group_code
         and m.use_group=true
         and lower(m.status)='active'
        where r.batch_id=v_batch
        order by r.product_code
      loop
        exit when v_need<=0.0000001;
        v_take:=least(v_need,v_r.available);
        if v_take>0 then
          v_alloc:=v_alloc || jsonb_build_array(jsonb_build_object('productCode',v_r.product_code,'qty',v_take));
          v_need:=v_need-v_take;
        end if;
      end loop;
      if v_need>0.0000001 then
        raise exception 'Batch % does not have enough remaining stock for Group % (short by %)',v_batch,v_group_code,v_need;
      end if;
    end if;

    insert into public.invoice_lines(
      line_id,invoice_id,invoice_no_snapshot,line_no,entry_type,product_code,product_group_code,
      display_product_code,product_name_snapshot,product_barcode_snapshot,product_note,qty,unit_snapshot,
      unit_price,line_total,stock_allocation_json
    ) values (
      v_line_id,v_invoice_id,v_invoice_no,v_line_no,v_entry,v_product_code,v_group_code,
      v_display_code,v_product_name,v_barcode,nullif(trim(coalesce(v_item->>'productNote','')),''),v_qty,v_unit,
      v_unit_price,v_line_total,v_alloc
    );
  end loop;

  if p_payment is not null and jsonb_typeof(p_payment)='object' and v_amount_paid>0 then
    v_payment_amount:=least(greatest(coalesce(nullif(p_payment->>'amount','')::numeric,v_amount_paid),0),v_amount_paid);
    if v_payment_amount>0 then
      v_payment_method_normalized:=case when v_payment_method in ('Bank','Partially Paid in Bank') then 'Bank' else 'Cash' end;
      v_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
      insert into public.payments(
        payment_id,invoice_id,invoice_no_snapshot,payment_date,customer_id,customer_name_snapshot,
        location_code,salesperson_staff_id,salesperson_name_snapshot,payment_method,bank_payment,
        bank_reference,currency,exchange_rate,amount,note,transaction_id,payment_source
      ) values (
        v_payment_id,v_invoice_id,v_invoice_no,v_invoice_date,v_customer_id,v_customer_name,
        v_location_code,v_salesperson_staff_id,v_salesperson_name,v_payment_method_normalized,
        case when v_payment_method_normalized='Bank' then v_bank else null end,
        case when v_payment_method_normalized='Bank' then v_tx else null end,
        v_currency,v_exchange_rate,v_payment_amount,
        coalesce(nullif(trim(coalesce(p_payment->>'note','')),''),'Initial invoice payment'),
        case when v_payment_method_normalized='Bank' then v_tx else null end,'Invoice'
      );
    end if;
  end if;

  return jsonb_build_object(
    'success',true,
    'invoiceId',v_invoice_id,
    'invoiceNo',v_invoice_no,
    'paymentId',v_payment_id,
    'subtotal',v_subtotal,
    'grandTotal',v_grand,
    'amountPaid',v_amount_paid,
    'outstanding',v_outstanding,
    'status',v_status
  );
exception
  when unique_violation then
    if position('uq_payments_transaction_id_normalized' in sqlerrm)>0 then
      raise exception 'Transaction ID already exists';
    elsif position('uq_invoices_invoice_no_customer_id' in sqlerrm)>0 then
      raise exception 'Invoice No. % already exists for this Customer',v_invoice_no;
    elsif position('invoices_invoice_no_key' in sqlerrm)>0 then
      raise exception 'Invoice No. % already exists',v_invoice_no;
    else
      raise;
    end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_bundle_core_access_v1(p_invoice jsonb, p_payment jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_batch text := nullif(trim(coalesce(p_invoice->>'batchNumber','')),'');
begin
  if not public.bb_has_sales_write() then
    raise exception 'BIG BROTHER sales write access denied';
  end if;

  if v_batch is not null then
    perform pg_advisory_xact_lock(hashtext('BB_BATCH_ALLOC_' || v_batch));
  end if;

  return public.bb_sales_save_invoice_bundle_core_v1(p_invoice,p_payment);
end;
$function$;

CREATE OR REPLACE FUNCTION public.bb_sales_check_invoice_customer(p_invoice_no text, p_customer_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice_no text:=trim(coalesce(p_invoice_no,''));
  v_customer_id text:=nullif(trim(coalesce(p_customer_id,'')),'');
  v_exists boolean:=false;
begin
  if not public.bb_is_active_user() then
    raise exception 'BIG BROTHER access denied';
  end if;

  if v_invoice_no='' then
    raise exception 'Invoice No. is required';
  end if;

  if v_customer_id is null then
    return jsonb_build_object(
      'success',true,
      'exists',false,
      'customerId','',
      'invoiceNo',v_invoice_no,
      'rule','INVOICE_NO_PLUS_CUSTOMER_ID'
    );
  end if;

  select exists(
    select 1
    from public.invoices i
    where lower(trim(i.invoice_no))=lower(v_invoice_no)
      and i.customer_id=v_customer_id
  )
  into v_exists;

  return jsonb_build_object(
    'success',true,
    'exists',v_exists,
    'customerId',v_customer_id,
    'invoiceNo',v_invoice_no,
    'rule','INVOICE_NO_PLUS_CUSTOMER_ID'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_bundle(p_invoice jsonb, p_payment jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_location text:=trim(coalesce(p_invoice->>'locationCode',''));
begin
  if not public.bb_has_module_access('invoice_generator','create') then raise exception 'Invoice Generator create access denied'; end if;
  if not public.bb_has_location_access(v_location) then raise exception 'Invoice location access denied'; end if;
  return public.bb_sales_save_invoice_bundle_core_access_v1(p_invoice,p_payment);
end;$function$;

CREATE OR REPLACE FUNCTION public.bb_sales_save_invoice_split_payment(p_invoice jsonb, p_payment jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_location text:=trim(coalesce(p_invoice->>'locationCode',''));
  v_method text:=trim(coalesce(p_invoice->>'paymentMethod',''));
  v_bank text:=nullif(trim(coalesce(p_invoice->>'paymentBank','')),'');
  v_tx text:=nullif(trim(coalesce(p_invoice->>'transactionId','')),'');
  v_currency text:=upper(trim(coalesce(p_invoice->>'currency','USD')));
  v_cash numeric:=greatest(coalesce(nullif(p_payment->>'cashAmount','')::numeric,0),0);
  v_bank_amount numeric:=greatest(coalesce(nullif(p_payment->>'bankAmount','')::numeric,0),0);
  v_invoice_payload jsonb;
  v_cash_payload jsonb;
  v_result jsonb;
  v_invoice public.invoices%rowtype;
  v_bank_payment_id text;
  v_cash_payment_id text;
begin
  if not public.bb_has_module_access('invoice_generator','create') then
    raise exception 'Invoice Generator create access denied';
  end if;

  if not public.bb_has_location_access(v_location) then
    raise exception 'Invoice location access denied';
  end if;

  if v_method<>'Cash + Bank' then
    raise exception 'Cash + Bank payment method is required';
  end if;

  if v_cash<=0 then
    raise exception 'Cash Amount must be greater than 0';
  end if;

  if v_bank_amount<=0 then
    raise exception 'Bank Amount must be greater than 0';
  end if;

  if v_bank is null then
    raise exception 'Payment Bank is required';
  end if;

  if v_tx is null then
    raise exception 'Transaction ID is required for the Bank portion';
  end if;

  if v_currency not in ('USD','KHR') then
    raise exception 'Currency must be USD or KHR';
  end if;

  -- Permit verified balances to be split across invoices only while funds
  -- remain for the very same customer. The payment trigger checks the amount.
  if exists(
    select 1 from public.payments p
    where lower(trim(coalesce(p.transaction_id,'')))=lower(v_tx)
  ) and not exists(
    select 1 from public.bb_verified_bank_transactions r
    join public.bb_bank_balance_snapshot b on b.transaction_id=r.transaction_id
    where lower(trim(r.transaction_id))=lower(v_tx)
      and b.customer_id=nullif(trim(coalesce(p_invoice->>'customerId','')),'')
      and r.status='AVAILABLE' and b.remaining_amount>0
  ) then
    raise exception 'Transaction ID already exists';
  end if;

  v_invoice_payload :=
    p_invoice
    || jsonb_build_object(
         'paymentMethod','Cash',
         -- The interim cash step must not claim the existing bank transfer.
         -- The bank payment below carries the true transaction ID, and the
         -- finished invoice restores it after the bank allocation succeeds.
         'transactionId','',
         'bankReference','',
         'paymentBank','',
         'amountPaid',coalesce(nullif(p_invoice->>'grandTotal','')::numeric,0),
         'creditAmount',0,
         'outstanding',0,
         'status','Paid'
       );

  v_cash_payload :=
    coalesce(p_payment,'{}'::jsonb)
    || jsonb_build_object(
         'paymentMethod','Cash',
         'amount',v_cash,
         'bankPayment','',
         'transactionId','',
         'bankReference','',
         'note','Initial invoice split payment - Cash'
       );

  v_result :=
    public.bb_sales_save_invoice_bundle_core_access_v1(
      v_invoice_payload,
      v_cash_payload
    );

  select *
  into v_invoice
  from public.invoices i
  where i.invoice_id=v_result->>'invoiceId'
  for update;

  if not found then
    raise exception 'Split payment invoice was not created';
  end if;

  if abs((v_cash+v_bank_amount)-v_invoice.grand_total)
     > (case when v_invoice.currency='KHR' then 0.5 else 0.005 end)
  then
    raise exception
      'Cash Amount + Bank Amount must equal Grand Total (% + % <> %)',
      v_cash,
      v_bank_amount,
      v_invoice.grand_total;
  end if;

  v_cash_payment_id:=nullif(trim(coalesce(v_result->>'paymentId','')),'');

  v_bank_payment_id :=
    public.bb_next_prefixed_id(
      'public.payments'::regclass,
      'payment_id',
      'PAY',
      4
    );

  insert into public.payments(
    payment_id,
    invoice_id,
    invoice_no_snapshot,
    payment_date,
    customer_id,
    customer_name_snapshot,
    location_code,
    salesperson_staff_id,
    salesperson_name_snapshot,
    payment_method,
    bank_payment,
    bank_reference,
    currency,
    exchange_rate,
    amount,
    note,
    transaction_id,
    payment_source
  )
  values(
    v_bank_payment_id,
    v_invoice.invoice_id,
    v_invoice.invoice_no,
    v_invoice.invoice_date,
    v_invoice.customer_id,
    v_invoice.customer_name_snapshot,
    v_invoice.location_code,
    v_invoice.salesperson_staff_id,
    v_invoice.salesperson_name_snapshot,
    'Bank',
    v_bank,
    v_tx,
    v_invoice.currency,
    v_invoice.exchange_rate,
    v_bank_amount,
    'Initial invoice split payment - Bank',
    v_tx,
    'Invoice'
  );

  update public.invoices
  set
    payment_method='Cash + Bank',
    amount_paid=grand_total,
    outstanding=0,
    credit_amount=0,
    status='Paid',
    bank_payment=v_bank,
    bank_reference=v_tx
  where invoice_id=v_invoice.invoice_id;

  return
    v_result
    || jsonb_build_object(
         'paymentMethod','Cash + Bank',
         'paymentIds',jsonb_build_array(v_cash_payment_id,v_bank_payment_id),
         'cashPaymentId',v_cash_payment_id,
         'bankPaymentId',v_bank_payment_id,
         'splitCashAmount',v_cash,
         'splitBankAmount',v_bank_amount,
         'amountPaid',v_invoice.grand_total,
         'outstanding',0,
         'status','Paid'
       );
exception
  when unique_violation then
    if position('uq_payments_transaction_id_normalized' in sqlerrm)>0 then
      raise exception 'Transaction ID already exists';
    else
      raise;
    end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.bb_sales_verify_invoice_save(p_invoice_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_invoice public.invoices%rowtype;
begin
 if not public.bb_is_active_user()
    or not public.bb_has_module_access('invoice_generator','create') then
   raise exception 'Invoice verification access denied';
 end if;
 if length(trim(coalesce(p_invoice_id,'')))<8 then raise exception 'Invalid invoice verification ID'; end if;
 select * into v_invoice from public.invoices where invoice_id=trim(p_invoice_id);
 if not found then return jsonb_build_object('success',true,'found',false); end if;
 if not (public.bb_is_admin() or public.bb_has_location_access(v_invoice.location_code)) then
   raise exception 'Invoice verification location access denied';
 end if;
 return jsonb_build_object('success',true,'found',true,'invoiceId',v_invoice.invoice_id,
   'invoiceNo',v_invoice.invoice_no,'locationCode',v_invoice.location_code);
end $function$;
