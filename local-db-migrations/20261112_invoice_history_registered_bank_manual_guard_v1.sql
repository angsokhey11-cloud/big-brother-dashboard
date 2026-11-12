-- Reject manual re-labeling of registered bank receipts without proper wallet debit.
CREATE OR REPLACE FUNCTION public.bb_sales_history_update_invoice(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    declare
      v_result jsonb;
      v_invoice_id text;
      v_invoice public.invoices%rowtype;
      v_method text;
      v_cash numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'splitCashAmount','')),'')::numeric,0),0);
      v_bank_amount numeric:=greatest(coalesce(nullif(trim(coalesce(p_payload->>'splitBankAmount','')),'')::numeric,0),0);
      v_tolerance numeric:=0.005;
      v_bank_payment text:=nullif(trim(coalesce(p_payload->>'bankPayment','')),'');
      v_bank_reference text:=nullif(trim(coalesce(p_payload->>'bankReference','')),'');
      v_cash_payment_id text;
      v_bank_payment_id text;
      v_keep_payment_id text;
      v_invoice_payment_count integer:=0;
    begin
      if not public.bb_has_module_access('invoice_history','edit') then
        raise exception 'Invoice History edit access denied';
      end if;

      perform set_config('bb.invoice_history_correction','on',true);

      -- Manual history edits must not relabel a registered payment as Bank without
      -- debiting the wallet. Reuse requires the guarded Admin wallet-correction RPC.
      if coalesce(current_setting('bb.history_registered_wallet',true),'')<>'on'
         and trim(coalesce(p_payload->>'paymentMethod','')) in
           ('Bank','Cash + Bank','Partially Paid in Bank')
         and exists(select 1 from public.bb_verified_bank_transactions t
           where upper(trim(t.transaction_id))=
             upper(trim(coalesce(p_payload->>'transactionId',p_payload->>'bankReference',''))))
         and not exists(
           select 1 from public.payments p
           join public.bb_bank_balance_allocations a on a.payment_id=p.payment_id
           where p.invoice_id=trim(coalesce(p_payload->>'invoiceId',''))
             and a.reversed_at is null and upper(trim(a.transaction_id))=
               upper(trim(coalesce(p_payload->>'transactionId',p_payload->>'bankReference','')))
         )
      then raise exception 'Use Registered Bank Balance in Invoice History to debit the selected receipt safely';end if;

      v_result:=public.bb_sales_history_update_invoice_core_access_v1(p_payload);
      v_invoice_id:=trim(coalesce(v_result->>'invoiceId',p_payload->>'invoiceId',''));

      select *
      into v_invoice
      from public.invoices i
      where i.invoice_id=v_invoice_id
      for update;

      if not found then
        raise exception 'Corrected invoice was not found';
      end if;

      v_method:=trim(coalesce(p_payload->>'paymentMethod',v_invoice.payment_method,''));
      v_tolerance:=case when upper(coalesce(v_invoice.currency,'USD'))='KHR' then 0.5 else 0.005 end;

      if v_method='Cash + Bank' then
        if v_cash<=0 then raise exception 'Cash Amount must be greater than 0'; end if;
        if v_bank_amount<=0 then raise exception 'Bank Amount must be greater than 0'; end if;
        if abs((v_cash+v_bank_amount)-coalesce(v_invoice.grand_total,0))>v_tolerance then
          raise exception 'Cash Amount + Bank Amount must equal Grand Total';
        end if;
        if v_bank_payment is null then raise exception 'Bank Payment is required for Cash + Bank'; end if;
        if v_bank_reference is null then raise exception 'Bank Reference / Transaction ID is required for Cash + Bank'; end if;

        if exists(
          select 1 from public.payments p
          where lower(trim(coalesce(p.transaction_id,'')))=lower(v_bank_reference)
            and p.invoice_id<>v_invoice.invoice_id
        ) then
          raise exception 'Transaction ID already exists';
        end if;

        if exists(select 1 from public.payment_allocations pa where pa.invoice_id=v_invoice.invoice_id)
           or exists(
             select 1 from public.payments p
             where p.invoice_id=v_invoice.invoice_id
               and lower(coalesce(p.payment_source,''))<>'invoice'
           ) then
          raise exception 'Cash + Bank correction is not allowed after later receivable payments were applied';
        end if;

        select min(p.payment_id) into v_cash_payment_id
        from public.payments p
        where p.invoice_id=v_invoice.invoice_id
          and lower(coalesce(p.payment_source,''))='invoice'
          and lower(trim(coalesce(p.payment_method,'')))='cash';

        select min(p.payment_id) into v_bank_payment_id
        from public.payments p
        where p.invoice_id=v_invoice.invoice_id
          and lower(coalesce(p.payment_source,''))='invoice'
          and lower(trim(coalesce(p.payment_method,'')))='bank';

        if v_cash_payment_id is null then
          v_cash_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
          insert into public.payments(
            payment_id,invoice_id,invoice_no_snapshot,payment_date,
            customer_id,customer_name_snapshot,location_code,
            salesperson_staff_id,salesperson_name_snapshot,
            payment_method,bank_payment,bank_reference,currency,exchange_rate,
            amount,note,transaction_id,payment_source
          )
          values(
            v_cash_payment_id,v_invoice.invoice_id,v_invoice.invoice_no,v_invoice.invoice_date,
            v_invoice.customer_id,v_invoice.customer_name_snapshot,v_invoice.location_code,
            v_invoice.salesperson_staff_id,v_invoice.salesperson_name_snapshot,
            'Cash',null,null,v_invoice.currency,v_invoice.exchange_rate,
            v_cash,'Corrected from Invoice History - Cash',null,'Invoice'
          );
        else
          update public.payments p
          set invoice_no_snapshot=v_invoice.invoice_no,
              payment_date=v_invoice.invoice_date,
              customer_id=v_invoice.customer_id,
              customer_name_snapshot=v_invoice.customer_name_snapshot,
              location_code=v_invoice.location_code,
              salesperson_staff_id=v_invoice.salesperson_staff_id,
              salesperson_name_snapshot=v_invoice.salesperson_name_snapshot,
              payment_method='Cash',
              bank_payment=null,
              bank_reference=null,
              currency=v_invoice.currency,
              exchange_rate=v_invoice.exchange_rate,
              amount=v_cash,
              note='Corrected from Invoice History - Cash',
              transaction_id=null,
              payment_source='Invoice',
              updated_at=now()
          where p.payment_id=v_cash_payment_id;
        end if;

        if v_bank_payment_id is null then
          v_bank_payment_id:=public.bb_next_prefixed_id('public.payments'::regclass,'payment_id','PAY',4);
          insert into public.payments(
            payment_id,invoice_id,invoice_no_snapshot,payment_date,
            customer_id,customer_name_snapshot,location_code,
            salesperson_staff_id,salesperson_name_snapshot,
            payment_method,bank_payment,bank_reference,currency,exchange_rate,
            amount,note,transaction_id,payment_source
          )
          values(
            v_bank_payment_id,v_invoice.invoice_id,v_invoice.invoice_no,v_invoice.invoice_date,
            v_invoice.customer_id,v_invoice.customer_name_snapshot,v_invoice.location_code,
            v_invoice.salesperson_staff_id,v_invoice.salesperson_name_snapshot,
            'Bank',v_bank_payment,v_bank_reference,v_invoice.currency,v_invoice.exchange_rate,
            v_bank_amount,'Corrected from Invoice History - Bank',v_bank_reference,'Invoice'
          );
        else
          update public.payments p
          set invoice_no_snapshot=v_invoice.invoice_no,
              payment_date=v_invoice.invoice_date,
              customer_id=v_invoice.customer_id,
              customer_name_snapshot=v_invoice.customer_name_snapshot,
              location_code=v_invoice.location_code,
              salesperson_staff_id=v_invoice.salesperson_staff_id,
              salesperson_name_snapshot=v_invoice.salesperson_name_snapshot,
              payment_method='Bank',
              bank_payment=v_bank_payment,
              bank_reference=v_bank_reference,
              currency=v_invoice.currency,
              exchange_rate=v_invoice.exchange_rate,
              amount=v_bank_amount,
              note='Corrected from Invoice History - Bank',
              transaction_id=v_bank_reference,
              payment_source='Invoice',
              updated_at=now()
          where p.payment_id=v_bank_payment_id;
        end if;

        if exists(
          select 1
          from public.payment_allocations pa
          join public.payments p on p.payment_id=pa.payment_id
          where p.invoice_id=v_invoice.invoice_id
            and lower(coalesce(p.payment_source,''))='invoice'
            and p.payment_id not in (v_cash_payment_id,v_bank_payment_id)
        ) then
          raise exception 'Extra original payment rows are already linked and cannot be replaced safely';
        end if;

        delete from public.payments p
        where p.invoice_id=v_invoice.invoice_id
          and lower(coalesce(p.payment_source,''))='invoice'
          and p.payment_id not in (v_cash_payment_id,v_bank_payment_id);

        update public.invoices i
        set payment_method='Cash + Bank',
            amount_paid=i.grand_total,
            outstanding=0,
            credit_amount=0,
            status=case when coalesce(i.reversal_amount,0)>=coalesce(i.grand_total,0)-0.000001 then 'Reversed' else 'Paid' end,
            bank_payment=v_bank_payment,
            bank_reference=v_bank_reference,
            updated_at=now()
        where i.invoice_id=v_invoice.invoice_id;

        v_result:=v_result||jsonb_build_object(
          'paymentMethod','Cash + Bank',
          'cashPaymentId',v_cash_payment_id,
          'bankPaymentId',v_bank_payment_id,
          'splitCashAmount',v_cash,
          'splitBankAmount',v_bank_amount
        );

      elsif v_method in ('Cash','Bank') then
        select count(*) into v_invoice_payment_count
        from public.payments p
        where p.invoice_id=v_invoice.invoice_id
          and lower(coalesce(p.payment_source,''))='invoice';

        if v_invoice_payment_count>1 then
          if exists(select 1 from public.payment_allocations pa where pa.invoice_id=v_invoice.invoice_id)
             or exists(
               select 1 from public.payments p
               where p.invoice_id=v_invoice.invoice_id
                 and lower(coalesce(p.payment_source,''))<>'invoice'
             ) then
            raise exception 'Split payment cannot be collapsed after later receivable payments were applied';
          end if;

          select min(p.payment_id) into v_keep_payment_id
          from public.payments p
          where p.invoice_id=v_invoice.invoice_id
            and lower(coalesce(p.payment_source,''))='invoice'
            and lower(trim(coalesce(p.payment_method,'')))=lower(v_method);

          if v_keep_payment_id is null then
            select min(p.payment_id) into v_keep_payment_id
            from public.payments p
            where p.invoice_id=v_invoice.invoice_id
              and lower(coalesce(p.payment_source,''))='invoice';
          end if;

          if v_method='Bank' then
            if v_bank_payment is null then raise exception 'Bank Payment is required for Bank payment'; end if;
            if v_bank_reference is null then raise exception 'Bank Reference / Transaction ID is required for Bank payment'; end if;

            if exists(
              select 1 from public.payments p
              where lower(trim(coalesce(p.transaction_id,'')))=lower(v_bank_reference)
                and p.invoice_id<>v_invoice.invoice_id
            ) then
              raise exception 'Transaction ID already exists';
            end if;
          end if;

          update public.payments p
          set invoice_no_snapshot=v_invoice.invoice_no,
              payment_date=v_invoice.invoice_date,
              customer_id=v_invoice.customer_id,
              customer_name_snapshot=v_invoice.customer_name_snapshot,
              location_code=v_invoice.location_code,
              salesperson_staff_id=v_invoice.salesperson_staff_id,
              salesperson_name_snapshot=v_invoice.salesperson_name_snapshot,
              payment_method=v_method,
              bank_payment=case when v_method='Bank' then v_bank_payment else null end,
              bank_reference=case when v_method='Bank' then v_bank_reference else null end,
              currency=v_invoice.currency,
              exchange_rate=v_invoice.exchange_rate,
              amount=v_invoice.amount_paid,
              note='Corrected from Invoice History',
              transaction_id=case when v_method='Bank' then v_bank_reference else null end,
              payment_source='Invoice',
              updated_at=now()
          where p.payment_id=v_keep_payment_id;

          delete from public.payments p
          where p.invoice_id=v_invoice.invoice_id
            and lower(coalesce(p.payment_source,''))='invoice'
            and p.payment_id<>v_keep_payment_id;

          update public.invoices i
          set payment_method=v_method,
              bank_payment=case when v_method='Bank' then v_bank_payment else null end,
              bank_reference=case when v_method='Bank' then v_bank_reference else null end,
              updated_at=now()
          where i.invoice_id=v_invoice.invoice_id;
        end if;
      end if;

      return v_result||jsonb_build_object('revision',public.bb_sales_history_revision());
    exception
      when unique_violation then
        if position('uq_payments_transaction_id_normalized' in sqlerrm)>0 then
          raise exception 'Transaction ID already exists';
        else
          raise;
        end if;
    end;
    $function$;
