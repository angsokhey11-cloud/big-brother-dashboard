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
