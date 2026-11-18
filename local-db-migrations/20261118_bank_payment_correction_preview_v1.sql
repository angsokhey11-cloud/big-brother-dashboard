-- LOCAL BRAIN V5/V6: preview-only payment correction.
-- Cloud can atomically replace a payment, but V3.4 synchronization has not
-- been verified to propagate the original payment deletion plus reversal.
-- Do not enable local writes until that exact replay is verified.
-- Apply via approved Code Sync; no business records changed.
create or replace function public.bb_sales_history_correct_bank_payment_v1(p_payload jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare
 v_id text:=trim(coalesce(p_payload->>'invoiceId',''));
 v_method text:=trim(coalesce(p_payload->>'method',''));
 v_reason text:=trim(coalesce(p_payload->>'reason',''));
 v_tid text:=upper(trim(coalesce(p_payload->>'transactionId','')));
 v_apply boolean:=coalesce((p_payload->>'apply')::boolean,false);
 i public.invoices%rowtype;
 p public.payments%rowtype;
 a public.bb_bank_balance_allocations%rowtype;
 old_reg public.bb_verified_bank_transactions%rowtype;
 new_reg public.bb_verified_bank_transactions%rowtype;
 v_old jsonb; v_new jsonb; v_token text;
 v_remaining numeric; v_cash numeric:=0; v_bank numeric:=0; v_paid numeric; v_out numeric; v_tol numeric; v_rate numeric;
 v_count integer; v_ledger numeric; v_expected_bank numeric; v_bank_name text;
 v_payment_id text; v_audit_id text; v_admin text; v_status text; v_lock text;
begin
 if auth.uid() is null or not public.bb_is_admin() or not public.bb_has_module_access('invoice_history','edit')
 then raise exception 'Admin Invoice History edit permission is required'; end if;
 if v_apply then raise exception 'Local Brain payment correction is preview-only until payment replacement synchronization is verified. Apply corrections in Cloud Invoice History.';end if;
 select * into i from public.invoices where invoice_id=v_id;
 if not found then raise exception 'Invoice not found'; end if;
 v_tol:=case when i.currency='KHR' then 0.5 else 0.005 end;
 if i.payment_method<>'Bank' or i.status<>'Paid' or i.grand_total<=0
 or abs(i.amount_paid-i.grand_total)>v_tol or abs(i.outstanding)>v_tol
 or abs(i.change_amount)>v_tol or coalesce(i.reversal_amount,0)<>0
 or i.currency not in ('USD','KHR') or i.exchange_rate<=0 or i.migration_review_required
 then raise exception 'Only unreversed, fully paid original Bank invoices with a registered balance are supported'; end if;

 select count(*) into v_count from public.payments where invoice_id=v_id;
 if v_count<>1 then raise exception 'Multiple or later payments exist; use the related accounting workflow first'; end if;
 select * into p from public.payments where invoice_id=v_id;
 if lower(coalesce(p.payment_source,''))<>'invoice' or p.payment_method<>'Bank'
 or p.customer_id is distinct from i.customer_id or p.currency<>i.currency
 or abs(p.amount-i.grand_total)>v_tol or p.migration_review_required
 then raise exception 'Original bank payment does not reconcile to the invoice'; end if;
 select count(*) into v_count from public.bb_bank_balance_allocations where payment_id=p.payment_id and reversed_at is null;
 if v_count<>1 then raise exception 'Exactly one original active bank allocation is required; multi-source or manual bank payments are not supported'; end if;
 select * into a from public.bb_bank_balance_allocations where payment_id=p.payment_id and reversed_at is null;
 if a.payment_source<>'INVOICE' or a.invoice_currency<>i.currency or abs(a.applied_invoice_amount-p.amount)>v_tol
 or upper(trim(coalesce(p.transaction_id,'')))<>upper(trim(a.transaction_id))
 then raise exception 'Bank allocation does not reconcile to this payment'; end if;
 select * into old_reg from public.bb_verified_bank_transactions where transaction_id=a.transaction_id;
 if not found or old_reg.status not in ('AVAILABLE','USED') then raise exception 'Original bank receipt unavailable or cancelled'; end if;
 if exists(select 1 from public.sales_returns where invoice_id=v_id)
 or exists(select 1 from public.payment_allocations where invoice_id=v_id or payment_id=p.payment_id)
 or exists(select 1 from public.ar_request_allocations where invoice_id=v_id)
 or exists(select 1 from public.ar_payment_requests where payment_id=p.payment_id)
 or exists(select 1 from public.daily_cash_close_invoices where invoice_id=v_id)
 or exists(select 1 from public.daily_cash_request_invoices where invoice_id=v_id)
 or exists(select 1 from public.daily_receivable_cash_collections where invoice_id=v_id or payment_id=p.payment_id)
 or exists(select 1 from public.company_deposits where payment_id=p.payment_id)
 or exists(select 1 from public.telegram_ar_jobs where payment_id=p.payment_id)
 then raise exception 'This invoice/payment has linked collection, deposit, return or A/R history; correct that workflow first'; end if;
 select old_reg.amount-coalesce(sum(applied_bank_amount),0) into v_remaining
 from public.bb_bank_balance_allocations where transaction_id=a.transaction_id and reversed_at is null;
 if v_remaining<-(case when old_reg.currency='KHR' then 0.5 else 0.005 end) then raise exception 'Original bank receipt is overallocated; audit required'; end if;
 v_old:=jsonb_build_object('invoice',to_jsonb(i),'payment',to_jsonb(p),'allocation',to_jsonb(a));
 v_token:=md5(v_old::text);
 if not v_apply then
  return jsonb_build_object('invoiceId',i.invoice_id,'invoiceNo',i.invoice_no,'customerId',i.customer_id,'currency',i.currency,'grandTotal',i.grand_total,'invoiceDate',i.invoice_date,'dueDate',i.due_date,'transactionId',a.transaction_id,'bankCurrency',old_reg.currency,'releaseAmount',a.applied_bank_amount,'remainingBefore',greatest(v_remaining,0),'remainingAfter',v_remaining+a.applied_bank_amount,'token',v_token,'previewOnly',true,'message','Local Brain payment correction is preview-only until the old payment replacement and reversal can synchronize safely. Apply the correction in Cloud Invoice History.');
 end if;
 raise exception 'Local Brain payment correction is preview-only';
end;
$fn$;
revoke all on function public.bb_sales_history_correct_bank_payment_v1(jsonb) from public,anon,authenticated;
grant execute on function public.bb_sales_history_correct_bank_payment_v1(jsonb) to authenticated;

DO $verify$
BEGIN
 IF has_function_privilege('anon','public.bb_sales_history_correct_bank_payment_v1(jsonb)','EXECUTE')
 OR NOT has_function_privilege('authenticated','public.bb_sales_history_correct_bank_payment_v1(jsonb)','EXECUTE')
 OR position('previewOnly' in pg_get_functiondef('public.bb_sales_history_correct_bank_payment_v1(jsonb)'::regprocedure))=0
 THEN RAISE EXCEPTION 'Local payment correction preview verification failed'; END IF;
 RAISE NOTICE 'LOCAL_PAYMENT_CORRECTION_PREVIEW_READY: no business records modified';
END $verify$;
