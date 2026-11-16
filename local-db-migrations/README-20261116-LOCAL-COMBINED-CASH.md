# BIG BROTHER — Local Brain V5/V6 Combined Cash + Old A/R Cash
16-Nov-2026 — PREPARED, NOT YET APPLIED TO LOCAL DATABASE.

## Purpose
Add Old A/R Cash to Daily Cash Collection and Sales Support > Your Collection. The salesman sees one summary, while each type goes through its existing approval: Cash Sales -> Pending Daily Cash; Old A/R Cash -> Pending Receivable. No new A/R payment, bank balance, Cash Vault entry or revenue is created by submission.

## Apply on the LOCAL Windows PC
1. Backup Local Brain and stop active account-data writes or syncs. Start your working V5/Docker and V6 as normal.
2. Use Control Center > Code Sync, updating big-brother-dashboard and big-brother-daily-cash-collection repositories. A skipped/dirty repository must be handled before continuing.
3. Open the folder at D:\BIG BROTHER Local Backup\Local Brain\Code Sources\big-brother-dashboard\local-db-migrations
4. Run CHECK-LOCAL-COMBINED-CASH.cmd. It only checks the running local Docker/Postgres and required existing functions. If a dependency is missing, STOP. Do not use a Cloud repair.
5. Only if the check passes: run INSTALL-LOCAL-COMBINED-CASH.cmd and type APPLY. The installer first backs up the full Local database under D:\BIG BROTHER Local Backup\Local Brain\brain-backups\combined-cash-local, then applies the SQL in one transaction using the LOCAL container supabase_db_Local_Brain.
6. Verify the installer reports 'LOCAL BRAIN COMBINED COLLECTION INSTALLED'. Preserve the backup file. Open the Local Brain dashboard, not a GitHub Pages URL.

## Safety and scope
- The SQL is guarded, transactional and schema/RPC-only, not a cash transaction.
- Installer targets only the exact local Docker container and database postgres; no Cloud API, Cloud->Local, or Local->Cloud upload calls.
- Missing tables/functions STOP the install. Do not bypass them.
- The pending Daily Cash and Pending Receivable request queues are unchanged; Admin separately approves them.
- If local API rewriting fails and the browser still tries to use the Cloud Supabase API, the adapter blocks it. Verify Network calls target Local Brain before testing financial writes.
- Existing mobile offline read-only snapshots stay read-only. Test connected Local Brain V5/V6 first.
- This local SQL is deliberately NOT registered for auto-install by Code Sync manifest; run the guarded installer explicitly.
- Code Sync alone does not install PostgreSQL changes. Cloud changes do not imply Local has changed.

## Test checklist
- Daily Cash Collection and Your Collection on local desktop and mobile show the new Old A/R Cash selection.
- Select Cash Sales + old A/R cash; verify combined USD/KHR preview and same location.
- Submit a small authorized test, then verify one Pending Daily Cash request and one Pending Receivable request in their original Admin approval functions.
- Confirm an invalid A/R invoice or duplicate submission cannot create a partial or second batch.
- Confirm no new actual payment or vault record exists before Admin approval.
- Verify no Cloud API network calls occur from Local Brain.

## Prepared files
- 20261116_combined_collection_LOCAL_ONE_SHOT_V1.sql
- V34-LOCAL-COMBINED-CASH-INSTALL-V1.ps1
- CHECK-LOCAL-COMBINED-CASH.cmd
- INSTALL-LOCAL-COMBINED-CASH.cmd

## Read-only SQL verification on LOCAL database
SELECT
 to_regprocedure('public.bb_sales_support_ar_cash_candidates_v1()') IS NOT NULL AS picker,
 to_regprocedure('public.bb_sales_support_combined_cash_request_v1(jsonb)') IS NOT NULL AS your_collection,
 to_regprocedure('public.bb_dcc_combined_cash_request_v1(jsonb)') IS NOT NULL AS daily_cash,
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.bb_salesman_combined_cash_submissions'::regclass) AS rls_enabled,
 (SELECT count(*) FROM public.bb_salesman_combined_cash_submissions) AS count_combined_submissions;

## Rollback
If the guarded SQL fails, the transaction should roll back. Do NOT restore the entire Local database or run Cloud->Local as a workaround: either could affect unrelated local-only transactions. Retain the backup and the exact error for a targeted fix.

## Outstanding verification
Actual V5/V6 local deployment, local PostgreSQL compatibility, Local Brain API rewrite, and real end-to-end submission are NOT yet tested on the Windows host.
