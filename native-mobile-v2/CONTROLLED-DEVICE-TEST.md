# Online V2 controlled device check
V11 signed/debug builds passed (runs 45337326627 / 45337326539); recovery and arithmetic tests passed. Initial PostgreSQL suite failed because synthetic bank balance view lacked customer_id, required by deployed core. Fixture only corrected, view now includes customer_id/status/currency/original_amount. Await regression rerun.
Test the signed development package com.bigbrother.online.v2dev (not production).
1. Login as admin and authorized staff separately. Check route access and dashboard.
2. Generator: select direct sale, location/customer, search product; compare live warehouse quantities and customer price with existing app.
3. Select open batch, check selling date restriction, exact purchased and zero-cost quantities, group quantities; validate after changing draft.
4. Compare carton conversion, discount, six payment calculations, both FX directions, bank receipt dates and registered transfer selection.
5. Native A4 preview: check Khmer names, long product names, multi-page, credit terms, subtotal/paid/outstanding and watermark.
6. Read-only duplicate check and recovery status. Do not use test invoices in production. Complete must remain disabled and preview must not be registered, shared or printed as a real invoice.
7. Invoice History: test existing read-only PNG, PDF and printing using already-saved invoice, if authorized.
No Local changes. This is device-test preparation, not production readiness.
