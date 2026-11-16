# BIG BROTHER — LOCAL ONLY A/R Customer Location route correction 16-Nov-2026.
# Check-only by default; -Apply runs a verified LOCAL PostgreSQL backup first.
# No Cloud/Local refresh, Cloud API, or Local -> Cloud upload.
[CmdletBinding()]
param(
 [switch]$Apply,
 [string]$BackupRoot='D:\BIG BROTHER Local Backup\Local Brain\brain-backups\ar-customer-route'
)
$ErrorActionPreference='Stop'
$container='supabase_db_Local_Brain'
$database='postgres'
$sql=Join-Path $PSScriptRoot '20261116_ar_customer_route_LOCAL_ONE_SHOT_V1.sql'

function Check-Exit([string]$name) {
 if($LASTEXITCODE -ne 0) {
  throw ('LOCAL_AR_CUSTOMER_ROUTE_STOP: '+$name+' failed, exit '+$LASTEXITCODE)
 }
}
function Local-Query([string]$statement) {
 $out = & docker exec $container psql -X -A -t -v 'ON_ERROR_STOP=1' -U postgres -d $database -c $statement 2>&1
 Check-Exit 'local PostgreSQL query'
 return (($out | Out-String).Trim())
}

if(-not(Test-Path -LiteralPath $sql -PathType Leaf)){throw 'LOCAL_AR_CUSTOMER_ROUTE_STOP: SQL migration file missing'}
if(-not(Get-Command docker -ErrorAction SilentlyContinue)){throw 'LOCAL_AR_CUSTOMER_ROUTE_STOP: Docker not available'}
$state=(& docker inspect -f '{{.State.Running}}' $container 2>$null | Out-String).Trim()
Check-Exit 'Local Brain Docker inspect'
if($state -ne 'true'){throw 'LOCAL_AR_CUSTOMER_ROUTE_STOP: expected Local Brain PostgreSQL container not running'}
$dbName=Local-Query 'select current_database()'
if($dbName -ne 'postgres'){throw ('LOCAL_AR_CUSTOMER_ROUTE_STOP: unexpected local DB '+$dbName)}

$required=@(
 'public.bb_ar_list()',
 'public.bb_ar_list_all()',
 'public.bb_ar_create_request(jsonb)',
 'public.bb_ar_create_request_v2(jsonb)',
 'public.bb_ar_detail(text)',
 'public.bb_ar_detail_by_id(text)',
 'public.bb_ar_bank_assistant_list_v1()',
 'public.bb_ar_bank_assistant_submit_v1(jsonb)',
 'public.bb_sales_support_ar_cash_candidates_v1()',
 'public.bb_dcc_combined_cash_request_v1(jsonb)',
 'public.bb_sales_support_combined_cash_request_v1(jsonb)',
 'private.bb_set_invoice_receivable_owner()'
)
$expression=($required | ForEach-Object { "'" + $_.Replace("'","''") + "'" }) -join ','
$missing=Local-Query ("select coalesce(string_agg(r,', '),'NONE') from unnest(array["+ $expression +"]) r where to_regprocedure(r) is null")
if($missing -ne 'NONE'){throw ('LOCAL_AR_CUSTOMER_ROUTE_STOP: missing required local RPC(s): '+$missing)}

$tables=@('public.customers','public.invoices','public.locations','public.app_users','public.ar_payment_requests','public.ar_request_allocations','public.daily_cash_closes','public.bb_salesman_combined_cash_submissions','public.bb_verified_bank_transactions','public.bb_bank_balance_snapshot')
$expression=($tables | ForEach-Object { "'" + $_.Replace("'","''") + "'" }) -join ','
$missing=Local-Query ("select coalesce(string_agg(t,', '),'NONE') from unnest(array["+ $expression +"]) t where to_regclass(t) is null")
if($missing -ne 'NONE'){throw ('LOCAL_AR_CUSTOMER_ROUTE_STOP: missing local A/R-related table(s): '+$missing)}
$hash=(Get-FileHash -LiteralPath $sql -Algorithm SHA256).Hash.ToUpperInvariant()
Write-Host 'LOCAL BRAIN V5/V6 | A/R Customer Location route correction' -ForegroundColor Cyan
Write-Host ('Local PostgreSQL: '+$container+' / '+$database)
Write-Host ('SQL checksum: '+$hash)
Write-Host 'Preflight PASS: all 12 existing route RPCs and required tables exist.' -ForegroundColor Green
if(-not $Apply){
 Write-Host 'CHECK ONLY: No SQL installed; no data changed.' -ForegroundColor Yellow
 Write-Host 'To install: run INSTALL-LOCAL-AR-CUSTOMER-ROUTE.cmd and type APPLY.'
 exit 0
}
# Full backup before deploying any privileged database function.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$dump="/tmp/bb-ar-customer-route-before-"+$stamp+".dump"
$backup=Join-Path $BackupRoot ('BB_LOCAL_PRE_AR_CUSTOMER_ROUTE_'+$stamp+'.dump')
try {
 & docker exec $container pg_dump -U postgres -d $database -Fc -f $dump
 Check-Exit 'local database pg_dump backup'
 & docker cp ($container+':'+$dump) $backup
 Check-Exit 'copying local database backup'
 if(-not (Test-Path -LiteralPath $backup -PathType Leaf)){
  throw 'LOCAL_AR_CUSTOMER_ROUTE_STOP: backup missing after docker copy'
 }
 if((Get-Item -LiteralPath $backup).Length -lt 1024){
  throw 'LOCAL_AR_CUSTOMER_ROUTE_STOP: backup unexpectedly small'
 }
 Write-Host ('Full Local DB backup verified: '+$backup) -ForegroundColor Green
}finally{
 & docker exec $container rm -f $dump 2>$null | Out-Null
}
$tmpSql='/tmp/bb-local-ar-customer-route-'+$stamp+'.sql'
try {
 & docker cp $sql ($container+':'+$tmpSql)
 Check-Exit 'copying SQL into LOCAL Docker container'
 & docker exec $container psql -X -v 'ON_ERROR_STOP=1' -U postgres -d $database -f $tmpSql
 Check-Exit 'applying guarded A/R Customer Location migration'
}finally{
 & docker exec $container rm -f $tmpSql 2>$null | Out-Null
}
$verified=Local-Query "select case when position('c.location_code' in pg_get_functiondef('public.bb_sales_support_ar_cash_candidates_v1()'::regprocedure))>0 and position('c.location_code' in pg_get_functiondef('public.bb_ar_list()'::regprocedure))>0 then 'PASS' else 'FAIL' end"
if($verified -ne 'PASS'){throw 'LOCAL_AR_CUSTOMER_ROUTE_STOP: post-install function validation failed'}
Write-Host 'SUCCESS: A/R now uses Customer assigned Location for collection responsibility.' -ForegroundColor Green
Write-Host 'PostgREST schema-cache reload sent. Refresh Local Your Collection, Daily Cash and A/R.' -ForegroundColor Cyan
Write-Host 'No invoices, customer locations, stock, payments, receivables or cash balances were edited by this migration.' -ForegroundColor Cyan
