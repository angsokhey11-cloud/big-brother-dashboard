# BIG BROTHER — Local 08C Cloud-to-Local V2 Stock Source Guard

**Status:** STAGED, 7/7 isolated no-network regression tests PASSED. **Not deployed to real Local V5/V6.**

## Why this matters

The currently uploaded Local `08C-MERGE-CLOUD-STAGE-PERMANENT-V1.2-STOCK-GUARD-STAGED.sql` pre/post sync guard checked only `stock_activity.from_bucket='BATCH_PENDING'`. V2 invoice sale explicitly uses **two buckets**:
- Purchased: `from_bucket='BATCH_PENDING'`, source key `BATCH-INVOICE:<line-id>:<product-code>:PURCHASED`.
- Zero-Cost: `from_bucket='BATCH_ZERO_COST'`, source key `BATCH-INVOICE:<line-id>:<product-code>:ZERO`.

Cloud and Local could therefore each have a Zero-Cost sale with the same source key and different `transaction_id`, while a generic PK upsert would preserve both and over-deduct stock. This was a real **guard coverage bug**, **not evidence that Cloud currently has duplicate rows**.

Read-only Cloud `public.stock_activity` inspection on 01-Nov-2026: **2,645** sale source movements tracked, **2,624 Purchased** and **21 Zero-Cost**, **0** duplicate source keys and **0** source suffix/bucket mismatches. No customer rows exported.

## Exact standalone patch prepared

Created from the uploaded original staged Local SQL:

- **Output file:** `08C-MERGE-CLOUD-STAGE-PERMANENT-V1.2-STOCK-GUARD-V2-STAGED.sql` (47,869 bytes; SHA256 `035c7039d6492f9e1c7bba1cbd0629271090ae8caa6752745f7baac2cc4019cc`).
- **Review diff:** `08C-STOCK-GUARD-V2-REVIEW.diff`.
- Five source-guard comparisons were extended from just `BATCH_PENDING` to `BATCH_PENDING` **OR** `BATCH_ZERO_COST`: Cloud duplicate, Local duplicate, cross-server collision (both sides), post-merge duplicate.
- Cross-server check rejects both different transaction IDs and **contradictory buckets for the same source key**, even when IDs are identical.
- All pre-existing salary-ID reconciliation, additive-schema assumptions, audit-row deferral, generic Cloud-wins PK merge, stage verification, `session_replication_role` restoration, and other transaction logic remains unchanged.
- This SQL file has **not** been placed into the Local controller folder, nor run against real Local or Cloud.

## Verified automatic CI

[GitHub Actions 41283188860](https://github.com/angsokhey11-cloud/big-brother-dashboard/actions/runs/41283188860): **SUCCESS** in disposable PostgreSQL 17 with `--network none`, cleanup and ROLLBACK verified.

`CI-LOCAL-SYNC-SOURCE-GUARD-V2.sql` mirrors the source-key pre/post checks; `CI-LOCAL-SYNC-SOURCE-GUARD-V2-ASSERTIONS.sql` verifies **7/7**:
1. Identical Purchased and ZERO keys/transaction IDs from both sides accepted.
2. Duplicate Cloud ZERO sale key rejected.
3. Duplicate Local ZERO sale key rejected.
4. Cloud/Local ZERO same source, **different transaction IDs**, rejected.
5. Cloud/Local same transaction ID but mismatched source buckets rejected.
6. Post-merge duplicate Local ZERO sale rejected.
7. Original Purchased cross-server source duplicate still rejected.

**Caveat:** CI tests the extracted guard predicates with fake rows; it does NOT run the entire 08C merge with all 143 business tables, live permission triggers, Salary V2, warehouse history, Local DB, or business data. Never treat a CI pass as approval to deploy.

## Exact Local controller integration dependency

The user-provided `08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2(3).ps1` **does not invoke a filename containing V2/STAGED**. It reads exactly:

`08C-MERGE-CLOUD-STAGE-PERMANENT-V1.2.sql`

from the same Local script directory. When the full V2 release is approved, a controlled, backed-up replacement with the staged V2 content must target **that canonical filename** (and preserve the original file as backup) or this safety fix will not actually be used.

The same runner already enforces:
- Mandatory Cloud-schema additive preflight via `V34-PRE-SYNC-SCHEMA-GUARD.ps1`.
- Mandatory approved-SQL-code verification in check-only mode via `V34-LOCAL-APPROVED-SQL-CODE-GATE.ps1`.
- A full exact-merge **ROLLBACK rehearsal** with required verification sentinels **before** committing the same 08C SQL.
- The Local-only infrastructure replay protections and Salary V2 collision gates.

Retain all of these controls; never remove them to make Stock Source V2 pass. **Do not apply this patch until end-to-end Local/Cloud parity and accounting approval gates are complete.**

## Next gates

- Confirm the **installed canonical Local 08C file's actual hash** during release to ensure it matches the approved staged patch rather than an older copy.
- Test the exact full merge (rollback rehearsal) against **current** real Local V5 and V6 backups, with imported Cloud stage only in disposable containers, then inspect stock, salary, A/R and approved cash for regressions.
- Review the separate Supabase Branching baseline issue: 342 migrations still fail on blank replay because the initial public business-table DDL predates the migration history.
- Audit end-to-end client/PWA/APK permissions and valid bank-refund transactions before deployment.

**Real production/Local modifications this work session: NONE.**
