# BIG BROTHER Local Brain - read-only damage exchange migration check
# Scoped to migration 20261103_b_damage_exchange_cost_cogs_v1; no data writes.
[CmdletBinding()]
param(
  [string]$Container='supabase_db_Local_Brain',
  [string]$Database='postgres',
  [string]$DbUser='postgres'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$report=Join-Path $PSScriptRoot ('LOCAL-DAMAGE-EXCHANGE-CHECK-'+$stamp+'.txt')
$lines=@(
  'BIG BROTHER LOCAL DAMAGE EXCHANGE MIGRATION CHECK V1',
  ('TIME: '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
  'PURPOSE: diagnose 20261103_b_damage_exchange_cost_cogs_v1 failure',
  'MODE: READ ONLY TRANSACTION / NO MIGRATION EXECUTION',
  ('EXPECTED CONTAINER: '+$Container),
  ('DATABASE: '+$Database)
)
try {
  if(-not (Get-Command docker -ErrorAction SilentlyContinue)){
    throw 'Docker is not available. Start Local Brain / Docker first.'
  }
  $running=@(& docker ps --format '{{.Names}}' 2>&1)
  if($LASTEXITCODE -ne 0){throw ('docker ps failed: '+($running -join ', '))}
  if($running -notcontains $Container){
    throw ('Local Brain database container not running: '+$Container+'. Running: '+($running -join ', '))
  }
  $sql=@'
\\pset pager off
BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout='45s';
SELECT '01 - REQUIRED TABLES' AS diagnostic;
SELECT
  to_regclass('public.stock_damage_exchange_items') IS NOT NULL AS exchange_items,
  to_regclass('public.stock_damage_clear_allocations') IS NOT NULL AS clear_allocations,
  to_regclass('public.stock_activity') IS NOT NULL AS stock_activity,
  to_regclass('public.system_activity_log') IS NOT NULL AS audit_log,
  to_regprocedure('public.bb_stock_receive_damage_exchange(jsonb)') IS NOT NULL AS exchange_receive_rpc;
SELECT '02 - FUTURE RECEIVER CODE ANCHORS' AS diagnostic;
SELECT
  p.proname AS routine,
  length(pg_get_functiondef(p.oid)) AS code_size,
  position('BB_DAMAGE_EXCHANGE_DOCUMENTED_COST_20261103' IN pg_get_functiondef(p.oid))>0 AS documented_cost_guard_installed,
  position('BB_DAMAGE_EXCHANGE_HEADER_VALUE_20261103' IN pg_get_functiondef(p.oid))>0 AS header_cost_guard_installed,
  (length(pg_get_functiondef(p.oid))-length(replace(pg_get_functiondef(p.oid),'      received_qty =',''))) / length('      received_qty =') AS literal_header_anchor_count,
  position('    v_received_unit_cost :=' IN pg_get_functiondef(p.oid))>0 AS original_cost_anchor,
  position('    v_line_value :=' IN pg_get_functiondef(p.oid))>0 AS original_line_value_anchor
FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
WHERE ns.nspname='public' AND p.proname='bb_stock_receive_damage_exchange';
SELECT '03 - HISTORICAL EXCHANGE ITEM HEADERS (ID 14 AND 16 ONLY)' AS diagnostic;
SELECT exchange_item_id, product_code, status, exchange_qty, received_qty,
       unit_cost, exchange_value, clearance_transaction_id
FROM public.stock_damage_exchange_items WHERE exchange_item_id IN (14,16)
ORDER BY exchange_item_id;
SELECT '04 - HISTORICAL EXCHANGE ALLOCATIONS' AS diagnostic;
SELECT x.exchange_item_id,x.product_code,x.exchange_qty,x.received_qty,x.unit_cost,
       count(a.allocation_id) AS allocation_rows,
       coalesce(sum(a.allocated_qty),0) AS allocated_qty,
       round(coalesce(sum(a.allocated_qty*d.unit_cost),0),2) AS documented_value,
       round(coalesce(sum(a.allocated_qty*d.unit_cost),0)/nullif(sum(a.allocated_qty),0),6) AS documented_unit_cost
FROM public.stock_damage_exchange_items x
LEFT JOIN public.stock_damage_clear_allocations a ON a.clear_transaction_id=x.clearance_transaction_id
LEFT JOIN public.stock_activity d ON d.transaction_id=a.damage_transaction_id
WHERE x.exchange_item_id IN (14,16)
GROUP BY x.exchange_item_id,x.product_code,x.exchange_qty,x.received_qty,x.unit_cost
ORDER BY x.exchange_item_id;
SELECT '05 - MIGRATION EXPECTED STOCK MOVEMENTS' AS diagnostic;
WITH expected(id) AS (SELECT unnest(ARRAY[
 'TRX-007126','TRX-007128','TRX-007134','TRX-007136',
 'TRX-007166','TRX-007186','TRX-007188','TRX-007206','TRX-007208',
 'TRX-007266','TRX-007388','TRX-007394','TRX-007396','TRX-007400',
 'TRX-007762','TRX-007766','TRX-007768','TRX-007780']))
SELECT e.id AS transaction_id,
       coalesce(a.product_code,'NOT IN LOCAL') AS product_code,
       a.movement_type,a.qty,a.unit_cost,a.line_value,
       a.from_bucket,a.to_bucket
FROM expected e LEFT JOIN public.stock_activity a ON a.transaction_id=e.id
ORDER BY e.id;
SELECT '06 - COST REPAIR SPECIFIC COUNTS' AS diagnostic;
SELECT
 (SELECT count(*) FROM public.stock_damage_exchange_items WHERE exchange_item_id IN (14,16)) AS found_exchange_ids,
 (SELECT count(*) FROM public.stock_damage_exchange_items WHERE exchange_item_id IN (14,16) AND coalesce(unit_cost,0)=0) AS zero_cost_exchanges,
 (SELECT count(*) FROM public.stock_damage_exchange_items
    WHERE (exchange_item_id=14 AND product_code='CHM-220' AND received_qty=259 AND unit_cost=0.45 AND exchange_value=116.55)
       OR (exchange_item_id=16 AND product_code='CH-O220' AND received_qty=46 AND unit_cost=0.45 AND exchange_value=20.70)) AS corrected_headers,
 (SELECT coalesce(sum(line_value),0) FROM public.stock_activity
    WHERE transaction_id IN ('TRX-007388','TRX-007394','TRX-007396') AND movement_type='BATCH_SALE') AS selected_cogs,
 (SELECT count(*) FROM public.stock_activity a
    WHERE a.product_code IN ('CHM-220','CH-O220')
    AND a.created_at>='2026-10-31 06:55:00+00'::timestamptz
    AND a.unit_cost<=0
    AND (a.from_bucket IN ('WAREHOUSE_GOOD','BATCH_PENDING')
      OR a.to_bucket IN ('WAREHOUSE_GOOD','BATCH_PENDING'))) AS later_zero_cost_purchased_movements;
SELECT '07 - PURCHASED AVERAGE COSTS' AS diagnostic;
SELECT product_code,average_cost,warehouse_good,batch_pending
FROM public.bb_stock_product_rows_zero_cost_v1_internal()
WHERE product_code IN ('CHM-220','CH-O220')
ORDER BY product_code;
SELECT '08 - EXISTING COST CORRECTION AUDIT' AS diagnostic;
SELECT action,metadata->>'migrationId' AS migration_id,count(*) AS rows
FROM public.system_activity_log
WHERE action='DAMAGE_EXCHANGE_COST_CORRECTION_20261103'
GROUP BY action,metadata->>'migrationId';
ROLLBACK;
'@
  $output=@($sql | & docker exec -i $Container psql -X -U $DbUser -d $Database -v ON_ERROR_STOP=1 -P pager=off -P null='(NULL)' 2>&1)
  $exit=$LASTEXITCODE
  $lines+=('PSQL EXIT CODE: '+$exit)
  $lines+='FULL READ-ONLY QUERY OUTPUT:'
  $lines+=$output
  $lines | Out-File -LiteralPath $report -Width 400 -Encoding utf8
  if($exit -ne 0){
    Write-Host ('Read-only check stopped; report with full error: '+$report) -ForegroundColor Yellow
    exit 1
  }
  Write-Host ('Local read-only diagnostic complete: '+$report) -ForegroundColor Green
  Write-Host 'Send the report. No stock, invoices, costs or migrations were modified.'
}catch{
  $lines+=('DIAGNOSTIC ERROR: '+$_.Exception.Message)
  $lines | Out-File -LiteralPath $report -Width 400 -Encoding utf8
  Write-Host ('Diagnostic stopped: '+$_.Exception.Message) -ForegroundColor Red
  Write-Host ('Report: '+$report)
  exit 1
}
