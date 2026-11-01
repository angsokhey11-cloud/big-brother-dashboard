-- Real Cloud current financial triggers + DCC report, synthetic CI only.
-- The existing DCC cash-disappearance problem is explicitly flagged as a
-- RELEASE BLOCKER, not misrepresented as a successful cash-refund workflow.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
DO $bb_ci_finance$
DECLARE
 inv record;
 r jsonb; n int;
 err text; denied boolean;
 cash_pre boolean;cash_post boolean;
 payments_pre int;
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
   RAISE EXCEPTION 'Finance CI refused outside sandbox';
 END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);

 -- CASE 1: credit invoice with $40 collected and $25 reversal.
 -- Expected net credit = 100 - 25 - 40 = $35. Pending AR approval rejected.
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-AR-RET-25','BB-CI-AR-PART','BB-CI-NONBATCH-25',1,25);
 SELECT reversal_amount,amount_paid,outstanding,credit_amount,status
 INTO inv FROM public.invoices WHERE invoice_id='BB-CI-AR-PART';
 IF inv.reversal_amount<>25 OR inv.amount_paid<>40 OR inv.outstanding<>35
 OR inv.credit_amount<>35 OR inv.status<>'Processing' THEN
    RAISE EXCEPTION 'FINANCE CASE1 incorrect net credit: %',row_to_json(inv);
 END IF;
 IF (SELECT status FROM public.ar_payment_requests WHERE request_id='BB-CI-AR-REQUEST')<>'Rejected' THEN
    RAISE EXCEPTION 'FINANCE CASE1 in-process AR request not invalidated';
 END IF;
 RAISE NOTICE 'PASS FINANCE CASE 1/4: $100 credit minus $25 return and $40 paid = $35 outstanding; pending approval invalidated';

 -- CASE 2: overpaid credit $90 cannot reverse $30 without refund/credit.
 denied:=false;err:='';
 BEGIN
   INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
   VALUES('BB-CI-AR-RET-OVER','BB-CI-AR-OVER','BB-CI-NONBATCH-OVER',1,30);
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF position('Process the customer refund/credit before reversing' IN err)=0 THEN
     RAISE EXCEPTION 'FINANCE CASE2 unexpected rejection: %',err;
   END IF;
   denied:=true;
 END;
 IF NOT denied OR EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id='BB-CI-AR-RET-OVER') OR
   (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-AR-OVER')<>0 THEN
   RAISE EXCEPTION 'FINANCE CASE2 overpaid reversal inserted despite guard';
 END IF;
 RAISE NOTICE 'PASS FINANCE CASE 2/4: reversal exceeding collected credit blocked atomically';

 -- CASE 3: cumulative partial return 20 + 30 on $100, $25 paid.
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-AR-RET-20','BB-CI-AR-MULTI','BB-CI-NONBATCH-20',1,20);
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-AR-RET-30','BB-CI-AR-MULTI','BB-CI-NONBATCH-30',1,30);
 SELECT reversal_amount,amount_paid,outstanding,credit_amount,status
 INTO inv FROM public.invoices WHERE invoice_id='BB-CI-AR-MULTI';
 IF inv.reversal_amount<>50 OR inv.amount_paid<>25 OR
 inv.outstanding<>25 OR inv.credit_amount<>25 OR inv.status<>'Processing' THEN
   RAISE EXCEPTION 'FINANCE CASE3 cumulative net A/R incorrect: %',row_to_json(inv);
 END IF;
 RAISE NOTICE 'PASS FINANCE CASE 3/4: cumulative credit returns $20 + $30, net A/R $25';

 -- CASE 4: DCC currently hides cash received after full return,
 -- although the $100 payment remains. This is a DOCUMENTED BLOCKER.
 r:=public.bb_dcc_invoice_list();
 cash_pre:=EXISTS(SELECT 1 FROM jsonb_array_elements(r->'invoices') a
  WHERE a->>'invoiceId'='BB-CI-DCC-CASH');
 IF NOT cash_pre THEN RAISE EXCEPTION 'FINANCE CASE4 missing initial $100 cash receipt'; END IF;
 payments_pre:=(SELECT count(*) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH');
 IF payments_pre<>1 THEN RAISE EXCEPTION 'FINANCE CASE4 initial cash payment missing'; END IF;
 INSERT INTO public.sales_returns(return_id,invoice_id,line_id,qty,return_amount)
 VALUES('BB-CI-DCC-FULL-RETURN','BB-CI-DCC-CASH','BB-CI-NONBATCH-CASH',1,100);
 r:=public.bb_dcc_invoice_list();
 cash_post:=EXISTS(SELECT 1 FROM jsonb_array_elements(r->'invoices') a
   WHERE a->>'invoiceId'='BB-CI-DCC-CASH');
 IF cash_post THEN
   RAISE NOTICE 'DCC behavior changed: reversed cash invoice still listed. Re-audit net cash refund handling.';
 ELSE
   RAISE NOTICE 'RELEASE BLOCKER VERIFIED: DCC hides fully reversed $100 CASH invoice even though original $100 payment remains; no refund event was generated';
 END IF;
 IF (SELECT count(*) FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH')<>1 OR
    (SELECT amount FROM public.payments WHERE invoice_id='BB-CI-DCC-CASH')<>100 THEN
   RAISE EXCEPTION 'FINANCE CASE4 cash payment silently altered';
 END IF;
 IF cash_post THEN RAISE EXCEPTION 'CI audit assumption changed; explicitly review DCC accounting policy'; END IF;
 RAISE NOTICE 'PASS FINANCE CASE 4/4: DCC cash-disappearance risk reproducibly flagged; cash payment unchanged';
END;
$bb_ci_finance$;
ROLLBACK;
DO $bb_ci_finance_after$
BEGIN
 IF current_database()<>'bb_stock_v2_sandbox' THEN
  RAISE EXCEPTION 'Finance post-rollback check refused outside sandbox';
 END IF;
 IF EXISTS(SELECT 1 FROM public.sales_returns WHERE return_id LIKE 'BB-CI-AR-RET-%'
  OR return_id='BB-CI-DCC-FULL-RETURN') THEN
  RAISE EXCEPTION 'Finance rollback left test returns';
 END IF;
 IF (SELECT reversal_amount FROM public.invoices WHERE invoice_id='BB-CI-AR-PART')<>0 OR
    (SELECT status FROM public.ar_payment_requests WHERE request_id='BB-CI-AR-REQUEST')<>'Processing' THEN
   RAISE EXCEPTION 'Finance rollback left modified credit status or AR request';
 END IF;
 RAISE NOTICE 'PASS: Finance 4/4 current implementation tests rolled back; DCC REFUND VISIBILITY remains release blocker';
END;
$bb_ci_finance_after$;
