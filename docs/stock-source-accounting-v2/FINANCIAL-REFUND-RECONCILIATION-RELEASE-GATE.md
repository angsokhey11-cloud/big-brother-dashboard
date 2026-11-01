# BIG BROTHER Stock Source V2 — A/R and Cash Refund Release Gate

**Status: ACCOUNTING RECONCILIATION 4/4 verified; Daily Cash refund workflow NOT RELEASE-READY.**
**Date:** 01-Nov-2026. **Environment:** synthetic PostgreSQL 17, isolated GitHub Actions, no network / production records.

## 01-Nov-2026 — Accountant clarification: Approved Daily Cash Close is mandatory BEFORE Reversal

**Separate workflows:** Invoice Reversal is a genuine return / accounting correction against an issued sale; future Invoice Cancellation for a completely misissued invoice and safe number reuse is **out of scope** for this Stock Source V2 work.

The accountant explicitly defines **Daily Cash Collection cleared = Daily Cash Close approved**. Verified against Cloud schema and data structure:
- `daily_cash_closes.status = 'Approved'`, associated by `daily_cash_close_invoices.close_id` and exact `invoice_id`, not by duplicate-prone Invoice No.
- Other statuses such as Pending and Rejected do **not** clear the cash.
- Original invoice Cash, Cash + Bank and Partially Paid in Cash cannot be reversed until their DCC close is approved. The staged BEFORE INSERT guard also handles original `payments.payment_source='Invoice'` cash records.
- Credit invoices later paid with Cash through Receivables are **not** mistaken for original Cash invoices; bank-only sales are unaffected.
- After approval, reversing stock/sales may proceed but the approved cash-close row and original cash receipt are preserved; **cash refund or credit remains a separate authorized financial transaction**.

**Automated evidence:** [GitHub Actions run 41281784893](https://github.com/angsokhey11-cloud/big-brother-dashboard/actions/runs/41281784893) **SUCCESS**. The staged actual `bb_v2_reversal_require_approved_cash_close()` BEFORE INSERT trigger passed **6/6** synthetic cases: unapproved, Pending, Rejected blocked; Approved allowed with close history and original cash intact; Bank-only allowed; Credit A/R cash not blocked. Full `ROLLBACK` passed.

**Critical correction to earlier proposed reporting fix:** Do **NOT** add reversed approved receipts back to the active DCC `Close Selected` invoice list: this may let staff collect the same approved cash again. The former `CI-DCC-CASH-RECEIPT-VISIBILITY-PROTOTYPE.sql` is **SUPERSEDED, forensic-only and NOT DEPLOYABLE**.

Instead, the separate **approved-only, nonselectable** `bb_v2_dcc_approved_cash_history_staged()` was added in `CI-DCC-APPROVED-CASH-HISTORY-STAGED.sql`. The same CI test confirms a fully reversed $100 cash invoice remains in approved close history with its original $100 receipt, $100 reversal, $0 net sale, and a **reconciliation review flag**, while Pending / Rejected close invoices are excluded. No fictitious refund is generated.

**Release restrictions:** These functions are staged in GitHub only, never applied to Cloud or real Local V5/V6. Access grants, full Supabase RLS, legacy historical returns, cash close/selected UI, actual refund OUT ledger and approved bank balance adjustments still require integration and accounting sign-off.

## Verified current Cloud accounting behavior

Audited live production definitions read-only (`pg_get_functiondef`) and copied **only** `bb_credit_invoice_net_balance_guard`, `bb_sync_invoice_reversal_receivable`, and `bb_dcc_invoice_list` into feature-branch isolated test reference `CI-CLOUD-AR-DCC-CURRENT-FUNCTIONS-READONLY.sql`. No live schema change.

Verified [GitHub CI run 41280848959](https://github.com/angsokhey11-cloud/big-brother-dashboard/actions/runs/41280848959) on a synthetic database:

- **A/R case 1:** $100 credit invoice, $40 collected, $25 return -> net invoice $75, outstanding **$35**. Processing A/R request automatically rejected for resubmission.
- **A/R case 2:** $100 credit invoice with $90 collected cannot reverse $30: would create $20 overpayment; actual BEFORE credit guard aborts return and stock transaction atomically until customer refund/credit handled.
- **A/R case 3:** $100 credit invoice, $25 collected, cumulative $20+$30 reversal -> outstanding **$25**, no double counting.
- **DCC case 4: REPRODUCED DEFECT.** $100 CASH invoice remains paid in `payments`; after $100 full reversal, current `bb_dcc_invoice_list()` removes it because it excludes fully reversed invoices/returns. No refund payment or cash outflow occurred. **Cash disappeared from this report only, not from the database payment record.** The report therefore cannot be relied upon to reconcile actual refunds as-is.

The selected Cloud functions are not complete production integration: no Supabase Auth/RLS, real multiple-bank allocations, physical cash close history, browser/APK, or Local V5/V6 was tested.

## Staged reporting-only prototype (PASS, NOT DEPLOYED)

`CI-DCC-CASH-RECEIPT-VISIBILITY-PROTOTYPE.sql` creates a **separate** `bb_dcc_invoice_list_v2_staged()`, based on existing Cloud DCC logic, without overwriting `bb_dcc_invoice_list()`. It:

1. Retains the original, gross `Cash` payment row even when the invoice is fully reversed.
2. Adds `reportEventType: CASH_RECEIPT`, `reversalAmount`, `netInvoiceValue`, and `cashRefundReviewRequired`. The test verifies $100 collected / $100 reversed / $0 net, with reconciliation required.
3. **Does not issue money, invent a negative refund, adjust a bank wallet, reduce a cash vault balance, or declare the customer refunded.**
4. Revokes PUBLIC EXECUTE on the test function. This is a CI prototype, **not a deployable user-facing RPC**. A production release must separately review authenticated grants/RLS, backend and UI compatibility.

The prototype's original cash row + warning passed the same CI run. It is a visibility repair, **not settlement**.

## Proposed full cash/bank refund requirements (approval / development pending)

Create a separate **authorized, auditable refund or customer-credit settlement**. Refunds should never be automatically inferred from `sales_returns` or written merely because an invoice's net value fell.

- Identify exact immutable `invoice_id`, `return_id`/return allocations, original payment sources, customer and currency. Duplicate invoice numbers are valid; NEVER join by `invoice_no` alone.
- Each refund/credit request has unique idempotency key, requesting user, approving user, source/account, date, amount, currency, exchange rate, external bank transaction reference (if bank), and reason. Pending approval is distinct from **executed** money movement.
- Eligibility based on **actual gross payments allocated** minus **remaining net sale value** minus previously executed refunds or transferred customer credits, calculated in consistent invoice currency. Never exceed refundable excess, never refund same allocation twice, never make a negative warehouse/batch stock adjustment to pay cash.
- Cash refund: write a separately identifiable **OUT** movement in the correct company/salesman cash ledger and expose it as a dated **negative refund row** in DCC. Track which salesman/batch physically paid it; distinguish from warehouse/cash-vault expense as required.
- Bank refund: require actual bank transaction confirmation; record approved outgoing bank transaction, never silently create a new customer bank receipt or reuse an incoming transaction ID.
- Customer credit / unused bank balance: create a distinct traceable liability/credit transfer and source relationship, not physical cash outflow. Must reconcile oldest-first wallet allocations and release original payment allocation only under approved rules.
- Cash Collection UI: display original receipts and refunds separately, with source date, invoice, customer, salesman, refund status and return reason; keep gross collections and negative refunds visible. **Never automatically include a reversed receipt as a new selectable close**. Cash-close and financial-export totals must reconcile to gross cash IN less executed cash OUT. Report-only review flags cannot assert a refund was paid.
- Credit A/R reversal guard currently requires refund/credit **before** applying a reversal that would leave overpayment. Design and test a legal two-step settlement that does not erase original collections, lose bank-wallet linkage, or allow over-refund.
- Make corrections reversible through a controlled audit trail, not silent deletions. Respect USD/KHR conversion and historical exchange rates.

## Mandatory test matrix before approving release

1. Partial and full reversals of **unpaid credit**, **partially collected credit**, **fully collected cash**, **bank**, **cash+bank**, and **customer wallet** payments; include USD/KHR cross-currency.
2. Customer refunds paid, pending approval, rejected, already paid, and retried; no double payments or phantom cash.
3. Duplicate invoice numbers with different customers, invoice ID and A/R payment allocation isolation.
4. Gross cash stays visible after reversal, negative cash refund appears only on executed payment; unmatched overpayment flagged. Confirm Close Selected and cash-vault ledger balance once.
5. Multiple cash closes, earlier/later return dates, expenses, and salesman batch accountability.
6. Real Supabase schema/Auth/RLS and Local V5/V6 offline migration and sync; Web/PWA/Online APK/Local APK flows.
7. Enforce automatic CI gate plus explicit accountant approval of real reconciliation cases.

## Release decision

**DO NOT DEPLOY** the reporting prototype or Stock Source V2 solely because isolated SQL tests passed. Current A/R guard behavior is verified, but **recording a real refund, ledger reconciliation, and DCC refund visibility** still require approved design and end-to-end tests.

**Production changed:** No. **Live refunds created:** No. **Extra Supabase branches:** None.
