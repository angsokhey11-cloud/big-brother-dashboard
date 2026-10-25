# BIG BROTHER Local Brain — Staff Relation Code Sync Preparation
Date: 2026-10-25
Status: PREPARED INVENTORY ONLY — NOT AN EXECUTABLE SQL MIGRATION
Applies to: Local Brain V5 and V6, desktop + tablet/mobile.

## Non-negotiable sync boundary

1. **Code Sync** is the ONLY deployment path for application source changes, SQL functions, table/column schema changes, grants, constraints, indexes, and local permissions.
2. **Cloud → Local** synchronizes **business records ONLY**. It must not deploy code, functions, permissions, migrations, or schema. Preserve local-only business records, and use the established Cloud-wins-for-matching-ID policy only for business records.
3. No direct production SQL patching of the Local Brain PostgreSQL database as a substitute for Code Sync.
4. Run Schema Guard, take a local PostgreSQL backup, inspect migration checksums, then apply manifest-listed SQL migrations through the existing Code SQL Migration workflow. Do not mark a migration complete without verification.
5. Local Brain V6 uses V5 as a prerequisite in the established startup workflow. Verify both interfaces after Code Sync.

## Already on GitHub: Staff Relation presentation and shared controller

Repository: angsokhey11-cloud/big-brother-staff-relation

- index.html — professional PC workspace, same SVG icon family as mobile
- mobile.html — compact mobile workspace
- staff-relation.js — shared Staff Relation authorized controller and Admin-on-behalf submission routes
- staff-relation.css — shared base
- staff-relation-desktop-v1.js + .css — desktop presentation and categorized Available Payment
- staff-relation-desktop-history-v1.css — one-line desktop Payment History
- staff-relation-mobile-payment-history-v4.js + .css — source-category breakdown for multi-source payments
- staff-relation-compact-mobile-v2.js + .css — compact mobile payments
- staff-relation-mobile-staff-picker-v6.js + .css — searchable mobile Admin staff picker
- staff-relation-admin-mobile-v5.css — selected-button styling
- staff-relation-shared-icons-v1.js — same mobile professional SVG artwork

Repository: angsokhey11-cloud/big-brother-dashboard

- PC and mobile routing/asset versions pointing to current Staff Relation pages and scripts
- PWA cache/version updates where required by current Code Sync procedure

**Caution:** Code Sync should deploy the complete current files using the approved existing workflow, not copy isolated snippets or overwrite Local data.

## Cloud SQL features introduced after the currently indexed Local migration set

The currently checked Local SQL migration manifest ends with 20261023_stock_batch_date_correction_v1 and does not list Staff Relation salary/Admin-on-behalf updates.

The new SQL requirements are:

1. **Admin on behalf of staff:**
   - staff_payment_requests, staff_leave_requests, staff_salary_advance_requests: submitted_by_user_id and submission_channel, including corresponding status checks.
   - private.bb_staff_relation_admin_request_target(text)
   - public.bb_staff_relation_admin_request_payment(text,jsonb)
   - public.bb_staff_relation_admin_submit_leave(text,date,date,text)
   - public.bb_staff_relation_admin_submit_salary_advance(text,date,numeric,text)
   - All privileged functions must enforce the existing Admin gate and use restricted EXECUTE grants.

2. **Payment History method:**
   - public.bb_staff_relation_my_payment_history and public.bb_staff_relation_admin_view return real paymentMethod from approved payment/expense data (where present).

3. **Salary History correction:**
   - private.bb_staff_salary_edit_audit_v1
   - public.bb_staff_relation_admin_update_salary(...)
   - public.bb_staff_relation_admin_master_data includes updatedAt for concurrency protection.

4. **Protected salary setup deletion / new version security:**
   - private.bb_staff_salary_delete_audit_v1
   - public.bb_staff_relation_admin_delete_salary(text,text,timestamptz)
   - public.bb_staff_relation_admin_save_salary(...) duplicate-date and claimed/paid-month protections.
   - The existing unique index on staff_payment_earnings for MONTHLY_SALARY per staff_id/salary_month must be present.

5. **Missing due salary backfill (accounting opening September 2026):**
   - private.bb_staff_relation_sync_due_salary_months(text)
   - Updates to public.bb_staff_relation_admin_view, private.bb_staff_relation_sync_current_identity, private.bb_staff_relation_sync_staff.
   - This generates missing, due salary earnings only; never duplicate/reopen REQUESTED, PAID or historical earning records.

## Local Schema Guard checks before packaging EXECUTABLE migrations

- Verify exact Local PostgreSQL version, Staff Relation tables, columns and function signatures against Cloud.
- Verify baseline salary setup, monthly earning index, and Admin/staff authorization helpers are present.
- Inspect Local changes to any function before replacing it. SQL patches must SAFE-STOP on missing/mismatched prerequisites rather than blindly overwrite custom code.
- Add idempotent, checksum-verified SQL files to local-db-migrations/manifest.json in dependency order AFTER reviewing the Local Schema Guard report. Protect existing business rows and salary/payment/request records.
- Validate that old salary earning IDs and payment request IDs remain linked; already PAID September salary may not reappear as AVAILABLE.
- Verify Cloud→Local business-data sync independently only after Local schema/code compatibility is established.

## Functional acceptance tests

- Desktop & mobile show the same Staff Relation earning categories and consistent professional icons.
- Personal Staff Relation and Admin View retain their respective permission gates; Admin-on-behalf requests are auditable and follow normal approval.
- Available Payment groups: Sales Incentive, Driver Allowance, Salary, Special Allowance; one row per earning, oldest first, hide empty groups.
- Payment History: one transaction per row; real payment method; multi-source breakdown collapses.
- Salary Edit updates the correct salary ID, Delete is protected, and already-claimed/paid salaries never become requestable again.
- September 2026 opening salary is generated if eligible and missing; running sync twice creates zero duplicates.
- Verify Code Sync logs, SQL migration report, login and transactions on both Local Brain V5 and V6.
- Confirm Cloud→Local still handles business data ONLY and no local-only business records were lost.

## Current status / deployment hold

This document is a preflight inventory, NOT a migration. No executable SQL files or new manifest entries are authorized as safe until the Local Schema Guard report is examined. Do not run Cloud→Local to try to deploy these functions.

## VERIFIED 2026-10-25 21:44 SCHEMA GUARD FAILURE (uploaded Windows scripts)

Received and inspected:
- `08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2.ps1` (352 lines)
- `08C-MERGE-CLOUD-STAGE-PERMANENT-V1.2.sql` (595 lines)
- `SCHEMA-GUARD-REPORT` dated 2026-10-25 21:44:19

**Confirmed failure site:** PowerShell step 4A invokes `V34-PRE-SYNC-SCHEMA-GUARD.ps1` as a separate process and **aborts on nonzero exit** before step 4B / 5 / 6 / 7. Cloud dump and Local backup succeeded. **08C never ran**, so no normal `SYNC-REPORT.txt` was generated. The existing script produces `V34-FAILURE-SUMMARY.txt` on failure.

Actual report:
- `MISSING TABLE public.bb_notification_events_v2`
- `MISSING TABLE public.bb_push_config_v1`
- `MISSING TABLE public.bb_push_deliveries_v1`
- `MISSING TABLE public.bb_push_subscriptions_v1`
- Three `submission_channel text NOT NULL DEFAULT 'STAFF'` columns missing/need review in staff_payment_requests, staff_leave_requests, staff_salary_advance_requests.
- Three `submitted_by_user_id uuid` columns are safe-additive.
- Fresh Cloud public tables 139, Local public tables 136, hence not a simple total-count equality.

**New verified security concern:** The sync controller runs `supabase db dump --data-only --use-copy --schema public` and then rewrites **all** public COPY targets into isolated Cloud staging. The existing 08C merge iterates every table present in `bb_cloud_stage` with a matching public name. **Device push subscriptions, Web Push auth secrets, config and delivery telemetry are infrastructure, not business data** and must NOT be blindly copied Cloud → Local. A business-data scope must be enforced consistently in the Cloud capture/COPY, Schema Guard, staging SQL, merge plan, and verification. Do not merely waive these four blockers in Schema Guard while still staging them.

**Verified merge behavior:** 08C uses primary-key `INSERT ... ON CONFLICT DO UPDATE` for matching records; preserves Local-only rows; does not check `source_updated_at` or other timestamps before upsert. 08C also contains historical hardcoded assumptions: one app_users alias and exactly three missing-Auth audit targets; these must remain subject to a fresh **read-only** preflight and cannot be silently loosened because Auth remains local-only.

**Cloud reconciliation target after repair:** CHEA KIMSUN / SID-008 request #22, $240 PAID. Expenses EXP-000024 ($220 September salary) and EXP-000025 ($20 Special Allowance), both PAID via ABA; staff earning IDs 793 and 901 marked PAID and request item IDs 38 and 40 associated with request #22. These must be checked in Local after successful **business-data** sync. Never recreate or approve the same expenses manually.

**Files still needed to implement and safely validate a patch:**
- `V34-PRE-SYNC-SCHEMA-GUARD.ps1` (actual failing checker)
- `08B-PREPARE-CLOUD-STAGE-V1.2.sql` (staging table creation and staging scope)
- `V34-LOCAL-APPROVED-SQL-CODE-GATE.ps1` (optional for a complete Code Sync integration review)

DO NOT alter original 08C identity safety exceptions, disable Schema Guard, or run Cloud → Local until the agreed business-only table scope and Staff Relation Code Sync schema migrations are in place. Code Sync remains separate from Cloud → Local.


## 2026-10-25 follow-up — Code Sync repair prepared and registered

GitHub migration:
- `local-db-migrations/20261025_staff_relation_sync_schema_v1.sql` registered in `local-db-migrations/manifest.json` with checked SHA-256.
- Adds only Staff Relation submission metadata and four Notification/Web Push TABLE STRUCTURES; no business records or device-push secrets copied.
- Four `ENABLE ALWAYS` infrastructure triggers fail closed if legacy 08C attempts to import notification/push rows during `session_replication_role=replica`.

Windows controller one-time updater (Code Sync DOWNLOADS these source files; Code SQL Migration does NOT automatically execute PowerShell):
- `local-db-migrations/V34-INSTALL-BUSINESS-ONLY-STAGING-V1.ps1`
- `local-db-migrations/INSTALL-BUSINESS-ONLY-STAGING.cmd`
- The updater backs up exactly the approved uploaded `08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2.ps1`, refuses SHA mismatch/multiple copies, and excludes four infra data payloads from staging while retaining COPY headers.
- Also makes SQL code gate **CheckOnly** on every Cloud→Local run and makes permanent-ID foundation **READ ONLY**, preserving Code Sync vs business sync separation. The actual `08C` SQL and Schema Guard are unchanged.
- Download source through normal **Code Sync**, then run the one-time installer from the Code Sources directory. This is a controller-file update, NOT a manual SQL execution.
- **Not yet installed or tested on the user's Windows Local Brain**. The old Schema Guard may still reject unexpected dependencies; do not assert a successful merge before Local verification.

Offline synthetic staged-COPY test: PASS — all four push/notification payloads removed; Staff Payment and Expense rows preserved; sequence setval skipped. Windows PowerShell/native PostgreSQL test: NOT RUN.

Safe order:
1. Normal Code Sync; confirm `20261025_staff_relation_sync_schema_v1` in the Code SQL Migration report as applied/verified.
2. From synced `Code Sources\big-brother-dashboard\local-db-migrations`, double-click `INSTALL-BUSINESS-ONLY-STAGING.cmd`. It backs up the old 08 controller and patches staging only after validation; it does not execute SQL or merge business records.
3. Run Cloud→Local preflight using the same old Schema Guard and SQL gate in read-only modes; stop on any failure.
4. Then run existing Cloud→Local to synchronize business data. Confirm SYNC-REPORT.txt shows committed. Reconcile SID-008 payment request #22 ($240 PAID) and expenses EXP-000024 ($220) / EXP-000025 ($20).
5. Preserve Local-only rows and backups. Never bypass rollback rehearsal or exact identity/audit safety checks.

Known blockers still dependent on local verification: `V34-PRE-SYNC-SCHEMA-GUARD.ps1`, `08B-PREPARE-CLOUD-STAGE-V1.2.sql`, and the check-only semantics of `V34-LOCAL-APPROVED-SQL-CODE-GATE.ps1` were not supplied. Their true behavior cannot be certified from the uploaded 08 and 08C files.


## 2026-10-25 23:11 — Next Cloud→Local blocker resolved in Code Sync

After previous 4A Schema Guard repair, the latest screenshot shows staging import failure:
`psql:/tmp/08B-cloud-stage-data-v1.2.sql:3037: ERROR: duplicate key value violates unique constraint "payments_lower_idx"`
`Key (lower(TRIM(BOTH FROM transaction_id)))=(179195231042684) already exists.`
`CONTEXT: COPY payments, line 643`.

Thus Step 6 staging COPY aborted; Step 7A rollback rehearsal and Step 7B real merge did NOT run. No successful SYNC-REPORT.txt is expected. Staging is partial only. Re-run a **fresh** Cloud→Local after Code Sync; do not resume old staging.

Read-only Cloud verification:
- Cloud `public.payments` uses `idx_payments_normalized_transaction_lookup` **non-unique**, partial normalization; payment_id primary key remains unique.
- Cloud contains 3 payment rows for transaction_id `179195231042684`: PAY-0560, PAY-1110, PAY-1178 (same customer, separate invoices).
- Cloud also reuses `179092673997751` twice and `179091405727617` twice. Seven total rows across those three bank references. Their accounting correctness is an **independent audit question**; DO NOT drop/delete/alter any such payment to make staging pass.
- Stage `payments_lower_idx` is **UNIQUE**, unlike Cloud. The stale Local index is the likely source if 08B creates staging via `LIKE public.payments INCLUDING INDEXES`; 08B source has not been provided, so verify this during the next Local run.

**Code Sync fix (schema-only, versioned and SHA-256 manifest-registered):**
- `local-db-migrations/20261025_payment_transaction_index_cloud_parity_v1.sql`.
- Fail-closed verifies local public.payments, the exact legacy UNIQUE normalized transaction index, non-unique Cloud-compatible index expression, primary key and foreign keys.
- Removes only `public.payments_lower_idx` if its verified definition matches the legacy normalized transaction expression; creates/validates `idx_payments_normalized_transaction_lookup` as NON-UNIQUE.
- No data row writes and no changes to Bank Register uniqueness rules. Does not alter payment primary keys.

Run normal Code Sync and confirm migration applied in `CODE-SQL-MIGRATION-REPORT`, then run **fresh** Cloud→Local. If staging still creates a UNIQUE payments_lower_idx, stop and inspect `08B-PREPARE-CLOUD-STAGE-V1.2.sql`; that SQL is currently unavailable and may explicitly recreate the obsolete unique index independently of Local.

Once merge completes, verify SID-008 Staff Payment Request #22 PAID and EXP-000024 / EXP-000025, plus reused transaction IDs and their distinct `payment_id` records. Do not manually recreate CHEA KIMSUN salary expenses.


## 2026-10-25 late-night addition — Multi-use Registered Bank Wallet missed by earlier Local patch

User correctly identified that the Cloud's new bank balance multiple-use feature had not been brought into Local Brain through Code Sync. Verified in migration history: `20261016_bank_manual_transaction_admin_only` contains an explicit LOCAL LEGACY path that preserves full-payment status=USED behavior and does not enable `bb_bank_balance_allocations` partial debit logic.

Cloud read-only evidence:
- Real bank wallet allocations: multiple payments may reference one registered bank transfer.
- `bb_bank_balance_snapshot` derives `used_amount` from `bb_bank_balance_allocations` and `remaining_amount = original - active allocations`.
- `private.bb_bank_guard_payment()` atomically locks transfer ID, requires AVAILABLE status/customer match, validates currency/rate/bank, checks remaining amount, writes allocation, and marks USED only when exhausted.
- `public.bb_bank_validate_invoice_input()` validates remaining balance and approved exchange rate.
- `public.bb_invoice_bank_bulk_sync()` returns remaining amounts to manual Sync Bank.
- `public.bb_customer_bank_balance_list_v2(text)` returns remaining balance for Invoice/A-R staff.
- Bank Register transaction itself remains UNIQUE even though payments may share the ID. Admin-only manual/unregistered transfer rule remains.
- Read-only Cloud balance summary at preparation: 9 partially used AVAILABLE wallets; 76 available wallets; 124 USED; 0 negative remaining. Allocation ledger: 118 rows across 114 transaction IDs.
- Confirmed duplicate reference `179195231042684` has 3 allocation rows; two other references have 2 rows each.

New **Code Sync only** SQL migration registered after normalized payment-index compatibility:
`local-db-migrations/20261025_bank_partial_use_cloud_parity_v1.sql`

Includes guards against unfamiliar Local bank functions and missing tables/columns/view/triggers; snapshots no business data and never manually creates payment/expense/balance rows. Installs seven exact Cloud function definitions and checks payment wallet-edit guards and authenticated-only RPCs. Read-only Cloud migration preflight and postflight have passed. **Local execution is NOT YET CONFIRMED**. If a guard rejects a different Local code version, inspect Code SQL Migration report rather than bypass or weakening rules.

Order: Code Sync first (index migration, then bank partial-use migration), then fresh Cloud → Local business data sync. Verify prior payment/expense reconciliation and make a separate controlled test of bank allocation across more than one invoice on Local only after reviewing current real balances. Do not create real accounting test payments without authorization.


## 2026-10-25 23:49 — Same Stage 6 payments_lower_idx error after prior migrations

A new screenshot confirms a repeat of the **same Step 6 COPY staging error**:
- \`psql:/tmp/08B-cloud-stage-data-v1.2.sql:3037\` rejected duplicate normalized transaction_id \`179195231042684\`.
- Cloud staging was created, \`COPY payments\` failed on line 643.
- 08C did not start, no committed merge and no successful SYNC-REPORT.txt.

**Diagnostic distinction:** the index migration fixes \`public.payments\`, but the COPY uses
\`bb_cloud_stage.payments\`, which can still have a separately created/cloned
UNIQUE \`payments_lower_idx\`. A successful Code Sync migration must be verified
on Local; the screenshot alone does not prove it was applied.

**Safe supplemental fix committed:**

- \`local-db-migrations/08D-CHECK-STAGE-PAYMENTS-INDEX-V1.sql\` is **staging-only** SQL, NOT a permanent app-schema migration. Do NOT register in \`manifest.json\` or run manually. The Cloud→Local controller invokes it after 08B staging creation, before COPY.
- It checks \`public.payments\` PK and NON-UNIQUE lookup index READ-ONLY, and the partial-use wallet guard from Code Sync. If Local Code Sync did not succeed, it stops with \`BANK_STAGE_STOP\` and instructs the operator to fix Code Sync.
- Only a verified obsolete UNIQUE \`lower(trim(transaction_id))\` **temporary stage index** is removed; it does not drop the Local payment index or edit business records, payment IDs, wallet allocations or bank registration constraints.
- Unknown indexes, constraint-backed indexes or absent prerequisites fail closed before COPY.

**Windows controller installer V2:**
- \`local-db-migrations/V34-INSTALL-STAGE-PAYMENTS-PARITY-V2.ps1\` verifies stage SQL SHA-256, locates precisely one 08 controller, backs up before patching, and installs a one-time Step 6 stage-helper invocation.
- If the controller is exactly the original V1.2 SHA, the installer first calls the Code-Synced V1 business-only/read-only updater, then installs V2. If the controller is unexpectedly modified, it stops rather than overwriting.
- Existing \`local-db-migrations/INSTALL-BUSINESS-ONLY-STAGING.cmd\` now calls V2. **Still a one-time Windows installer, not SQL manually executed**; Code Sync copies source but does not automatically write to a separate Local Windows controller folder.
- The installer itself runs **no SQL, no Cloud→Local merge and no business-data changes**.

**Safe execution sequence**:
1. Code Sync: confirm successful application of \`20261025_payment_transaction_index_cloud_parity_v1\` and \`20261025_bank_partial_use_cloud_parity_v1\` in the SQL migration report.
2. Run synced \`INSTALL-BUSINESS-ONLY-STAGING.cmd\` once. Verify it prints \`Stage 6 payment-index compatibility check INSTALLED\` and a controller backup path.
3. Run a **fresh** Cloud→Local (old staging was a failed partial import), not a resume.
4. Step 6A reports \`BANK_STAGE_PARITY_OK\` before \`COPY payments\`. If \`BANK_STAGE_STOP\` occurs, do not bypass; collect report.
5. Only a committed Step 8 SYNC-REPORT means the business merge succeeded. Then reconcile CHEA KIMSUN request #22 and expenses EXP-000024 / EXP-000025 and inspect reused bank reference allocations.

**Deployment status:** GitHub source updated. Local Windows controller, Code Sync application, Step 6A result and 08C merge have NOT been verified; no accounting records touched by this preparation. The exact 08B source is still unavailable, so the stage-only guard uses index definition checks instead of unverified blind 08B text replacement.
