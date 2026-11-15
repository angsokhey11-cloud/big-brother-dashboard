-- BIG BROTHER V2 CASH REFUND PROOF OF CONCEPT -- SYNTHETIC CI ONLY.
-- NEVER DEPLOY THIS FILE. Functions explicitly REFUSE any database other than
-- bb_stock_v2_sandbox. No bank outgoing, no external payment execution, no real user data.
-- Supports *ONLY* Invoice-originated USD Cash receipts after an Approved DCC
-- and a recorded Reversal. Real mixed Cash/Bank, Credit A/R, exchange and wallet
-- bank allocations require future separate, reviewed integration.
\set ON_ERROR_STOP on

CREATE FUNCTION public.bb_ci_refund_approve_v1(p_key text)
RETURNS text LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' AS $body$
DECLARE v public.bb_ci_refund_requests%rowtype;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'TEST-ONLY REFUND APPROVAL BLOCKED OUTSIDE SYNTHETIC DB';
 END IF;
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.app_users
    WHERE user_id=auth.uid() AND active=true AND lower(role)='admin'
 ) THEN RAISE EXCEPTION 'Refund Admin approval access denied'; END IF;
 SELECT * INTO v FROM public.bb_ci_refund_requests
 WHERE request_key=p_key FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Refund request not found'; END IF;
 IF v.status='Approved' THEN RETURN v.status; END IF;
 IF v.status<>'Pending' THEN RAISE EXCEPTION 'Refund approval status is not Pending'; END IF;
 UPDATE public.bb_ci_refund_requests
 SET status='Approved',approved_by=auth.uid(),approved_at=now()
 WHERE request_key=p_key;
 RETURN 'Approved';
END;
$body$;

CREATE FUNCTION public.bb_ci_refund_execute_v1(p_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' AS $body$
DECLARE
 v public.bb_ci_refund_requests%rowtype;
 inv public.invoices%rowtype;
 paid_cash numeric:=0;
 paid_all numeric:=0;
 already_refunded numeric:=0;
 cap numeric:=0;
 balance numeric:=0;
 entry text;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'TEST-ONLY CASH REFUND BLOCKED OUTSIDE SYNTHETIC DB';
 END IF;
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.app_users
   WHERE user_id=auth.uid() AND active=true AND lower(role)='admin'
 ) THEN RAISE EXCEPTION 'Refund execution Admin access denied'; END IF;
 SELECT * INTO v FROM public.bb_ci_refund_requests
 WHERE request_key=p_key FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Refund request not found'; END IF;
 -- Identical retry returns the existing immutable entry, never spends again.
 IF v.status='Executed' THEN
   IF v.ledger_entry_id IS NULL THEN RAISE EXCEPTION 'Executed refund missing ledger reference'; END IF;
   RETURN jsonb_build_object('success',true,'idempotent',true,
     'refundRequestKey',v.request_key,'ledgerEntryId',v.ledger_entry_id);
 END IF;
 IF v.status<>'Approved' OR v.approved_by IS NULL THEN
   RAISE EXCEPTION 'Refund must be Approved before execution';
 END IF;
 IF v.cash_source='BANK' THEN
   RAISE EXCEPTION 'Bank refund requires verified outgoing bank transaction integration; not implemented';
 END IF;
 IF v.cash_source NOT IN ('CASH_VAULT','DAILY_CASH') THEN
   RAISE EXCEPTION 'Unknown cash refund funding source';
 END IF;
 IF v.amount_usd<=0 THEN RAISE EXCEPTION 'Refund must be greater than zero'; END IF;
 SELECT * INTO inv FROM public.invoices WHERE invoice_id=v.invoice_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invoice not found'; END IF;
 -- Restrict THIS test-only implementation to one-currency Cash-origin invoices
 -- so it cannot accidentally treat mixed/FX receivables as USD cash.
 IF upper(coalesce(inv.currency,''))<>'USD' OR
 lower(trim(coalesce(inv.payment_method,'')))<>'cash' THEN
   RAISE EXCEPTION 'Only original USD Cash invoice supported by isolated test';
 END IF;
 IF NOT EXISTS(
   SELECT 1 FROM public.daily_cash_close_invoices d
   JOIN public.daily_cash_closes c ON c.close_id=d.close_id
   WHERE d.invoice_id=inv.invoice_id
    AND lower(coalesce(c.status,''))='approved'
 ) THEN
   RAISE EXCEPTION 'Refund invoice has no Approved Daily Cash Collection';
 END IF;
 IF coalesce(inv.reversal_amount,0)<=0 THEN
   RAISE EXCEPTION 'Refund requires recorded Reversal before settlement';
 END IF;
 SELECT coalesce(sum(p.amount) FILTER (WHERE
   lower(trim(coalesce(p.payment_method,'')))='cash'
   AND lower(trim(coalesce(p.payment_source,'')))='invoice'),0),
   coalesce(sum(p.amount),0)
 INTO paid_cash,paid_all
 FROM public.payments p
 WHERE p.invoice_id=inv.invoice_id AND coalesce(p.amount,0)>0;
 paid_cash:=coalesce(paid_cash,0);
 paid_all:=coalesce(paid_all,0);
 IF paid_all<=0 OR paid_cash<>paid_all THEN
   RAISE EXCEPTION 'Mixed or noncash invoice payments unsupported; no cash refund posted';
 END IF;
 SELECT coalesce(sum(amount_usd),0) INTO already_refunded
 FROM public.bb_ci_refund_requests
 WHERE invoice_id=v.invoice_id AND status='Executed';
 cap:=greatest(paid_all -
   greatest(coalesce(inv.grand_total,0)-coalesce(inv.reversal_amount,0),0)
   - already_refunded,0);
 IF v.amount_usd>cap+0.000001 THEN
   RAISE EXCEPTION 'Refund exceeds confirmed remaining overpayment. Available: %',cap;
 END IF;
 IF v.cash_source='CASH_VAULT' THEN
   PERFORM pg_advisory_xact_lock(hashtext('BIG_BROTHER_CASH_VAULT_BALANCE'));
   SELECT coalesce(sum(CASE WHEN entry_type='IN' THEN usd_amount ELSE -usd_amount END),0)
   INTO balance FROM public.cash_vault_ledger;
   IF v.amount_usd>balance+0.000001 THEN
     RAISE EXCEPTION 'Insufficient Cash Vault USD balance';
   END IF;
   entry:=public.bb_next_prefixed_id('public.cash_vault_ledger'::regclass,'vault_entry_id','VLT',6);
   INSERT INTO public.cash_vault_ledger
     (vault_entry_id,entry_at,entry_type,source,usd_amount,khr_amount,
      exchange_rate,usd_equivalent,note)
   VALUES(entry,now(),'OUT','INVOICE_REVERSAL_REFUND',v.amount_usd,0,1,
     v.amount_usd,'Synthetic Refund request '||v.request_key);
 ELSIF v.cash_source='DAILY_CASH' THEN
   PERFORM pg_advisory_xact_lock(hashtext('BIG_BROTHER_DAILY_CASH_BALANCE'));
   SELECT coalesce(sum(CASE WHEN entry_type='IN' THEN amount ELSE -amount END),0)
   INTO balance FROM public.daily_cash_ledger WHERE currency='USD';
   IF v.amount_usd>balance+0.000001 THEN
     RAISE EXCEPTION 'Insufficient Daily Cash USD balance';
   END IF;
   entry:=public.bb_next_prefixed_id('public.daily_cash_ledger'::regclass,'daily_cash_entry_id','DCL',6);
   INSERT INTO public.daily_cash_ledger
     (daily_cash_entry_id,entry_at,entry_type,source,reference_type,
      reference_id,currency,amount,exchange_rate,amount_usd,note)
   VALUES(entry,now(),'OUT','INVOICE_REVERSAL_REFUND','INVOICE_REFUND',
     v.request_key,'USD',v.amount_usd,1,v.amount_usd,
     'Synthetic Refund request '||v.request_key);
 END IF;
 UPDATE public.bb_ci_refund_requests SET status='Executed',
   ledger_entry_id=entry,executed_at=now()
 WHERE request_key=v.request_key AND status='Approved';
 IF NOT FOUND THEN
   RAISE EXCEPTION 'Refund execution concurrency guard failed';
 END IF;
 RETURN jsonb_build_object('success',true,'idempotent',false,
   'refundRequestKey',v.request_key,'cashSource',v.cash_source,
   'paidOutUSD',v.amount_usd,'ledgerEntryId',entry);
END;
$body$;

-- These demo functions may only be invoked by the synthetic CI DB owner.
REVOKE ALL ON FUNCTION public.bb_ci_refund_approve_v1(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.bb_ci_refund_execute_v1(text) FROM PUBLIC;
