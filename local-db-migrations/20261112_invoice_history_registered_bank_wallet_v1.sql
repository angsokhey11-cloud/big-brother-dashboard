-- BIG BROTHER | Invoice History uses an Admin-registered bank wallet, atomically.
-- Only new original Invoice bank usage is supported. Never mutate a payment
-- already posted to a bank wallet or a cash collection that has been closed.
-- Existing Invoice History correction function remains unchanged.
CREATE OR REPLACE FUNCTION public.bb_sales_history_update_invoice_registered_wallet_v1(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
 v_id text:=btrim(coalesce(p_payload->>'invoiceId',''));
 v_tid text:=upper(btrim(coalesce(p_payload->>'transactionId',p_payload->>'bankReference','')));
 v_invoice public.invoices%ROWTYPE;
 v_reg public.bb_verified_bank_transactions%ROWTYPE;
 v_method text:=btrim(coalesce(p_payload->>'paymentMethod',''));
 v_bank text:=btrim(coalesce(p_payload->>'bankPayment',''));
 v_customer text:=btrim(coalesce(p_payload->>'customerId',''));
 v_currency text:=upper(btrim(coalesce(p_payload->>'currency','')));
 v_grand numeric;
 v_requested numeric;
 v_exchange numeric;
 v_rate numeric;
 v_debit numeric;
 v_available numeric;
 v_old_cash_id text;
 v_count int;
 v_result jsonb;
 v_active_count int;
 v_applied numeric;
 v_tol numeric;
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_admin()
   OR NOT public.bb_has_module_access('invoice_history','edit')
 THEN RAISE EXCEPTION 'Admin Invoice History edit permission is required'; END IF;
 IF v_id='' OR length(v_tid)<4 OR length(v_tid)>160 OR v_customer=''
 THEN RAISE EXCEPTION 'Invoice, customer and registered bank transaction are required';END IF;
 IF v_method NOT IN ('Bank','Cash + Bank','Partially Paid in Bank')
 THEN RAISE EXCEPTION 'Select Bank, Cash + Bank or Partially Paid in Bank to use a registered balance';END IF;
 IF v_bank='' THEN RAISE EXCEPTION 'Receiving bank name is required'; END IF;
 IF upper(btrim(coalesce(p_payload->>'bankReference','')))<>v_tid
 THEN RAISE EXCEPTION 'Selected registered bank ID does not match invoice Bank Transaction ID';END IF;

 SELECT * INTO v_invoice FROM public.invoices i WHERE i.invoice_id=v_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invoice not found';END IF;
 IF v_invoice.customer_id<>v_customer OR v_invoice.currency<>v_currency
 THEN RAISE EXCEPTION 'Registered bank correction cannot change the invoice customer or currency';END IF;
 IF coalesce(v_invoice.reversal_amount,0)<>0
  OR EXISTS(SELECT 1 FROM public.sales_returns WHERE invoice_id=v_id)
 THEN RAISE EXCEPTION 'Reversed invoice cannot be converted to a registered bank payment';END IF;
 IF v_invoice.payment_method NOT IN ('Cash','Credit')
 THEN RAISE EXCEPTION 'Only original Cash or Credit invoices can use this correction; existing Bank/split payments require an audited reversal';END IF;
 IF v_invoice.payment_method='Cash' AND v_method='Partially Paid in Bank'
 THEN RAISE EXCEPTION 'To correct existing Cash choose Bank or Cash + Bank. Partial Bank is available for original Credit invoices'; END IF;
 IF EXISTS(SELECT 1 FROM public.payment_allocations WHERE invoice_id=v_id)
  OR EXISTS(SELECT 1 FROM public.payments p WHERE p.invoice_id=v_id
     AND lower(coalesce(p.payment_source,''))<>'invoice')
 THEN RAISE EXCEPTION 'Invoice already has later A/R payments. Bank correction is blocked';END IF;
 IF EXISTS(SELECT 1 FROM public.daily_cash_close_invoices WHERE invoice_id=v_id)
  OR EXISTS(SELECT 1 FROM public.daily_cash_request_invoices WHERE invoice_id=v_id)
  OR EXISTS(SELECT 1 FROM public.daily_receivable_cash_collections WHERE invoice_id=v_id)
 THEN RAISE EXCEPTION 'Invoice appears in Daily Cash collection/history. Correct cash collection through its approved accounting workflow';END IF;
 IF EXISTS(SELECT 1 FROM public.payments p
   JOIN public.bb_bank_balance_allocations a ON a.payment_id=p.payment_id
   WHERE p.invoice_id=v_id)
 THEN RAISE EXCEPTION 'An existing bank wallet was already applied to this invoice';END IF;

 SELECT count(*),min(p.payment_id) INTO v_count,v_old_cash_id
 FROM public.payments p
 WHERE p.invoice_id=v_id AND lower(coalesce(p.payment_source,''))='invoice';
 IF v_invoice.payment_method='Cash' THEN
   IF v_count<>1 OR NOT EXISTS(SELECT 1 FROM public.payments p
        WHERE p.payment_id=v_old_cash_id AND lower(trim(coalesce(p.payment_method,'')))='cash'
          AND p.transaction_id IS NULL)
   THEN RAISE EXCEPTION 'Cash invoice must have exactly one untouched original cash payment';END IF;
 ELSE
   IF v_count<>0 THEN RAISE EXCEPTION 'Credit invoice already has an original payment';END IF;
 END IF;

 v_grand:=nullif(p_payload->>'grandTotal','')::numeric;
 v_exchange:=nullif(p_payload->>'exchangeRate','')::numeric;
 v_tol:=case when v_currency='KHR' then 0.5 else 0.005 end;
 IF v_grand IS NULL OR v_grand<=0 OR abs(v_grand-v_invoice.grand_total)>v_tol
 THEN RAISE EXCEPTION 'Registered bank correction cannot change the original invoice total. Save that correction first';END IF;
 IF v_method='Cash + Bank' THEN
   v_requested:=coalesce(nullif(p_payload->>'splitBankAmount','')::numeric,0);
   IF v_requested<=0
     OR coalesce(nullif(p_payload->>'splitCashAmount','')::numeric,0)<=0
     OR abs(v_requested+coalesce(nullif(p_payload->>'splitCashAmount','')::numeric,0)-v_grand)>v_tol
   THEN RAISE EXCEPTION 'Cash + Bank split must fully equal invoice total';END IF;
 ELSIF v_method='Partially Paid in Bank' THEN
   v_requested:=coalesce(nullif(p_payload->>'amountPaid','')::numeric,0);
 ELSE v_requested:=v_grand;
 END IF;
 IF v_requested<=0 OR v_requested>v_grand+v_tol
 THEN RAISE EXCEPTION 'Bank amount must be positive and no greater than invoice total';END IF;

 -- All bank uses and share edits take the same per-transaction advisory lock.
 PERFORM pg_advisory_xact_lock(hashtext('BB_BANK_TX_'||v_tid));
 SELECT * INTO v_reg FROM public.bb_verified_bank_transactions t
 WHERE t.transaction_id=v_tid FOR UPDATE;
 IF NOT FOUND OR v_reg.status<>'AVAILABLE'
 THEN RAISE EXCEPTION 'Choose an available Admin-registered bank receipt';END IF;
 IF v_reg.bank_name IS NOT NULL AND lower(btrim(v_reg.bank_name))<>lower(v_bank)
 THEN RAISE EXCEPTION 'Receiving Bank name must match registered receipt';END IF;
 IF v_reg.invoice_currency IS NOT NULL AND v_reg.invoice_currency<>v_currency
 THEN RAISE EXCEPTION 'Registered balance is not approved for this invoice currency';END IF;
 IF v_exchange IS NULL OR v_exchange<=0 THEN RAISE EXCEPTION 'Valid exchange rate required'; END IF;
 v_rate:=case when v_reg.currency=v_currency then 1
    when coalesce(v_reg.approved_exchange_rate,0)>1 then v_reg.approved_exchange_rate
    else v_exchange end;
 IF v_reg.currency<>v_currency AND (v_rate<=1 OR abs(v_exchange-v_rate)>0.000001)
 THEN RAISE EXCEPTION 'Invoice exchange rate must match approved bank conversion'; END IF;
 v_debit:=case when v_reg.currency=v_currency then v_requested
    when v_reg.currency='KHR' then v_requested*v_rate
    else v_requested/v_rate end;
 SELECT b.remaining_amount INTO v_available FROM public.bb_bank_balance_snapshot b
 WHERE b.transaction_id=v_tid AND b.customer_id=v_customer AND b.status='AVAILABLE';
 IF v_available IS NULL OR v_debit>v_available+(case when v_reg.currency='KHR' then 0.5 else 0.005 end)
 THEN RAISE EXCEPTION 'Customer registered bank balance is insufficient or belongs to another outlet';END IF;

 -- Removing an original uncollected Cash payment is necessary: changing its
 -- method in place would bypass the existing BEFORE INSERT bank debit guard.
 -- On ANY error, PostgreSQL rolls back this deletion and the entire edit.
 IF v_old_cash_id IS NOT NULL THEN
   DELETE FROM public.payments p WHERE p.payment_id=v_old_cash_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Original Cash payment changed during correction';END IF;
 END IF;

 -- The unchanged existing correction routine updates Invoice, Stock, A/R
 -- references and creates the new original Bank payment. Its BEFORE INSERT
 -- bank trigger debits EXACTLY this customer's approved outlet share.
 v_result:=public.bb_sales_history_update_invoice(p_payload);

 SELECT count(*),coalesce(sum(a.applied_invoice_amount),0)
 INTO v_active_count,v_applied
 FROM public.bb_bank_balance_allocations a
 JOIN public.payments p ON p.payment_id=a.payment_id
 WHERE p.invoice_id=v_id AND a.transaction_id=v_tid AND a.reversed_at IS NULL
   AND lower(coalesce(p.payment_source,''))='invoice';
 IF v_active_count<>1 OR abs(v_applied-v_requested)>v_tol THEN
   RAISE EXCEPTION 'Bank wallet was not debited exactly once; invoice correction rolled back';
 END IF;
 RETURN v_result||jsonb_build_object(
   'registeredBankApplied',true,
   'registeredBankTransactionId',v_tid,
   'registeredBankInvoiceAmount',v_applied,
   'registeredBankCurrency',v_currency);
END $fn$;
REVOKE ALL ON FUNCTION public.bb_sales_history_update_invoice_registered_wallet_v1(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_sales_history_update_invoice_registered_wallet_v1(jsonb) TO authenticated;
