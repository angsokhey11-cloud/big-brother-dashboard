-- BIG BROTHER — cloud / Local V5 / Local V6 stock comparison
-- READ ONLY. Run independently on each database and compare product_code rows.
-- Every row is one product, including both cost-source buckets and financial value.
-- Do NOT modify historical rows to make totals agree.
SELECT
  p.product_code,
  p.product_name,
  round(p.warehouse_good,4) AS warehouse_purchased_qty,
  round(p.warehouse_zero_cost,4) AS warehouse_zero_cost_qty,
  round(p.batch_pending,4) AS batch_purchased_qty,
  round(p.batch_zero_cost,4) AS batch_zero_cost_qty,
  round(p.average_cost,6) AS current_purchased_avg_cost,
  round(p.warehouse_value,2) AS warehouse_purchased_value_usd,
  round(p.batch_value,2) AS batch_purchased_value_usd,
  round(p.total_value,2) AS total_company_stock_value_usd
FROM public.bb_stock_product_rows_zero_cost_v1_internal() p
ORDER BY p.product_code;
