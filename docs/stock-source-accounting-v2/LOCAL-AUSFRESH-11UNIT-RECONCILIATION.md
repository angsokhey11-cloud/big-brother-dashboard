# Local Brain Ausfresh 2L stock variance — audited staging note
Date: 31-Oct-2026 (Cambodia)
Status: **ISOLATED DRY RUN PASSED; REAL LOCAL DATABASE NOT REPAIRED**

## Problem
- Cloud stock_activity count: **4,245**; Local PostgreSQL restored backup count: **4,247**.
- Product AF-2L / Ausfresh 2L; Batch BAT-000021 (Closed).
- Cloud Purchased Batch balance for AF-2L: **3,871 units** across all Batches.
- Local Purchased Batch balance for AF-2L: **3,860 units** across all Batches.
- Cloud company stock value **$75,390.32**; Local **$75,346.90**.
- 11 units difference attributed to two additional Local-only transactions for the same original invoice-line stock source:
  * TRX-000973 — 6 units (extra).
  * TRX-002412 — 5 units (extra).
  * TRX-004408 — 6 units (canonical Cloud stock deduction).
- Shared client_request_id: `BATCH-INVOICE:LINE-1791033509925-ba44r4:AF-2L:PURCHASED`.
- Cloud invoice: INV-2346, dated 02-Oct-2026, customer ANG KINY, invoice line 6 Ausfresh 2L.
- Cloud stock ledger has zero duplicate BATCH-INVOICE source IDs. Cloud contains TRX-004408, not the two extra Local IDs.
- Local Cloud→Local sync report COMMITTED (31-Oct-2026 17:13 Cambodia), 357 Local-only historical rows deliberately preserved, no deletes.

## Backup and isolated test
- Existing Local backup: `BIG-BROTHER-LOCAL-BACKUP-20261031-175347.dump` saved to user's PC Desktop, PostgreSQL custom archive, checked by pg_restore -l.
- Local DB Supabase image PostgreSQL 17.6.1.166, primary container `supabase_db_Local_Brain`.
- Separate no-network temporary container `bb-stock-v2-isolated`, isolated DB `bb_stock_v2_retry`; restore completed, 4,247 stock movement rows.
- Authorized role for isolated SQL repair simulation: supabase_admin (ordinary postgres role lacks DELETE permission).
- Isolated simulation ran `BEGIN; ... guarded DELETE 2; ... ROLLBACK;`:
  * BEFORE: AF-2L batch Purchased qty 3,860; average_cost 3.988749; AF-2L total value $18,116.90.
  * SIMULATED: batch Purchased qty 3,871; average_cost 3.988650; AF-2L total value $18,160.32.
  * SIMULATED company total $75,390.32 **EXACT CLOUD MATCH**.
  * AFTER ROLLBACK: back to 3,860, 3.988749, $18,116.90.
- This proves the proposed removal exactly reconciles the observed inventory quantity and value on the isolated data copy. It does NOT prove there are no undocumented external references or all historic invoices are correct.

## Live Local correction gate — NOT AUTHORIZED / NOT EXECUTED
1. Keep the pre-change `.dump` safe and privately held. Do not upload the backup.
2. Identify and protect Local-only legitimate records; do not blanket-delete the 357 history rows.
3. Reconfirm the TWO candidate rows on **live Local only** including transaction IDs, AF-2L, batch, source, invoice-line reference, quantities, and Cloud's canonical TRX-004408. Validate the reference isn't used by an offline queue or other accounting process.
4. Export the two full historic transaction rows externally, separate from the backup, to preserve traceability.
5. Run a purpose-built, restricted, guard-checked, atomic Local-only correction with explicit operator approval, audit record, and a post-correction report check. No unrestricted Stock Adjustment; no changes to Cloud.
6. Verify live Local: AF-2L qty 3,871, AF-2L avg 3.988650, AF-2L value $18,160.32, company value $75,390.32, stock activity count 4,245, no duplicated invoice-line source entries.
7. Re-run guarded Cloud→Local check only when needed; monitor preservation/merge for recurrence. Avoid Local→Cloud upload while duplicate Local-only entries exist.
8. SQL V2 migration and Cloud/Local Code Sync **remain blocked** pending separate compile/integration verification.

## Caveats
- Cloud `stock_activity` currently has no declared inbound foreign keys, but application-level references are not ruled out.
- `stock_activity` has an AFTER DELETE audit trigger; retain separate external transaction evidence because audit logging can have exceptions.
- The two candidates are historic Local-only sale deductions, not new inventory or purchase valuation adjustments. A correction must preserve invoice revenue, cash/bank payments, receivables and proper record provenance.
