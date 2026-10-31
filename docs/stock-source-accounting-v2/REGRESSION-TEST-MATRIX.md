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
