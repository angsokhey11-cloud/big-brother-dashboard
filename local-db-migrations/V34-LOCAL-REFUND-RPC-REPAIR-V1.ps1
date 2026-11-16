# BIG BROTHER — LOCAL ONLY Salesman Refund RPC repair 16-Nov-2026.
# Check-only by default; -Apply runs a verified LOCAL PostgreSQL backup first.
# No Cloud/Local refresh, Cloud API, or Local -> Cloud upload.
[CmdletBinding()]
param(
 [switch]$Apply,
 [string]$BackupRoot='D:\BIG BROTHER Local Backup\Local Brain\brain-backups\refund-rpc-repair'
)
$ErrorActionPreference='Stop'
$container='supabase_db_Local_Brain'
$database='postgres'
$sql=Join-Path $PSScriptRoot '20261116_local_refund_rpc_parity_v1.sql'

function Check-Exit([string]$name) {
 if($LASTEXITCODE -ne 0) {
  throw ('LOCAL_REFUND_REPAIR_STOP: '+$name+' failed, exit '+$LASTEXITCODE)
 }
}
function Local-Query([string]$statement) {
 $out = & docker exec $container psql -X -A -t -v 'ON_ERROR_STOP=1' -U postgres -d $database -c $statement 2>&1
 Check-Exit 'local PostgreSQL query'
 return (($out | Out-String).Trim())
}

if(-not(Test-Path -LiteralPath $sql -PathType Leaf)){throw 'LOCAL_REFUND_REPAIR_STOP: SQL migration file missing'}
if(-not(Get-Command docker -ErrorAction SilentlyContinue)){throw 'LOCAL_REFUND_REPAIR_STOP: Docker not available'}
$state=(& docker inspect -f '{{.State.Running}}' $container 2>$null | Out-String).Trim()
Check-Exit 'Local Brain Docker inspect'
if($state -ne 'true'){throw 'LOCAL_REFUND_REPAIR_STOP: expected Local Brain PostgreSQL container not running'}
$dbName=Local-Query 'select current_database()'
if($dbName -ne 'postgres'){throw ('LOCAL_REFUND_REPAIR_STOP: unexpected local DB '+$dbName)}

$required=@(
 'public.bb_is_admin()',
 'public.bb_is_active_user()',
 'private.bb_is_current_permanent_salesman(text)'
)
$expression=($required | ForEach-Object { "'" + $_.Replace("'","''") + "'" }) -join ','
$missing=Local-Query ("select coalesce(string_agg(r,', '),'NONE') from unnest(array["+ $expression +"]) r where to_regprocedure(r) is null")
if($missing -ne 'NONE'){throw ('LOCAL_REFUND_REPAIR_STOP: missing required local RPC(s): '+$missing)}

$tables=@('public.app_users','public.invoices','public.daily_cash_closes','public.bb_salesman_refund_deductions')
$expression=($tables | ForEach-Object { "'" + $_.Replace("'","''") + "'" }) -join ','
$missing=Local-Query ("select coalesce(string_agg(t,', '),'NONE') from unnest(array["+ $expression +"]) t where to_regclass(t) is null")
if($missing -ne 'NONE'){throw ('LOCAL_REFUND_REPAIR_STOP: missing local refund table(s): '+$missing)}
$hash=(Get-FileHash -LiteralPath $sql -Algorithm SHA256).Hash.ToUpperInvariant()
Write-Host 'LOCAL BRAIN V5/V6 | Salesman Refund RPC repair' -ForegroundColor Cyan
Write-Host ('Local PostgreSQL: '+$container+' / '+$database)
Write-Host ('SQL checksum: '+$hash)
Write-Host 'Preflight PASS: relevant tables and authorization functions exist.' -ForegroundColor Green
if(-not $Apply){
 Write-Host 'CHECK ONLY: No SQL installed; no data changed.' -ForegroundColor Yellow
 Write-Host 'To install: run INSTALL-LOCAL-REFUND-RPCS.cmd and type APPLY.'
 exit 0
}
# Full backup before deploying any privileged database function.
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$dump="/tmp/bb-refund-rpc-before-"+$stamp+".dump"
$backup=Join-Path $BackupRoot ('BB_LOCAL_PRE_REFUND_RPC_'+$stamp+'.dump')
try {
 & docker exec $container pg_dump -U postgres -d $database -Fc -f $dump
 Check-Exit 'local database pg_dump backup'
 & docker cp ($container+':'+$dump) $backup
 Check-Exit 'copying local database backup'
 if(-not (Test-Path -LiteralPath $backup -PathType Leaf)){
  throw 'LOCAL_REFUND_REPAIR_STOP: backup missing after docker copy'
 }
 if((Get-Item -LiteralPath $backup).Length -lt 1024){
  throw 'LOCAL_REFUND_REPAIR_STOP: backup unexpectedly small'
 }
 Write-Host ('Full Local DB backup verified: '+$backup) -ForegroundColor Green
}finally{
 & docker exec $container rm -f $dump 2>$null | Out-Null
}
$tmpSql='/tmp/bb-local-refund-rpc-'+$stamp+'.sql'
try {
 & docker cp $sql ($container+':'+$tmpSql)
 Check-Exit 'copying SQL into LOCAL Docker container'
 & docker exec $container psql -X -v 'ON_ERROR_STOP=1' -U postgres -d $database -f $tmpSql
 Check-Exit 'applying guarded refund RPC migration'
}finally{
 & docker exec $container rm -f $tmpSql 2>$null | Out-Null
}
$verified=Local-Query "select case when to_regprocedure('public.bb_admin_salesman_refund_overview_v1()') is not null and to_regprocedure('public.bb_salesman_refund_available_v1()') is not null then 'PASS' else 'FAIL' end"
if($verified -ne 'PASS'){throw 'LOCAL_REFUND_REPAIR_STOP: post-install function validation failed'}
Write-Host 'SUCCESS: Local refund Admin Overview and salesman availability RPCs installed.' -ForegroundColor Green
Write-Host 'PostgREST schema-cache reload sent. Refresh Local Daily Cash Collection after reload.' -ForegroundColor Cyan
Write-Host 'No refund rows, invoices, payments, Daily Cash closes or vault balances were changed by this migration.' -ForegroundColor Cyan
