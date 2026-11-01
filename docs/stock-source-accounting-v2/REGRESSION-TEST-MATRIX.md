# Source-specific stock / COGS regression matrix — STAGED (31-Oct-2026)
**No production deployment.** Live ledger audited read-only; no data changed.

## Preflight snapshot
- 2,643 original physical-product sale-line records are traceable by invoice line ID.
- 2 mixed Purchased+Zero-Cost original invoice-product sales.
- 7 sale-line records already have recorded source returns.
- 0 historical return-source overages found.
- 3 purchased-source sale lines have zero original line_value; preserve **recorded** COGS ($0) and flag for manual historical audit; do not replace using today's average.

## Functional fixture scenarios
| Scenario | Inputs | Expected | Status |
|---|---|---|---|
| Purchased Batch Sale | Batch P=20 Z=10, sell P=3 Z=0 | Batch P=17 Z=10; 3× original moving avg COGS | Test on isolated DB |
| Zero-Cost Batch Sale | P=20 Z=10, sell P=0 Z=2 | P=20 Z=8, COGS 0 | Test on isolated DB |
| Mixed Batch Sale | P=20 Z=10, sell P=3 Z=2 | P=17 Z=8, COGS only 3 purchased | Test on isolated DB |
| Purchased Back Sale | P=17 Z=8, return P=2 Z=0 | Batch P=15 Z=8; Warehouse purchased +2 | Test on isolated DB |
| Zero-Cost Back Sale | P=17 Z=8, return P=0 Z=3 | Batch P=17 Z=5; Warehouse zero-cost +3 | Test on isolated DB |
| Mixed Back Sale | P=17 Z=8, return P=2 Z=3 | Batch P=15 Z=5; Warehouse P+2 Z+3 | Test on isolated DB |
| Partial Invoice Reversal | Original sale P=3 Z=2, return P=1 Z=1 | Batch P+1 Z+1; COGS reverse original purchased cost ×1 | Test on isolated DB |
| Later Partial Reversal | Original P=3 Z=2, previously reversed P=1 Z=1, now return P=2 Z=1 | Original source remaining exhausted; no over-return | Test on isolated DB |
| Invalid split | Qty=5, P=3 Z=1 | Hard reject; no stock or invoice committed | Test on isolated DB |
| Wrong product | Invoice line Product A, return Product B | Hard reject | Test on isolated DB |
| Insufficient source | Only zero 2 remains, choose zero 3 | Hard reject atomically | Test on isolated DB |
| Group invoice | Original Group A allocated Product X P2 Z1 and Product Y P1 Z0 | Reversal source selection separately on X and Y | Test on isolated DB |
| COGS changed since sale | Sale cost $0.45, today's average $0.50 | Reversal COGS uses $0.45, never $0.50 | Test on isolated DB |
| Legacy exact one-source | Old invoice only original P sold, no source payload | Auto fill original sole source, validate original record | Test on isolated DB |
| Legacy exact mixed-source | Old invoice P+Z sold, no explicit source | Hard reject; accountant must select | Test on isolated DB |
| Legacy group without source | No physical-product source selections | Hard reject; no guessed group product | Test on isolated DB |
| Closed Batch | Return source to Warehouse or new same-location Batch | Original Closed Batch unchanged | Test on isolated DB |
| Duplicate invoice number | Different invoice IDs with same invoice_no | Only original line_id's ledger records count | Test on isolated DB |
| Selling units | 2 cartons × 12 units, mixed source P18/Z6 | Allocations and COGS in base units, Invoice Qty matches base | Test on isolated DB |
| Rapid double-submit | Same invoice/return submitted twice | Existing request/return uniqueness blocks duplicates | Test on isolated DB |
| Offline migration | Local V5/V6 Code Sync then local-only Back Sale and Sale | No cloud dependency; Cloud ↔ Local stays reconciled | Test after migration |

## Release gates
1. SQL **not deployed**; 2 staged SQL files + source preview, no schema changes yet.
2. The original-source reversal interface and BEFORE/AFTER triggers are staged; validate with a **throwaway PostgreSQL copy** to catch syntax/type errors and concurrency.
3. Confirm the history detail, account reports and post-close destination receipt preserve split values.
4. Legacy APK/PWA clients still loading a cached source-agnostic save must be updated or blocked by explicit compatibility check. Never silently fall back to source order.
5. Verify existing damage, batch transfer, adjustment, purchase receiving, borrow clearance, stock close and inventory reports don't break.
6. Register a checksum-verified Local V5/V6 SQL migration and guard against Cloud→Local schema drift. Test local read/save without internet.
7. Apply Cloud backend and frontend under a maintenance gate or atomic-compatible release. Verify read-only reconciliations before and after. Ensure export/rollback definitions exist.
8. Review three historically purchased-source zero-value lines. **Do not automatically edit earlier invoice amounts, COGS or stock.**

## 31-Oct-2026 continued pre-release verification (READ-ONLY)
- Synthetic PostgreSQL source arithmetic SQL: **12/12 passed**. Reproducible via `SOURCE-ARITHMETIC-SMOKE-READONLY.sql`. Tests arithmetic and input rejection **only**, not actual PL/pgSQL function execution.
- Live schema catalog: **31/31 expected stock/invoice/return fields present**.
- Invoice Generator staged `normalizeSimpleBatchRows` was executed on exact and grouped sample data: Purchased and Zero-Cost source availability were preserved for both.
- All ordinary, split-payment and multi-bank invoices reach `bb_sales_save_invoice_bundle_core_access_v1` then `bb_sales_save_invoice_bundle_core_v1`.
- Supabase branch list returned **main only**, so there is no existing isolated development database. Do **not** create a billable Supabase development branch without approval.
- Pre-close staged reversal now **blocks** an original purchased-cost record with zero/null historical cost for manual accounting review, consistent with post-close safeguard. This is not a historical write-off or automatic COGS correction.
- **No staging SQL deployed** to production, no migration manifest registration, no stock or financial data writes.

### Remaining NOT TESTED (hard blockers)
- Actual PostgreSQL `CREATE OR REPLACE FUNCTION` parsing/type resolution and trigger integration in an isolated clone. SQL syntax/compilation cannot be claimed as passed.
- Branch simulation for Live→Local V5/V6 Code Sync, schema guard, offline invoice/Back Sale/reversal flows, and cloud ↔ local merge integrity.
- Cached/stale online PWA, APK, mobile, and other older clients must be blocked or upgraded before strict explicit-source backend activation.
- Group service/non-stock line reversal edge cases, source return report editing, and cross-device concurrent batch updates still require integration regression testing.
- Verify historical sourced COGS ledger and monitor three original purchased-source zero-value sales; manual review only.

## 31-Oct-2026 Warehouse + Pending Batch valuation audit (READ-ONLY)
- Existing official valuation source: `bb_stock_product_rows_zero_cost_v1_internal` values **Purchased Warehouse** and **Purchased Pending Batch** together using `bb_stock_average_cost_internal`, while Zero-Cost quantities contribute $0 to financial stock value.
- **27 products checked**. Current Cloud stock valuation at the time of audit: Warehouse $11,638.60 + Pending Batch $63,751.72 = **total company inventory $75,390.32**. These are current ledger balances, not a guarantee of historical COGS correctness.
- Source balances: Warehouse Purchased 6,457; Warehouse Zero-Cost 3; Batch Purchased 22,877; Batch Zero-Cost 563 (units across different product types; do not use combined unit count as a business KPI).
- **0** source bucket sum mismatches; **0** open-batch snapshot mismatches; **0** closed batch pending-stock products; **0** products with negative company good-stock balances. Repeat with `WAREHOUSE-BATCH-VALUATION-RECONCILIATION-READONLY.sql` on Cloud and Local.
- Historic Back Sale ledger: **311** movements (306 Purchased, 5 Zero-Cost), **0** unexpected source buckets, **0** monetary-value Zero-Cost movements, **0** Purchased line values outside recorded 4-decimal unit-cost / cent rounding tolerance. **One** Purchased return recorded a zero unit cost; flag for manual audit only. Repeat with `BACK-SALE-SOURCE-LEDGER-AUDIT-READONLY.sql`.
- Total company stock value MUST NOT move just because Back Sale transfers unsold stock from Batch to Warehouse; Warehouse and Batch Purchased values should offset at the common current average cost. Invoice sale and reversal legitimately change total unsold stock value and COGS.
- **No production SQL deployed or stock/financial rows modified** during this check.

### Next mandatory release test
- Execute all staged PL/pgSQL definitions and real stock transfers on a **nonproduction copy**, check financial transaction boundaries, effects on ledger/report and rollback, then rerun both audits before/after.
- Do not add migration to Local V5/V6 manifest or merge branches until isolated integration tests pass and the deployment is coordinated for APK/PWA compatibility.


## 01-Nov-2026 — Isolated PostgreSQL Step 1 VERIFIED

**Test evidence:** Windows PowerShell transcript `V2-STEP1-COMPILE-20261101-113936.log`, saved by operator on Desktop. This section supersedes older statements above that SQL compilation was untested.

- Reused the previously captured read-only Local `pg_dump -Fc` snapshot. Test launched a new `--network none` Docker PostgreSQL container with no published ports; no live Local, Cloud, or controller changes.
- PostgreSQL bootstrap/stability checks and sandbox-only cron disable succeeded. Isolated restored stock_activity: **4,245** rows.
- All **10 staged PostgreSQL functions compiled** successfully: **3** source-aware Invoice/Back Sale, **6** source-aware Reversal, **1** read-only Reversal Source Snapshot.
- Synthetic arithmetic smoke: **12/12 PASS** (this proves input arithmetic, not real function execution).
- Warehouse/Batch read-only valuation: **27** products; WH Purchased **6,457**, WH Zero **3**, Batch Purchased **22,877**, Batch Zero **563**; WH value **$11,638.60**, Batch value **$63,751.72**, company inventory value **$75,390.32**. Snapshot/source/closed-batch/negative-stock mismatches: **0**.
- Back Sale historical audit: **311** movements (306 Purchased, 5 Zero-Cost); **0** invalid source buckets, **0** Zero-Cost monetary values, **0** Purchased display-rounding discrepancies; **1** Purchased Back Sale without recorded cost remains for separate manual audit (no automatic accounting edit).
- Test reported `STEP 1 PASSED: STAGED SQL COMPILED + READ-ONLY AUDITS RAN IN ISOLATED DATABASE`. Throwaway test container removed.

**STILL BLOCKED:** SQL compilation does not establish transactional correctness. Before release, run source-specific invoice sale / Back Sale / partial and post-close reversal **through the actual staged functions/triggers** in a disposable database; verify warehouse/batch ledgers, COGS at original purchase cost, invalid-source rollback, duplicate submission, multi-bank/split/offline paths, old APK/PWA compatibility, Local V5/V6 migrations, Salary V2 payment regression, and post-transaction reconciliation. Do not deploy staged SQL or merge frontend PRs yet.

## 01-Nov-2026 — Step 2A actual invoice-trigger test VERIFIED (6/6 PASS)
- Test SQL: `ACTUAL-BATCH-INVOICE-SOURCE-ROLLBACK-ISOLATED.sql`. Uses an existing OPEN mixed-source Batch and existing invoice header from the restored sandbox only.
- Tests the actual `invoice_lines` AFTER INSERT stock trigger and stock_activity/batch snapshots: mixed Purchased 3 + Zero-Cost 2 with source cost validation, Purchased-only 2, Zero-Cost-only 2 at $0, invalid split, Purchased oversell, missing explicit source.
- Each rejected insert uses a PL/pgSQL exception subtransaction; checks no rejected invoice, movement, or stock-balance changes remain.
- Whole fixture runs under explicit SQL BEGIN/ROLLBACK, then separately checks that no synthetic invoice-line or ledger rows survived.
- Dedicated no-network Docker runner and launcher are pinned to GitHub blob hashes. They reuse the verified 01-Nov `LOCAL-V2-READONLY-SNAPSHOT-20261101-112831.dump`. No real Local or Cloud DB connectivity.
- **Test executed successfully on 01-Nov-2026.** All six notices passed, full transaction rolled back, post-ROLLBACK verified no synthetic invoice lines or stock ledger rows remained; isolated Docker container removed. Historical read-only stock valuation still $75,390.32. Evidence: operator screenshot on 01-Nov-2026 (Step 2A) and prior Step 2A log. Original assertion was over-precise; verified column storage is stock_activity.unit_cost numeric(18,4), line_value numeric(18,2), and replaced assertion with correct 4dp/2dp checks. No stock accounting logic was changed. **Back Sale and pre/post-close Reversal real trigger tests remain release blockers.**


## 01-Nov-2026 — Step 2B actual Back Sale function PREPARED / NOT RUN
- Test SQL `ACTUAL-BACK-SALE-SOURCE-ROLLBACK-ISOLATED.sql` executes staged `bb_stock_save_batch_reference_internal(..., 'BACK_SALE')` on a throwaway PostgreSQL copy, selecting a real active test actor who has access to the existing open Batch and warehouse in the copied database. Permissions remain enabled.
- Seven cases: mixed Purchased 3 + Zero-Cost 2, Purchased-only 2, Zero-Cost-only 2, duplicate request idempotency, invalid source split, Purchased oversell, missing explicit source. Checks source-specific warehouse ledger buckets, cost precision, batch snapshot balances, no writes for rejected requests, and post-rollback deletion of all synthetic rows.
- One-command runner `RUN-BB-STOCK-SOURCE-V2-STEP2-BACKSALE.ps1`, pinned to matching SHA source files, executes BOTH Step 2A invoice test and Step 2B Back Sale test with `--network none`, no published ports, full SQL rollback, and explicit DB-name guard. Uses existing 01-Nov read-only Local backup; no new production database connections.
- Staged backend Back Sale response metadata corrected to say explicit source allocation rather than automatic Purchased-first. No production code deployed.
- **Step 2B has NOT run yet.** Pre/post-close Reversal, stale client compatibility, Salary V2/Local migration, and live deployment remain blocked.

## 01-Nov-2026 — Supabase Branching validation BLOCKED by historical migrations
- User approved temporary Supabase Branch compute quoted by Supabase at USD **0.01344/hour** (+ usage); branch `stock-source-v2-validation-20261101` was created from production main.
- Supabase branch status reported `MIGRATIONS_FAILED` **before Stock Source V2 SQL was installed**.
- Branch Postgres logs identified first replay failure: `relation "public.clients" does not exist` while executing function `public.bb_client_editor_revision()` in initial `clients_editor_auth_rls_rpc_v1` migration. This function assumes business tables already existed on main, but fresh branches do not clone the live schema.
- Branch migrations list and public tables were empty when checked. **No V2 test was performed against the branch**; no branch migrations were merged.
- The failed branch was deleted successfully and subsequent `list_branches` confirmed **main only**. Production was not modified.
- **Separate prerequisite:** safely reconcile migration history with live schema (e.g., baseline schema captured from actual production/Local schema, then independently replay and verify), before creating a new Supabase test branch. Do not repair migrations on production merely to make a test pass. Keep Stock Source V2 SQL staged.

## 01-Nov-2026 — Automated no-network GitHub Actions safety check VERIFIED
- Workflow: `.github/workflows/stock-source-v2-safety-ci.yml` (feature branch only; no production credentials).
- GitHub Actions run [41276642239](https://github.com/angsokhey11-cloud/big-brother-dashboard/actions/runs/41276642239) completed SUCCESS on commit `e325685c5f76f31045e6ae452db532e25cd2eebd`.
- `pglast` SQL grammar: 3 source-aware functions, 6 reversal functions, 1 source snapshot function all parsed successfully.
- Disposable `postgres:17` Docker container with `--network none` ran `SOURCE-ARITHMETIC-SMOKE-READONLY.sql`: **12/12 PASS**, container removed.
- This automatic feature-branch CI provides continuous grammar + pure arithmetic coverage without Supabase Branching cost or repeated Windows screenshots. It **does not** establish live trigger correctness, API authorization, stock-history regression, or Local migration safety.
- Production remains untouched. Existing 01-Nov isolated Local PostgreSQL Invoice Sale tests remain separately verified 6/6; Back Sale and Reversal pending.

## 01-Nov-2026 — Automatic CI extended to PowerShell schema export and Step 2B runners
- Workflow [run 41276832799](https://github.com/angsokhey11-cloud/big-brother-dashboard/actions/runs/41276832799) **SUCCESS** on feature commit `50f36d93d4ba4a83728db4402b0d4d29cce73b07`.
- Checks: PostgreSQL grammar for 10 staged functions; PowerShell parser for schema-only export, Back Sale test launcher and isolated runner; PostgreSQL 17 synthetic arithmetic **12/12 PASS**. Disposable test container removed.
- Added one-time schema-only export helper `EXTRACT-LOCAL-SCHEMA-ONLY-NONDESTRUCTIVE.ps1`; uses existing Local snapshot in `--network none` Docker; no real database access, no data rows, and no automatic publish. Function text may contain secrets; review before sharing.
- Still **NOT** a complete branch migration-replay fix or actual Back Sale / Reversal trigger integration test.
