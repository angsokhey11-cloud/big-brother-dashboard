# 21-Nov-2026 · Local Brain Code Sync — direct-sale stock guard blocker

## Grounded input
Local report: `LOCAL-STOCK-TRIGGER-CHECK-20261121-185736.txt`.

- Local container: `supabase_db_Local_Brain`, database `postgres`.
- Both stock triggers exist and are enabled: legacy `trg_invoice_lines_stock_direct_sale` runs ONLY on lines without a `source` key; the `source_v1` trigger runs ONLY on lines with that key.
- The required main function's explicit source-aware skip pattern was not found.
- The source-aware function's Batch early-return pattern was not found.
- The existing direct-sale reversal function Batch early-return guard passed.
- 18:52 Code Sync earlier stopped before any of its seven pending migrations were applied, with an automatic local backup.

## Minimal additive fix
The approved SQL manifest now places `20261103_0_restore_stock_trigger_guards_v1.sql` immediately **before** `20261103_a_direct_sale_warehouse_source_v1.sql`.

The new migration:
1. Requires the **exact** trigger pair and mutually exclusive WHEN definitions from the local diagnostic. Aborts otherwise.
2. Uses `pg_get_functiondef` to preserve each current Local Brain function and adds only the necessary early-return guard when the check fails. It never replaces a function with the entire Cloud implementation.
3. Main function: if `v_invoice.batch_id IS NULL` and the line has an explicit source, skip the old handler. Source-aware function: if `v_invoice.batch_id IS NOT NULL`, exit without treating a Batch sale as Direct Sale.
4. Requires the two original November 3 regex safety checks to pass after the patch, or aborts the controller transaction.
5. Has no direct table DML, no stock movement updates, and no invoice/COGS modifications.

The original `20261103_a...` migration itself is unchanged; it retains all its historical stock reconciliation and validation guards.

## Operator steps
1. Keep the original 18:52 backup stored at `brain-backups/code-sql-migrations/20261121-185207/local-before-code-sql.dump`.
2. From the V3.4 Control Center use **Code Sync → SQL Migration Code Sync** with the refreshed trusted manifest. Keep normal confirmation, backup and rollback protections enabled.
3. The next report should show `20261103_0_restore_stock_trigger_guards_v1` before `20261103_a_direct_sale_warehouse_source_v1`. If not, verify the dashboard GitHub commit/manifest refresh.
4. If ANY step fails, do not skip it and do not mark it applied manually. Share the new Code Sync report. A new guard error identifies the next specific incompatibility.
5. Confirm the local invoice stock behavior with controlled test records only after the migrations actually report success: source-aware Direct Sale deducts warehouse once; Batch Sale deducts only the batch.
6. This repair **does not install the 21-Nov Batch Selling Date Range editor database patch**. That patch is separate and needs a later local rollout when this Code Sync blocker is cleared.

## Scope
This is a targeted response to one observed Code Sync failure. It is not a full Local Brain migration audit, and success of the prerequisite guard does not guarantee that all older pending migrations are compatible.
