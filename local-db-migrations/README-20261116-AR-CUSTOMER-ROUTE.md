# BIG BROTHER — A/R Collection by Customer Assigned Location (16-Nov-2026)

STATUS: Cloud DB + desktop/mobile code updated. Local Brain V5/V6 migration is PREPARED but NOT YET INSTALLED on the Windows host.

## Correct business rule

- **Customer route for A/R:** customers.location_code (current customer directory location).
- **Sales/stock route:** invoices.location_code, unchanged and still used for sales history, batch stock and original Cash Sales DCC source.
- A/R collection access and route filtering must follow the customer. A Phnom Penh sale of stock to a Takeo customer should still allow an authorized Takeo salesman to request receivable cash.
- The main A/R list, All Receivable, invoice payment detail, Direct Request creation, registered-bank recommendations, A/R Cash Picker and both combined request handlers are aligned to the customer route.
- Old A/R and Sales Cash may have different sale/customer locations in one physical handover. Both routes are verified separately. The actual Daily Cash close still follows its existing sales location + salesman rules.
- Current customer location is authoritative; if you move a customer to a new assigned route later, collection responsibility follows that customer without rewriting historical invoices. Outstanding, COGS, bank, stock and sales locations are never changed by the migration.
- No automatic A/R payment or Cash Vault entry from selection/submission; Admin approval is unchanged.

## Local Brain procedure
1. Finish/pause any pending Cloud->Local or Local->Cloud sync. Take a verified backup of your local-only transactions and files.
2. Run Control Center **Code Sync** to update both big-brother-dashboard and big-brother-daily-cash-collection. Stop if repositories are skipped/dirty. The file names must be current.
3. On the LOCAL Windows PC open:
   D:\BIG BROTHER Local Backup\Local Brain\Code Sources\big-brother-dashboard\local-db-migrations
4. Run **CHECK-LOCAL-AR-CUSTOMER-ROUTE.cmd**. This is CHECK ONLY; it tests all 12 existing local RPCs and required tables. If it reports a missing function, STOP and share the exact error; don't force the installer.
5. After a clean preflight, run **INSTALL-LOCAL-AR-CUSTOMER-ROUTE.cmd**, type APPLY. Installer creates a full independent local PostgreSQL backup in:
   D:\BIG BROTHER Local Backup\Local Brain\brain-backups\ar-customer-route
   then runs the guarded SQL in the exact running LOCAL Docker Postgres container supabase_db_Local_Brain.
6. Refresh your Local Brain desktop/mobile A/R and collection pages. Confirm the browser calls LOCAL Supabase, not cloud.

## Checklist (no real submission required to start)
- In the A/R Cash picker, filter by Customer Assigned Location = TK-01 (Takeo).
- Confirm INV-7891 and INV-1711 belong to customer CUS-0239 in TK-01, while showing PP-01 only as original sale source.
- Verify another customer's route can be selected independently of the sale source.
- Confirm unauthorized staff cannot see/manage customers outside their authorized customer routes.
- Confirm no A/R request is created until user clicks Submit.
- If you intentionally test a real submission, A/R still goes only to the existing Pending Receivable screen and needs Admin approval; Daily Cash still goes separately to Pending Daily Cash.
- Do not use Local->Cloud upload while this patch is being tested.

## Local files
- 20261116_ar_customer_route_LOCAL_ONE_SHOT_V1.sql
- V34-LOCAL-AR-CUSTOMER-ROUTE-V1.ps1
- CHECK-LOCAL-AR-CUSTOMER-ROUTE.cmd
- INSTALL-LOCAL-AR-CUSTOMER-ROUTE.cmd

## Safety
- Local SQL changes function definitions/permissions, never customer, invoice, payment, bank, stock, or financial rows.
- Requires local migration prerequisites. It does not automatically install through manifest.json.
- Installer: check-only unless explicitly invoked with -Apply and a mandatory local full DB backup.
- This may be used after the previous combined collection upgrade; do not install against an older, mismatched local schema.
- Does not require Cloud->Local data refresh to change functions. Source files and SQL install are distinct.
- The actual Local Brain environment is not accessible in this chat; the operator must run the checks on the Windows PC.
