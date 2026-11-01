-- Actual staged BEFORE INSERT cash approval guard with real invoice return
-- and current Cloud financial triggers; synthetic DB, transactional rollback.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $bb_ci_cash_gate$
DECLARE
 err text; blocked boolean;
 amount_before numeric;
 n_payments integer;
 returned_count integer;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Cash approval gate CI cannot run outside sandbox';
 END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 n_payments:=(SELECT count(*) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH');
 amount_before:=(SELECT sum(amount) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH');

 -- CASE 1: cash payment received but no Daily Cash Close approved.
 blocked:=false;err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
   VALUES('BB-CI-GATE-UNAPPROVED','BB-CI-DCC-CASH','BB-CI-DCC-LINE',1,100);
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Approve Daily Cash Collection before Reversal' IN err)=0 THEN
     RAISE EXCEPTION 'CASH GATE CASE 1 unexpected error: %',err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-GATE-UNAPPROVED') THEN
   RAISE EXCEPTION 'CASH GATE CASE 1 allowed unapproved cash Reversal';
 END IF;
 RAISE NOTICE 'PASS CASH GATE CASE 1/6: unapproved original Cash receipt cannot reverse';

 -- CASE 2: Pending Daily Cash Close does NOT count as approval.
 blocked:=false;err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
   VALUES('BB-CI-GATE-PENDING','BB-CI-CASH-PENDING','BB-CI-DCC-LINE',1,10);
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Approve Daily Cash Collection before Reversal' IN err)=0 THEN
     RAISE EXCEPTION 'CASH GATE CASE 2 unexpected error: %',err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-GATE-PENDING') THEN
   RAISE EXCEPTION 'CASH GATE CASE 2 pending Close incorrectly approved';
 END IF;
 RAISE NOTICE 'PASS CASH GATE CASE 2/6: Pending cash close not sufficient';

 -- CASE 3: Rejected Close also cannot authorize stock/financial reversal.
 blocked:=false;err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
   VALUES('BB-CI-GATE-REJECTED','BB-CI-CASH-REJECTED','BB-CI-DCC-LINE',1,10);
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Approve Daily Cash Collection before Reversal' IN err)=0 THEN
     RAISE EXCEPTION 'CASH GATE CASE 3 unexpected error: %',err;
   END IF;
   blocked:=true;
 END;
 IF NOT blocked OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-GATE-REJECTED') THEN
   RAISE EXCEPTION 'CASH GATE CASE 3 rejected Close incorrectly approved';
 END IF;
 RAISE NOTICE 'PASS CASH GATE CASE 3/6: Rejected cash close not sufficient';

 -- CASE 4: after APPROVAL, full Reversal permitted, keeping original
 -- receipt + approved cash close history, WITHOUT inventing refund.
 INSERT INTO public.daily_cash_closes(close_id,status,expected_usd)
 VALUES('BB-CI-CLOSE-APPROVED','Approved',100);
 INSERT INTO public.daily_cash_close_invoices(
   close_invoice_id,close_id,invoice_id,invoice_cash_amount)
 VALUES('BB-CI-CLOSE-LINK-A','BB-CI-CLOSE-APPROVED','BB-CI-DCC-CASH',100);
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-GATE-AFTER-APPROVAL','BB-CI-DCC-CASH','BB-CI-DCC-LINE',1,100);
 IF (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-DCC-CASH')<>100
 OR (SELECT count(*) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH')<>n_payments
 OR (SELECT sum(amount) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH')<>amount_before
 OR (SELECT status FROM public.daily_cash_closes WHERE close_id='BB-CI-CLOSE-APPROVED')<>'Approved'
 OR NOT EXISTS(SELECT 1 FROM public.daily_cash_close_invoices
   WHERE close_id='BB-CI-CLOSE-APPROVED' AND invoice_id='BB-CI-DCC-CASH'
      AND invoice_cash_amount=100) THEN
    RAISE EXCEPTION 'CASH GATE CASE 4 changed original approved cash receipt / status';
 END IF;
 RAISE NOTICE 'PASS CASH GATE CASE 4/6: Approved original Cash may reverse; close history intact; no refund invented';

 -- CASE 5: Bank-only invoice is not subject to cash close approval.
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-GATE-BANK','BB-CI-BANK-ONLY','BB-CI-BANK-LINE',1,10);
 IF (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-BANK-ONLY')<>10 THEN
    RAISE EXCEPTION 'CASH GATE CASE 5 incorrectly blocked Bank-only Reversal';
 END IF;
 RAISE NOTICE 'PASS CASH GATE CASE 5/6: Bank-only Reversal unaffected';

 -- CASE 6: Credit invoice with later Receivable Cash is NOT original
 -- invoice Cash Collection; do not require an unrelated DCC approval.
 INSERT INTO public.payments(payment_id,invoice_id,payment_date,amount,
   payment_method,payment_source)
 VALUES('BB-CI-GATE-AR-CASH','BB-CI-AR-PART',current_date,40,'Cash','Receivable');
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-GATE-AR','BB-CI-AR-PART','BB-CI-AR-LINE',1,20);
 IF (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-AR-PART')<>20
 OR (SELECT outstanding FROM public.invoices WHERE invoice_id='BB-CI-AR-PART')<>40 THEN
    RAISE EXCEPTION 'CASH GATE CASE 6 Credit A/R cash reversal affected unexpectedly';
 END IF;
 RAISE NOTICE 'PASS CASH GATE CASE 6/6: Cash received through Credit A/R does not trigger invoice cash-close gate';

 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id IN
 ('BB-CI-GATE-UNAPPROVED','BB-CI-GATE-PENDING','BB-CI-GATE-REJECTED')) THEN
   RAISE EXCEPTION 'CASH GATE rejected requests had side effects';
 END IF;
END;
$bb_ci_cash_gate$;
ROLLBACK;

DO $bb_ci_cash_gate_after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Cash approval post-rollback check outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id LIKE 'BB-CI-GATE-%')
 OR EXISTS(SELECT 1 FROM public.daily_cash_close_invoices WHERE close_id='BB-CI-CLOSE-APPROVED')
 OR EXISTS(SELECT 1 FROM public.payments WHERE payment_id='BB-CI-GATE-AR-CASH')
 OR (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-DCC-CASH')<>0 THEN
   RAISE EXCEPTION 'CASH GATE rollback left synthetic financial changes';
 END IF;
 RAISE NOTICE 'PASS: 6/6 Cash approval Reversal guard tests and transaction ROLLBACK verified';
END;
$bb_ci_cash_gate_after$;
