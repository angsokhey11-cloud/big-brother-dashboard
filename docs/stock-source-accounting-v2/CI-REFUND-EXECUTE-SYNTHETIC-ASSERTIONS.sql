-- BIG BROTHER: strict SYNTHETIC-ONLY cash refund posting test matrix.
-- NO real outgoing payments, no Supabase/Local writes. All mutations rolled back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $refund_cases$
DECLARE
  r jsonb; ledger_id text; orig_entry_count integer;
  v_err text; blocked boolean; n integer;
  vault_amount numeric; wallet_amount numeric;
  history jsonb;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Cash refund CI refused outside isolated database';
 END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);

 -- 1: Reversal was recorded, but without actual approval no cash may move.
 blocked:=false;
 BEGIN
   PERFORM public.bb_ci_refund_execute_v1('BB-CI-REF-NOTAPPROVED');
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('Refund must be Approved' IN v_err)=0 THEN
      RAISE EXCEPTION 'REFUND CASE1 unexpected error: %',v_err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'REFUND CASE1 pending payout was executed'; END IF;
 RAISE NOTICE 'PASS REFUND CASE 1/9: Pending refund cannot post cash';

 -- 2: Unknown user cannot approve refund.
 blocked:=false;
 BEGIN
   PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
   PERFORM public.bb_ci_refund_approve_v1('BB-CI-REF-VAULT-30');
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('Refund Admin approval access denied' IN v_err)=0 THEN
     RAISE EXCEPTION 'REFUND CASE2 unexpected error: %',v_err;
   END IF;
   blocked:=true;
 END;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 IF NOT blocked OR
    (SELECT status FROM public.bb_ci_refund_requests WHERE request_key='BB-CI-REF-VAULT-30')<>'Pending'
 THEN RAISE EXCEPTION 'REFUND CASE2 unauthorized approval succeeded'; END IF;
 RAISE NOTICE 'PASS REFUND CASE 2/9: Unauthenticated/non-admin approval denied';

 -- 3: Approved Cash Vault refund $30: exactly one OUT and original close intact.
 IF public.bb_ci_refund_approve_v1('BB-CI-REF-VAULT-30')<>'Approved' THEN
   RAISE EXCEPTION 'REFUND CASE3 failed to approve';
 END IF;
 r:=public.bb_ci_refund_execute_v1('BB-CI-REF-VAULT-30');
 ledger_id:=r->>'ledgerEntryId';
 IF (r->>'success')::boolean IS DISTINCT FROM true OR (r->>'idempotent')::boolean IS DISTINCT FROM false
 OR ledger_id IS NULL OR
 (SELECT count(*) FROM public.cash_vault_ledger WHERE
  vault_entry_id=ledger_id AND entry_type='OUT'
  AND source='INVOICE_REVERSAL_REFUND' AND usd_amount=30)<>1 OR
 (SELECT status FROM public.bb_ci_refund_requests WHERE request_key='BB-CI-REF-VAULT-30')<>'Executed' THEN
   RAISE EXCEPTION 'REFUND CASE3 missing Vault OUT / approval linkage: %',r;
 END IF;
 SELECT coalesce(sum(CASE WHEN entry_type='IN' THEN usd_amount ELSE -usd_amount END),0)
   INTO vault_amount FROM public.cash_vault_ledger;
 IF vault_amount<>30 THEN RAISE EXCEPTION 'REFUND CASE3 Vault must have $30 remaining, got %',vault_amount; END IF;
 IF (SELECT status FROM public.daily_cash_closes WHERE close_id='BB-CI-REF-CLOSE')<>'Approved'
 OR (SELECT count(*) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH')<>1
 OR (SELECT amount FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH')<>100 THEN
  RAISE EXCEPTION 'REFUND CASE3 original cash receipt or close changed';
 END IF;
 RAISE NOTICE 'PASS REFUND CASE 3/9: Approved Vault cash refund posts exactly $30 OUT; original Approved close retained';

 -- 4: Same request key retried: the original entry is returned and no new OUT.
 orig_entry_count:=(SELECT count(*) FROM public.cash_vault_ledger);
 r:=public.bb_ci_refund_execute_v1('BB-CI-REF-VAULT-30');
 IF (r->>'idempotent')::boolean IS DISTINCT FROM true
 OR r->>'ledgerEntryId' IS DISTINCT FROM ledger_id
 OR (SELECT count(*) FROM public.cash_vault_ledger)<>orig_entry_count THEN
   RAISE EXCEPTION 'REFUND CASE4 idempotency failure: %',r;
 END IF;
 RAISE NOTICE 'PASS REFUND CASE 4/9: Idempotent retry cannot refund twice';

 -- 5: Daily Cash wallet pays distinct $20 refund, without changing Vault.
 PERFORM public.bb_ci_refund_approve_v1('BB-CI-REF-DAILY-20');
 r:=public.bb_ci_refund_execute_v1('BB-CI-REF-DAILY-20');
 IF (r->>'paidOutUSD')::numeric<>20 OR
    NOT EXISTS(SELECT 1 FROM public.daily_cash_ledger WHERE
     daily_cash_entry_id=r->>'ledgerEntryId' AND entry_type='OUT' AND
     source='INVOICE_REVERSAL_REFUND' AND reference_type='INVOICE_REFUND'
     AND reference_id='BB-CI-REF-DAILY-20' AND amount=20) THEN
   RAISE EXCEPTION 'REFUND CASE5 Daily Cash wallet posting absent: %',r;
 END IF;
 SELECT coalesce(sum(CASE WHEN entry_type='IN' THEN amount ELSE -amount END),0)
 INTO wallet_amount FROM public.daily_cash_ledger WHERE currency='USD';
 SELECT coalesce(sum(CASE WHEN entry_type='IN' THEN usd_amount ELSE -usd_amount END),0)
 INTO vault_amount FROM public.cash_vault_ledger;
 IF wallet_amount<>20 OR vault_amount<>30 OR wallet_amount+vault_amount<>50 THEN
   RAISE EXCEPTION 'REFUND CASE5 balances wrong (Vault %, Wallet %)',vault_amount,wallet_amount;
 END IF;
 RAISE NOTICE 'PASS REFUND CASE 5/9: Daily Cash refund $20 deducted ONLY from wallet; Vault not double-charged';

 -- 6: $80 reversal on $100 cash creates max $80 refundable, $50 already
 -- paid back; $40 more must be rejected (remaining cap only $30).
 PERFORM public.bb_ci_refund_approve_v1('BB-CI-REF-EXCESS-40');
 blocked:=false;
 BEGIN
   PERFORM public.bb_ci_refund_execute_v1('BB-CI-REF-EXCESS-40');
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('Refund exceeds confirmed remaining overpayment' IN v_err)=0 THEN
     RAISE EXCEPTION 'REFUND CASE6 unexpected error: %',v_err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked OR
   (SELECT status FROM public.bb_ci_refund_requests WHERE request_key='BB-CI-REF-EXCESS-40')<>'Approved'
 THEN RAISE EXCEPTION 'REFUND CASE6 excess refund unexpectedly posted'; END IF;
 RAISE NOTICE 'PASS REFUND CASE 6/9: Over-refund exceeds remaining return cap and cannot post';

 -- 7: Bank payouts blocked until OUTGOING-bank transfer verification exists.
 PERFORM public.bb_ci_refund_approve_v1('BB-CI-REF-BANK-10');
 blocked:=false;
 BEGIN
   PERFORM public.bb_ci_refund_execute_v1('BB-CI-REF-BANK-10');
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('verified outgoing bank transaction integration' IN v_err)=0 THEN
     RAISE EXCEPTION 'REFUND CASE7 unexpected bank error: %',v_err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'REFUND CASE7 phantom bank payout permitted'; END IF;
 RAISE NOTICE 'PASS REFUND CASE 7/9: Bank REFUND requires external outgoing confirmation (not faked)';

 -- 8: Wrong funding: bank-only invoice has no original Cash, no cash payout.
 PERFORM public.bb_ci_refund_approve_v1('BB-CI-REF-WRONGINVOICE');
 blocked:=false;
 BEGIN
   PERFORM public.bb_ci_refund_execute_v1('BB-CI-REF-WRONGINVOICE');
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('Only original USD Cash invoice supported' IN v_err)=0 THEN
      RAISE EXCEPTION 'REFUND CASE8 unexpected method error: %',v_err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'REFUND CASE8 bank invoice paid from Cash Vault'; END IF;
 RAISE NOTICE 'PASS REFUND CASE 8/9: Bank-only original invoice cannot drain Cash Vault';

 -- 9: Remaining refund cap is $30 but Daily Cash only has $20, so it
 -- must fail with a funding-specific error.
 INSERT INTO public.bb_ci_refund_requests
 (request_key,invoice_id,cash_source,amount_usd)
 VALUES('BB-CI-REF-WALLET-30','BB-CI-DCC-CASH','DAILY_CASH',30);
 PERFORM public.bb_ci_refund_approve_v1('BB-CI-REF-WALLET-30');
 blocked:=false;
 BEGIN
   PERFORM public.bb_ci_refund_execute_v1('BB-CI-REF-WALLET-30');
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_err=MESSAGE_TEXT;
   IF position('Insufficient Daily Cash USD balance' IN v_err)=0 THEN
     RAISE EXCEPTION 'REFUND CASE9 unexpected balance error: %',v_err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked OR
   (SELECT count(*) FROM public.daily_cash_ledger WHERE source='INVOICE_REVERSAL_REFUND')<>1 THEN
   RAISE EXCEPTION 'REFUND CASE9 insufficient wallet still posted cash';
 END IF;
 history:=public.bb_v2_dcc_approved_cash_history_staged();
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(history->'history') h
     WHERE h->>'invoice_id'='BB-CI-DCC-CASH' AND
       (h->>'approved_cash_close_amount')::numeric=100 AND
       (h->>'reversal_amount')::numeric=80) THEN
   RAISE EXCEPTION 'REFUND CASE9 approved cash historical receipt mutated';
 END IF;
 RAISE NOTICE 'PASS REFUND CASE 9/9: Insufficient account balance rejected, approved original history still intact';
END;
$refund_cases$;
ROLLBACK;
DO $refund_after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'REFUND CI rollback validation outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.bb_ci_refund_requests WHERE status='Executed')
 OR EXISTS(SELECT 1 FROM public.cash_vault_ledger WHERE source='INVOICE_REVERSAL_REFUND')
 OR EXISTS(SELECT 1 FROM public.daily_cash_ledger WHERE source='INVOICE_REVERSAL_REFUND') THEN
   RAISE EXCEPTION 'REFUND synthetic transaction ROLLBACK left payout or ledger records';
 END IF;
 IF (SELECT count(*) FROM public.bb_ci_refund_requests WHERE status='Pending')<>6
 OR (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-DCC-CASH')<>80 THEN
   RAISE EXCEPTION 'REFUND synthetic transaction ROLLBACK changed original fixture';
 END IF;
 RAISE NOTICE 'PASS: 9/9 synthetic cash refund posting tests rolled back, no bank payout implemented';
END;
$refund_after$;
