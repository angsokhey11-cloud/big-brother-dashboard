-- BIG BROTHER Back Sale purchased/zero-cost transfer ledger audit
-- READ-ONLY. No writes and no effect on Cloud or Local.
-- A transfer must be BATCH_PENDING -> WAREHOUSE_GOOD (Purchased) or
-- BATCH_ZERO_COST -> WAREHOUSE_ZERO_COST (Zero-Cost).
-- unit_cost may be stored with 4 decimals while line_value has cent rounding
-- of an underlying higher-precision average: tolerance = qty*0.00005 + $0.005.
WITH items AS (
 SELECT transaction_id,product_code,qty,unit_cost,line_value,
        from_bucket,to_bucket,
        CASE
          WHEN from_bucket='BATCH_PENDING' AND to_bucket='WAREHOUSE_GOOD' THEN 'PURCHASED'
          WHEN from_bucket='BATCH_ZERO_COST' AND to_bucket='WAREHOUSE_ZERO_COST' THEN 'ZERO_COST'
          ELSE 'WRONG_SOURCE'
        END AS source,
        abs(coalesce(line_value,0)-coalesce(unit_cost,0)*qty) AS value_gap
 FROM public.stock_activity
 WHERE movement_type='BACK_SALE'
)
SELECT
 count(*) back_sale_lines,
 count(*) FILTER(WHERE source='PURCHASED') purchased_return_lines,
 count(*) FILTER(WHERE source='ZERO_COST') zero_cost_return_lines,
 count(*) FILTER(WHERE source='WRONG_SOURCE') invalid_bucket_lines,
 round(coalesce(sum(qty) FILTER(WHERE source='PURCHASED'),0),4) purchased_units_returned,
 round(coalesce(sum(qty) FILTER(WHERE source='ZERO_COST'),0),4) zero_cost_units_returned,
 count(*) FILTER(WHERE source='ZERO_COST'
   AND (abs(coalesce(line_value,0))>0.000001 OR abs(coalesce(unit_cost,0))>0.000001)) zero_cost_with_monetary_value,
 count(*) FILTER(WHERE source='PURCHASED'
   AND value_gap>0.005+qty*0.00005+0.000001) purchased_values_outside_display_rounding,
 count(*) FILTER(WHERE source='PURCHASED' AND coalesce(unit_cost,0)<=0) purchased_return_lines_without_cost,
 round(coalesce(sum(line_value) FILTER(WHERE source='PURCHASED'),0),2) recorded_purchased_inventory_value_transferred
FROM items;
