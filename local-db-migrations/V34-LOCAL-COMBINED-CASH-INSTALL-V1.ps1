# BIG BROTHER Local Brain V5/V6 - guarded Combined Collection installer.
# Default: READ-ONLY preflight. Pass -Apply explicitly to install.
# Targets ONLY the exact LOCAL Docker PostgreSQL container; never connects to Cloud.
[CmdletBinding()]
param(
 [switch]$Apply,
 [string]$BackupRoot = 'D:\BIG BROTHER Local Backup\Local Brain\brain-backups\combined-cash-local'
)
$ErrorActionPreference='Stop'
$container='supabase_db_Local_Brain'
$db='postgres'
$dir=Split-Path -Parent $MyInvocation.MyCommand.Path
$sqlPath=Join-Path $dir '20261116_combined_collection_LOCAL_ONE_SHOT_V1.sql'
function StopIfFailed([string]$label) {
 if($LASTEXITCODE -ne 0){throw ('LOCAL_INSTALL_BLOCKED: '+$label+' (exit '+$LASTEXITCODE+')')}
}
function Run-LocalPsql([string]$query) {
 $result=& docker exec $container psql -X -A -t -v 'ON_ERROR_STOP=1' -U postgres -d $db -c $query 2>&1
 StopIfFailed 'local psql check'
 return (($result | Out-String).Trim())
}
if(-not (Test-Path -LiteralPath $sqlPath -PathType Leaf)){throw ('LOCAL_INSTALL_BLOCKED: missing approved SQL '+$sqlPath)}
if(-not (Get-Command docker -ErrorAction SilentlyContinue)){throw 'LOCAL_INSTALL_BLOCKED: Docker CLI not found'}
$state=(& docker inspect -f '{{.State.Running}}' $container 2>$null | Out-String).Trim()
StopIfFailed 'Local Brain PostgreSQL container not found'
if($state -ne 'true'){throw ('LOCAL_INSTALL_BLOCKED: '+$container+' is not running')}
$identity=Run-LocalPsql "select current_database()||'|'||current_user||'|'||current_setting('server_version_num')"
if($identity -notmatch '^postgres\|[^|]+\|[0-9]+$'){throw ('LOCAL_INSTALL_BLOCKED: unexpected database identity '+$identity)}
$missing=Run-LocalPsql @"
with required(f) as (
 values
 ('public.bb_is_active_user()'),
 ('public.bb_is_admin()'),
 ('public.bb_has_module_access(text,text)'),
 ('public.bb_dcc_mobile_has_access(text)'),
 ('private.bb_is_current_receivable_owner(text)'),
 ('public.bb_sales_support_your_collection_create_request(jsonb)'),
 ('public.bb_dcc_create_request(jsonb)'),
 ('public.bb_dcc_mobile_create_request(jsonb)'),
 ('public.bb_ar_create_request_v2(jsonb)')
)
select coalesce(string_agg(f,', '),'READY') from required where to_regprocedure(f) is null
"@
if($missing -ne 'READY'){throw ('LOCAL_INSTALL_BLOCKED: missing required Local RPC(s): '+$missing)}
$bytes=(Get-Item -LiteralPath $sqlPath).Length
if($bytes -lt 20000 -or $bytes -gt 100000){throw 'LOCAL_INSTALL_BLOCKED: unexpected migration file size'}
$hash=(Get-FileHash -LiteralPath $sqlPath -Algorithm SHA256).Hash
Write-Host ('LOCAL BRAIN ONLY | Container: '+$container+' | Database: '+$identity) -ForegroundColor Cyan
Write-Host ('Migration: '+[IO.Path]::GetFileName($sqlPath)+' | '+$bytes+' bytes | SHA-256 '+$hash)
Write-Host 'Preflight PASS: required original Daily Cash and A/R RPCs are present.' -ForegroundColor Green
if(-not $Apply){
 Write-Host 'CHECK ONLY: no schema or business data changed. To install, run INSTALL-LOCAL-COMBINED-CASH.cmd.' -ForegroundColor Yellow
 exit 0
}
# Perform a full local DB backup before any schema/RPC change. No Cloud backup or upload.
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$tmp='/tmp/bb-combined-cash-'+$stamp+'.dump'
$backup=Join-Path $BackupRoot ('BB_LOCAL_PRE_COMBINED_CASH_'+$stamp+'.dump')
try {
 & docker exec $container pg_dump -U postgres -d $db -Fc -f $tmp
 StopIfFailed 'full local DB backup'
 & docker cp ($container+':'+$tmp) $backup
 StopIfFailed 'copying local DB backup to Windows'
 if(-not (Test-Path -LiteralPath $backup -PathType Leaf) -or
    (Get-Item -LiteralPath $backup).Length -lt 1024){
   throw 'LOCAL_INSTALL_BLOCKED: complete backup file could not be verified'
 }
 Write-Host ('Local database backup: '+$backup) -ForegroundColor Green
}finally{
 & docker exec $container rm -f $tmp 2>$null | Out-Null
}
# Send UTF-8 SQL to psql in the verified local Docker container only.
$OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$previousEncoding=[Console]::OutputEncoding
try{
 [Console]::OutputEncoding=$OutputEncoding
 $sqlText=[IO.File]::ReadAllText($sqlPath,[Text.Encoding]::UTF8)
 $output=$sqlText | & docker exec -i $container psql -X -v 'ON_ERROR_STOP=1' -U postgres -d $db 2>&1
 $exit=$LASTEXITCODE
 if($exit -ne 0){throw ('LOCAL_INSTALL_BLOCKED: migration failed/rolled back: '+($output | Out-String))}
}finally{[Console]::OutputEncoding=$previousEncoding}
$verified=Run-LocalPsql "select CASE WHEN to_regprocedure('public.bb_dcc_combined_cash_request_v1(jsonb)') IS NOT NULL and to_regprocedure('public.bb_sales_support_combined_cash_request_v1(jsonb)') IS NOT NULL and to_regprocedure('public.bb_sales_support_ar_cash_candidates_v1()') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END"
if($verified -ne 'PASS'){throw 'LOCAL_INSTALL_BLOCKED: post-install RPC verification failed'}
Write-Host 'LOCAL BRAIN COMBINED COLLECTION INSTALLED (RPC/SHEMA ONLY).' -ForegroundColor Green
Write-Host 'No cash close, A/R request, payment or vault entry was created by this installation.' -ForegroundColor Cyan
Write-Host 'Use Code Sync for UI files; test inside V5/V6 and verify API requests remain LOCAL.' -ForegroundColor Cyan
