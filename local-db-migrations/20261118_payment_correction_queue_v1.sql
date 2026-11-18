-- Local Brain V5/V6 ONLY. Queues authenticated correction intents; no business rows are edited.
-- Install only after the V3.4 queue-aware upload helpers are in place.
create table if not exists private.bb_local_payment_correction_queue_v1(
 request_id uuid primary key,
 invoice_id text not null,
 actor_user_id uuid not null,
 intent jsonb not null,
 preview jsonb not null,
 created_at timestamptz not null default now(),
 completed_at timestamptz
);
create unique index if not exists bb_local_payment_correction_pending_uq_v1 on private.bb_local_payment_correction_queue_v1(invoice_id) where completed_at is null;
alter table private.bb_local_payment_correction_queue_v1 enable row level security;
revoke all on private.bb_local_payment_correction_queue_v1 from public,anon,authenticated;
create or replace function private.bb_local_payment_correction_read_v1(p_payload jsonb)
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
revoke all on function private.bb_local_payment_correction_read_v1(jsonb) from public,anon,authenticated;
create or replace function public.bb_sales_history_correct_bank_payment_v1(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare
 v_id text:=trim(coalesce(p_payload->>'invoiceId',''));
 v_apply boolean:=coalesce((p_payload->>'apply')::boolean,false);
 v_method text:=trim(coalesce(p_payload->>'method',''));
 v_reason text:=trim(coalesce(p_payload->>'reason',''));
 v_tid text:=upper(trim(coalesce(p_payload->>'transactionId','')));
 v_preview jsonb; v_i jsonb; v_p jsonb; v_a jsonb; v_intent jsonb;
 v_rid uuid; q private.bb_local_payment_correction_queue_v1%rowtype;
 v_total numeric; v_bank numeric:=0; v_cash numeric:=0; v_scale int;
begin
 if auth.uid() is null or not public.bb_is_admin() or not public.bb_has_module_access('invoice_history','edit')
 then raise exception 'Admin Invoice History edit permission is required';end if;
 if v_id='' then raise exception 'Invoice ID required';end if;
 perform pg_advisory_xact_lock(hashtext('BB_LOCAL_PAYMENT_QUEUE_'||v_id));
 select * into q from private.bb_local_payment_correction_queue_v1 where invoice_id=v_id and completed_at is null;
 if found then
  if v_apply then raise exception 'Payment correction already queued. Upload it before making another request.';end if;
  return q.preview||jsonb_build_object('previewOnly',true,'message','Payment correction queued: '||q.request_id::text||'. Run Local -> Cloud Upload, then Cloud -> Local Refresh. No payment balance has been changed locally.');
 end if;
 if v_apply then
  perform 1 from public.invoices where invoice_id=v_id for update;
  perform 1 from public.payments where invoice_id=v_id for update;
 end if;
 v_preview:=private.bb_local_payment_correction_read_v1(jsonb_build_object('invoiceId',v_id,'apply',false));
 if not v_apply then return v_preview||jsonb_build_object('previewOnly',false,'queuedMode',true,'message','Local correction is queued, not applied immediately. Upload and refresh before using released funds.');end if;
 if p_payload->>'token' is distinct from v_preview->>'token' then raise exception 'Invoice changed; reopen correction';end if;
 if length(v_reason)<3 or length(v_reason)>500 then raise exception 'Enter a correction reason (3–500 characters)';end if;
 v_total:=(v_preview->>'grandTotal')::numeric;
 v_scale:=case when v_preview->>'currency'='KHR' then 0 else 2 end;
 if v_method='Cash' then v_cash:=v_total;
 elsif v_method='Credit' then null;
 elsif v_method='Bank' then v_bank:=v_total;
 elsif v_method='Cash + Bank' then v_bank:=coalesce((p_payload->>'bankAmount')::numeric,0);v_cash:=v_total-v_bank;
  if v_bank<=0 or v_cash<=0 then raise exception 'Both payment portions must be positive';end if;
 elsif v_method='Partially Paid in Bank' then v_bank:=coalesce((p_payload->>'bankAmount')::numeric,0);
  if v_bank<=0 or v_bank>=v_total then raise exception 'Invalid partial bank amount';end if;
 elsif v_method='Partially Paid in Cash' then v_cash:=coalesce((p_payload->>'cashAmount')::numeric,0);
  if v_cash<=0 or v_cash>=v_total then raise exception 'Invalid partial cash amount';end if;
 else raise exception 'Unsupported correction method';end if;
 if v_cash<>round(v_cash,v_scale) or v_bank<>round(v_bank,v_scale) then raise exception 'Invalid currency precision';end if;
 if v_bank>0 and (v_tid='' or v_tid=upper(v_preview->>'transactionId')) then raise exception 'Select a different registered bank receipt';end if;
 if v_total-v_cash-v_bank>0 and v_preview->>'dueDate' is null then raise exception 'Set a valid due date before reopening receivable';end if;
 select to_jsonb(i) into v_i from public.invoices i where invoice_id=v_id;
 select to_jsonb(p) into v_p from public.payments p where invoice_id=v_id;
 select to_jsonb(a) into v_a from public.bb_bank_balance_allocations a where payment_id=v_p->>'payment_id' and reversed_at is null;
 if v_i is null or v_p is null or v_a is null or md5(jsonb_build_object('invoice',v_i,'payment',v_p,'allocation',v_a)::text) is distinct from v_preview->>'token' then raise exception 'Original allocation changed; reopen correction';end if;
 v_rid:=gen_random_uuid();
 v_intent:=jsonb_build_object('requestId',v_rid,'actor',auth.uid(),'invoiceId',v_id,'version','LOCAL_PAYMENT_INTENT_V1','invoice',v_i,'payment',v_p,'allocation',v_a,'replacement',
 jsonb_build_object('method',v_method,'reason',v_reason,'cashAmount',v_cash,'bankAmount',v_bank,'transactionId',case when v_bank>0 then v_tid else '' end));
 insert into private.bb_local_payment_correction_queue_v1(request_id,invoice_id,actor_user_id,intent,preview) values(v_rid,v_id,auth.uid(),v_intent,v_preview);
 return jsonb_build_object('success',true,'queued',true,'requestId',v_rid,'invoiceId',v_id,'message','Queued for Cloud reconciliation. Local payment and bank balance remain unchanged.');
end $f$;
revoke all on function public.bb_sales_history_correct_bank_payment_v1(jsonb) from public,anon,authenticated;
grant execute on function public.bb_sales_history_correct_bank_payment_v1(jsonb) to authenticated;
