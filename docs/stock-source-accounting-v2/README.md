# BIG BROTHER — Stock Source Accounting V2 (STAGED)
Date: 31-Oct-2026

## Current root cause (confirmed)
- `bb_stock_invoice_line_after_insert`: batch invoice chooses ZERO-COST first.
- `bb_stock_save_batch_reference_internal`: Back Sale chooses PURCHASED first.
- Mixed-source batches can therefore misclassify the source of sold vs returned units and distort COGS.
- Do not retrospectively change historical source allocations without an audited reconciliation.

## Proposed new stock movement contract
Every future Batch Invoice allocation for each exact underlying product:
`{productCode, qty, purchasedQty, zeroCostQty}`
where purchasedQty + zeroCostQty = qty, all nonnegative, and each selected source must have sufficient batch stock.

Every Back Sale line:
`{productCode, qty, purchasedQty, zeroCostQty}`
with the same sum and availability validation. Purchased returns go to WAREHOUSE_GOOD, zero-cost returns to WAREHOUSE_ZERO_COST. Purchased COGS remains based on the existing average-cost machinery; zero-cost movements carry zero cost. No direct crossing from zero-cost to purchased.

## Staged changes
- SQL **not deployed**: `docs/stock-source-accounting-v2/20261031_source_aware_batch_sale_and_back_sale_STAGED.sql` on this branch.
- Invoice Generator staged: source selector + purchased/zero-cost group member availability; exact/group per-product allocations, client validation.
- Stock Management staged: Back Sale source selector + source-specific movement payload on mobile and desktop.
- All staged on `feature/stock-source-accounting-20261031`, not on production `main`.

## Mandatory unfinished checks — block production
1. **Reversals:** `bb_batch_return_stock_internal` currently reverses PURCHASED first, not necessarily the source of the original line. `bb_postclose_reversal_stock_v1` also chooses purchased first. A source-specific reversal allocation and original-sale tracking must be implemented, including mixed invoices, partial reversals, and prior returns. Do not release before this is complete.
2. **Other invoice endpoints:** verify `bb_sales_save_invoice`, split, wallet, multi-bank, mobile, and offline client compatibility. All must honor the new source allocations or fail closed.
3. **Browser tests:** source selector behavior for exact product, product group, mixed source, selling-unit factor, multiple lines for one product, services, qty edit/remove, selected batch switch, old cached PWA and APK.
4. **Stock Key-in tests:** manual Back Sale, saved report reload, Source Purchased, Source Zero-Cost, Mixed, insufficient per-source qty, duplicate product, quantity edit, batch switching, staff permission.
5. **Accounting tests:** purchased and zero-cost stock ledgers, zero COGS on zero-cost sales, purchased average-cost COGS, Warehouse transfers, returned source, no silent redistribution, reversal allocation, reconciliation reports.
6. **Local V5/V6:** register new guarded SQL migration with correct SHA in local manifest, code sync both servers, test Cloud↔Local schema guard and data merge with protected salary/payment records; do not require live cloud connectivity to local transactions.
7. **Migration sequencing:** deploy backend + compatible frontend atomically or with a maintenance gate; prevent old cached clients from silently running source-agnostic sales/returns.
8. **Rollback plan:** export pre-deployment function definitions and trigger settings; no historical row updates. A SQL rollback must restore legacy functions but must not reinterpret allocations already stored by V2.

## Safe example
A batch has Purchased 20 and Zero-Cost 10. Invoice sells Purchased 3 + Zero-Cost 2. Remaining is Purchased 17 + Zero-Cost 8. Back Sale returns Purchased 1 + Zero-Cost 3. Warehouse receives purchased 1 and zero-cost 3; the batch remains Purchased 16 + Zero-Cost 5. Sold purchased 3 carries average cost; sold zero-cost 2 carries zero cost.

**Release status: BLOCKED (prototype only)** until reversal and Local regression tests pass.

## Reversal provenance investigation (31-Oct-2026)
- Confirmed pre-close reversal `bb_batch_return_stock_internal` restores PURCHASED first and values its return with **today's** average cost; both need replacement to faithfully reverse the original sale.
- Confirmed post-close `bb_postclose_reversal_stock_v1` already reads the original sale cost, but for a mixed-source *partial* return still chooses PURCHASED first; this must become accountant-selected when both sources remain.
- Confirmed BEFORE trigger `bb_batch_return_allocate_internal` rewrites the return `stock_allocation_json`, so the selected quantities must be propagated through this trigger too.
- In a read-only live ledger reconciliation, 2,643 original per-product sale records could be linked to their invoice lines; 2 records used both sources on one invoice line. These historical transactions must remain untouched pending audit.
- Added **STAGED ONLY** read-only `20261031_reversal_source_snapshot_STAGED.sql` to provide each physical product's original Purchased/Zero-Cost sales, prior returns, remaining source quantities, historical Purchased cost, and mismatch flag.
- Invoice Reversal app staged separately: source snapshot displayed by invoice line, with mismatch warnings, no change to current save function.

### Additional release blocker
- Implement an explicit **reversal-source picker** for mixed Batch Invoice lines and group-member products. Send exact return source quantities per physical product to all reversal save paths, and ensure BEFORE/AFTER and post-close stock triggers validate original per-line sale provenance and previous returns.
- Use the **historical purchase sale cost** for both pre-close and post-close COGS reversal, never current average cost.
- Include the Invoice Reversal repository in Cloud/Local code parity and end-to-end regression.
