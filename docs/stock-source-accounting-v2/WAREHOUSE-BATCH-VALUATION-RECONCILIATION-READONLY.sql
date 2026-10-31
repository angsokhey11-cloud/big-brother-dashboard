-- BIG BROTHER: WAREHOUSE + BATCH SOURCE VALUATION RECONCILIATION
-- READ-ONLY. No write, no migration, no schema changes. Can be run on Cloud or Local V5/V6.
-- Total company unsold inventory includes Purchased Warehouse + Purchased Pending Batch.
-- Zero-Cost stock is counted physically but contributes $0 to financial stock value.
-- This is CURRENT average-cost stock valuation, not original historical COGS.
--
-- Source balances: public.bb_stock_product_rows_zero_cost_v1_internal() is
-- independently ledger-derived and values Purchased stock only.
-- Batch snapshots: direct public.stock_batch_items per OPEN batch.
WITH valuation AS (
  SELECT product_code,warehouse_good,warehouse_zero_cost,
         batch_pending,batch_zero_cost,total_purchased_good,total_zero_cost_good,
         total_good,average_cost,warehouse_value,batch_value,total_value
  FROM public.bb_stock_product_rows_zero_cost_v1_internal()
), batch_snapshots AS (
  SELECT bi.product_code,
    coalesce(sum(bi.purchased_pending_qty_snapshot)
      FILTER(WHERE upper(coalesce(b.status,''))='OPEN'),0) AS open_purchased,
    coalesce(sum(bi.zero_cost_pending_qty_snapshot)
      FILTER(WHERE upper(coalesce(b.status,''))='OPEN'),0) AS open_zero,
    coalesce(sum(bi.pending_qty_snapshot)
      FILTER(WHERE upper(coalesce(b.status,''))='CLOSED'),0) AS closed_pending
  FROM public.stock_batch_items bi
  JOIN public.stock_batches b ON b.batch_id=bi.batch_id
  GROUP BY bi.product_code
), combined AS (
  SELECT v.*, coalesce(s.open_purchased,0) open_purchased,
         coalesce(s.open_zero,0) open_zero,
         coalesce(s.closed_pending,0) closed_pending
  FROM valuation v LEFT JOIN batch_snapshots s USING(product_code)
), exceptions AS (
  SELECT product_code,
    CASE
    WHEN abs(batch_pending-open_purchased)>0.000001
      OR abs(batch_zero_cost-open_zero)>0.000001 THEN 'BATCH_LEDGER_SNAPSHOT'
    WHEN abs(total_purchased_good-warehouse_good-batch_pending)>0.000001
      OR abs(total_zero_cost_good-warehouse_zero_cost-batch_zero_cost)>0.000001 THEN 'SOURCE_BUCKET_SUM'
    WHEN closed_pending>0.000001 THEN 'CLOSED_BATCH_HAS_STOCK'
    WHEN total_purchased_good< -0.000001 OR total_zero_cost_good< -0.000001 THEN 'NEGATIVE_COMPANY_STOCK'
    ELSE NULL END AS reason
  FROM combined
)
SELECT
  count(*) AS products_checked,
  round(sum(warehouse_good),4) AS warehouse_purchased_units,
  round(sum(warehouse_zero_cost),4) AS warehouse_zero_cost_units,
  round(sum(batch_pending),4) AS pending_batch_purchased_units,
  round(sum(batch_zero_cost),4) AS pending_batch_zero_cost_units,
  round(sum(warehouse_value),2) AS purchased_warehouse_value_usd,
  round(sum(batch_value),2) AS purchased_pending_batch_value_usd,
  round(sum(total_value),2) AS total_unsold_company_inventory_value_usd,
  count(*) FILTER(WHERE abs(batch_pending-open_purchased)>0.000001
      OR abs(batch_zero_cost-open_zero)>0.000001) AS batch_snapshot_mismatches,
  count(*) FILTER(WHERE abs(total_purchased_good-warehouse_good-batch_pending)>0.000001
      OR abs(total_zero_cost_good-warehouse_zero_cost-batch_zero_cost)>0.000001) AS source_sum_mismatches,
  count(*) FILTER(WHERE closed_pending>0.000001) AS closed_batch_stock_mismatches,
  count(*) FILTER(WHERE total_purchased_good< -0.000001
      OR total_zero_cost_good< -0.000001) AS negative_company_stock_products,
  (SELECT coalesce(jsonb_agg(jsonb_build_object('productCode',product_code,'reason',reason)),
      '[]'::jsonb) FROM exceptions WHERE reason IS NOT NULL) AS exception_products
FROM combined;
