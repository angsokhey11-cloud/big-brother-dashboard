# BIG BROTHER - Read-only Local Stock Trigger Gate Diagnostic V1
# This script never runs migration files and never updates any database records.
[CmdletBinding()]
param(
    [string]$Container = '',
    [string]$Database = 'postgres',
    [string]$DbUser = 'postgres'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = Join-Path $PSScriptRoot ("LOCAL-STOCK-TRIGGER-CHECK-" + $stamp + ".txt")
$header = @(
    'BIG BROTHER - LOCAL STOCK TRIGGER READ-ONLY CHECK',
    ('TIME: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')),
    'MODE: READ-ONLY (no schema changes, no business data changes)',
    'AIM: diagnose 20261103_a_direct_sale_warehouse_source_v1 gate'
)
try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker command is unavailable. Start Docker Desktop on the Local Brain PC.'
    }
    $running = @(& docker ps --format '{{.Names}}' 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ('docker ps failed: ' + ($running -join '; ')) }
    if (-not $Container) {
        $preferred = @($running | Where-Object { $_ -eq 'supabase_db_Local_Brain' })
        if ($preferred.Count -eq 1) {
            $Container = $preferred[0]
        } else {
            $candidates = @($running | Where-Object { $_ -match '(?i)(supabase.*db|postgres|local.*db|db.*local)' })
            if ($candidates.Count -ne 1) {
                throw ('Cannot determine single Local Brain PostgreSQL container. Running containers: ' + ($running -join ', ') + '. Specify -Container NAME after checking the correct database.')
            }
            $Container = $candidates[0]
        }
    }
    if ($running -notcontains $Container) {
        throw ("Selected local container is not running: " + $Container)
    }
    $header += ('DOCKER CONTAINER: ' + $Container)
    $header += ('DATABASE: ' + $Database)
    $sql = @'
\pset pager off
SELECT CASE WHEN to_regclass('public.stock_batches') IS NOT NULL
     AND to_regclass('public.invoices') IS NOT NULL
     AND to_regclass('public.invoice_lines') IS NOT NULL
     AND to_regclass('public.stock_activity') IS NOT NULL
     THEN 'LOCAL_BIG_BROTHER_TABLES_PRESENT' ELSE 'REQUIRED_LOCAL_TABLES_MISSING' END AS local_database_check;
SELECT
    p.proname AS stock_function,
    md5(pg_get_functiondef(p.oid)) AS function_md5,
    pg_get_functiondef(p.oid) ~* 'v_invoice[.]batch_id[[:space:]]+is[[:space:]]+null[[:space:]]+and[[:space:]]+coalesce' AS expected_double_deduction_skip_present,
    pg_get_functiondef(p.oid) ~* 'new[.]stock_allocation_json' AS source_field_referenced,
    position('-- BATCH SALE' IN pg_get_functiondef(p.oid)) AS batch_sale_comment_pos,
    position('-- DIRECT SALE' IN pg_get_functiondef(p.oid)) AS direct_sale_comment_pos
FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
WHERE ns.nspname='public' AND p.proname='bb_stock_invoice_line_after_insert';
SELECT
  tgname AS trigger_name, tgenabled AS trigger_enabled, pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace ns ON ns.oid=c.relnamespace
WHERE ns.nspname='public' AND c.relname='invoice_lines'
  AND NOT t.tgisinternal
  AND t.tgname IN ('trg_invoice_lines_stock_direct_sale','trg_invoice_lines_stock_direct_sale_source_v1')
ORDER BY tgname;
SELECT
  p.proname AS function_name,
  pg_get_functiondef(p.oid) ~* 'v_invoice[.]batch_id[[:space:]]+is[[:space:]]+not[[:space:]]+null[[:space:]]+then[[:space:]]+return[[:space:]]+new' AS expected_batch_invoice_skip_present,
  position('  v_location_name text;' IN pg_get_functiondef(p.oid)) > 0 AS expected_declaration_present
FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
WHERE ns.nspname='public' AND p.proname IN
  ('bb_stock_invoice_line_source_aware_after_insert','bb_invoice_reversal_direct_stock_v2_internal');
SELECT
  'MAIN_TRIGGER_1200_CHAR_EXCERPT_AROUND_BATCH_SALE' AS section,
  substring(
      pg_get_functiondef(p.oid)
      FROM greatest(1,position('-- BATCH SALE' IN pg_get_functiondef(p.oid)) - 720)
      FOR 1700
  ) AS definition_excerpt
FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
WHERE ns.nspname='public' AND p.proname='bb_stock_invoice_line_after_insert';
'@
    $result = @($sql | & docker exec -i $Container psql -X -U $DbUser -d $Database -v ON_ERROR_STOP=1 -P pager=off 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ('Local read-only SQL query failed: ' + ($result -join [Environment]::NewLine))
    }
    $header += 'STATUS: READ-ONLY CHECK COMPLETED'
    $header += 'RESULTS:'
    $reportLines = $header + $result
    $reportLines | Out-File -LiteralPath $report -Encoding utf8 -Width 300
    Write-Host ('Read-only report created: ' + $report) -ForegroundColor Green
    Write-Host 'Share this report to diagnose the exact Local function difference.'
}
catch {
    $header += 'STATUS: READ-ONLY CHECK BLOCKED'
    $header += ('ERROR: ' + $_.Exception.Message)
    $header | Out-File -LiteralPath $report -Encoding utf8 -Width 300
    Write-Host ('Read-only diagnostic stopped: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Report: ' + $report)
    exit 1
}
