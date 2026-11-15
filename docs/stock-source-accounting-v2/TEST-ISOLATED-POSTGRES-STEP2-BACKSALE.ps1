# BIG BROTHER — Stock Source Accounting V2 isolated PostgreSQL compile/smoke test
# STAGING ONLY. Runs against a separate throwaway Docker container; no Cloud or V5/V6 connection.
# Requires an existing local PostgreSQL custom-format .dump/.backup exported separately.
# The isolated Supabase image requires its supabase_admin superuser for restore/function compilation.
# This runner ONLY verifies SQL compilation and read-only audits; it does NOT run real sale/reversal fixtures.
# Does not create or merge any Supabase branch.
# Usage:
# .\TEST-ISOLATED-POSTGRES.ps1 -BackupFile 'C:\Path\LocalBrainV6.backup' -StagedDir 'C:\Path\stock-source-accounting-v2'
# StagedDir must contain the 3 STAGED.sql + 3 READONLY.sql files (see README).
param(
  [Parameter(Mandatory=$true)][string]$BackupFile,
  [Parameter(Mandatory=$true)][string]$StagedDir,
  [string]$Image='public.ecr.aws/supabase/postgres:17.6.1.166',
  [string]$ContainerName='bb-stock-source-v2-step2-backsale-isolated-test'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Check-LastExit([string]$Step) {
  if($LASTEXITCODE -ne 0) { throw "$Step failed (exit code $LASTEXITCODE). Test is NOT approved." }
}
# Windows PowerShell 5.1 can promote Docker's transient stderr to a
# NativeCommandError when ErrorActionPreference=Stop. Only startup probes use
# Continue. Every probe returns an explicit Docker exit code and SQL output.
function Probe-SandboxSql([string]$Sql, [string]$Role='postgres') {
  $oldPreference=$ErrorActionPreference
  try {
    $ErrorActionPreference='Continue'
    $lines=@(docker exec $ContainerName psql -X -v ON_ERROR_STOP=1 -U $Role -d postgres -tAc $Sql 2>$null)
    $exitCode=$LASTEXITCODE
  } finally {
    $ErrorActionPreference=$oldPreference
  }
  return @{ Ok=($exitCode -eq 0); Value=(($lines -join '')).Trim() }
}
function Wait-StableSandbox([string]$Phase) {
  # pg_isready can pass while Supabase's temporary initdb server is running,
  # immediately before it shuts down. Require two SQL connections, four
  # seconds apart, to the SAME postmaster. Only inspect this isolated container.
  for($attempt=1;$attempt -le 30;$attempt++){
    $first=Probe-SandboxSql 'SELECT pg_postmaster_start_time()::text;'
    if($first.Ok -and $first.Value -ne ''){
      Start-Sleep -Seconds 4
      $second=Probe-SandboxSql 'SELECT pg_postmaster_start_time()::text;'
      if($second.Ok -and $first.Value -eq $second.Value){
        Write-Host "Isolated PostgreSQL stable at $Phase (same postmaster)." -ForegroundColor Green
        return
      }
    } else {
      Start-Sleep -Seconds 3
    }
  }
  docker logs --tail 30 $ContainerName
  throw "Isolated PostgreSQL did not stabilize during $Phase; stop."
}
function RunSql([string]$FileName) {
  $file=Join-Path $StagedDir $FileName
  if(-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing staged SQL: $file" }
  Write-Host "Checking in isolated database: $FileName" -ForegroundColor Cyan
  docker cp "$file" "$($ContainerName):/tmp/$FileName" | Out-Null
  Check-LastExit 'Docker copy'
  docker exec $ContainerName psql -X -v ON_ERROR_STOP=1 -U supabase_admin -d bb_stock_v2_sandbox -f "/tmp/$FileName"
  Check-LastExit "SQL $FileName"
}
$files=@(
  '20261031_source_aware_batch_sale_and_back_sale_STAGED.sql',
  '20261031_exact_batch_reversal_sources_STAGED.sql',
  '20261031_reversal_source_snapshot_STAGED.sql',
  'SOURCE-ARITHMETIC-SMOKE-READONLY.sql',
  'WAREHOUSE-BATCH-VALUATION-RECONCILIATION-READONLY.sql',
  'BACK-SALE-SOURCE-LEDGER-AUDIT-READONLY.sql',
  'ACTUAL-BATCH-INVOICE-SOURCE-ROLLBACK-ISOLATED.sql',
  'ACTUAL-BACK-SALE-SOURCE-ROLLBACK-ISOLATED.sql'
)
if(-not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) {
  throw "Backup file not found: $BackupFile. Do not connect this script to the live Local Brain database."
}
if([IO.Path]::GetExtension($BackupFile).ToLowerInvariant() -notin @('.dump','.backup')) {
  throw "Only PostgreSQL custom-format .dump/.backup files are accepted; no live database credentials."
}
foreach($f in $files) {
  if(-not (Test-Path -LiteralPath (Join-Path $StagedDir $f) -PathType Leaf)) { throw "Missing test file: $f" }
}
if(-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop is required.' }
docker image inspect $Image *> $null
if($LASTEXITCODE -ne 0) { throw "Docker image $Image not found locally; inspect/approve it before running the test." }
$existing=docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
if($existing) { throw "Container $ContainerName already exists: refusing to reuse or delete it." }
$started=$false
try {
  Write-Host 'Launching isolated NO-NETWORK PostgreSQL container; no ports published.' -ForegroundColor Cyan
  $password=[Guid]::NewGuid().ToString('N')
  docker run -d --name $ContainerName --network none -e "POSTGRES_PASSWORD=$password" $Image | Out-Null
  Check-LastExit 'Start isolated container'
  $started=$true
  Wait-StableSandbox 'first boot'
  # Supabase postgres is not a superuser. Inspect role on isolated instance.
  $admin=Probe-SandboxSql "SELECT rolsuper AND rolcanlogin FROM pg_roles WHERE rolname='supabase_admin';"
  if(-not $admin.Ok -or $admin.Value -ne 't') { throw 'Isolated supabase_admin superuser missing; stop.' }

  # Modify cron settings ONLY inside this new --network none throwaway container.
  # Do not let transient psql stderr terminate the Windows PowerShell host.
  $cronDb=Probe-SandboxSql "ALTER SYSTEM SET cron.database_name = 'bb_stock_v2_sandbox';" 'supabase_admin'
  if(-not $cronDb.Ok){ throw 'Sandbox-only cron.database_name setting failed; stop.' }
  $cronOff=Probe-SandboxSql "ALTER SYSTEM SET cron.launch_active_jobs = off;" 'supabase_admin'
  if(-not $cronOff.Ok){ throw 'Sandbox-only cron.launch_active_jobs setting failed; stop.' }

  docker restart $ContainerName | Out-Null
  Check-LastExit 'Restart isolated container with cron jobs disabled'
  Wait-StableSandbox 'post-cron restart'
  $cronDatabase=Probe-SandboxSql 'SHOW cron.database_name;'
  $cronActive=Probe-SandboxSql 'SHOW cron.launch_active_jobs;'
  if(-not $cronDatabase.Ok -or $cronDatabase.Value -ne 'bb_stock_v2_sandbox' -or
     -not $cronActive.Ok -or $cronActive.Value -ne 'off') {
    throw 'Sandbox pg_cron settings could not be verified after restart; stop.'
  }
  Write-Host 'Verified cron runs against sandbox database only, scheduled jobs OFF.' -ForegroundColor Green
  Write-Host 'Restoring backup COPY into isolated container (source remains unchanged).' -ForegroundColor Cyan
  docker cp "$BackupFile" "$($ContainerName):/tmp/local-source.backup" | Out-Null
  Check-LastExit 'Copy PostgreSQL dump'
  docker exec $ContainerName createdb -U postgres bb_stock_v2_sandbox
  Check-LastExit 'Create sandbox-only database'
  docker exec $ContainerName pg_restore --exit-on-error --no-owner --no-acl -U supabase_admin -d bb_stock_v2_sandbox /tmp/local-source.backup
  Check-LastExit 'Restore isolated database'
  # All writes below are inside the throwaway no-network Docker database.
  # The source dump is historical, so its pre-correction stock totals may differ.
  $restoredCount=(docker exec $ContainerName psql -X -v ON_ERROR_STOP=1 -U supabase_admin -d bb_stock_v2_sandbox -tAc 'SELECT count(*) FROM public.stock_activity;').Trim()
  Check-LastExit 'Count isolated restored stock ledger'
  Write-Host "Isolated restored stock movements: $restoredCount (historical backup baseline)" -ForegroundColor DarkCyan
  foreach($f in $files){ RunSql $f }
  Write-Host 'COMPILE + AUDITS + ACTUAL BATCH INVOICE AND BACK SALE ROLLBACK TESTS COMPLETE.' -ForegroundColor Green
  Write-Host 'NOTE: real Back Sale fixture runs here; Invoice Reversal, authenticated UI, and Local sync remain UNTESTED.' -ForegroundColor Yellow
} finally {
  if($started){
    Write-Host 'Removing ONLY the throwaway test container.' -ForegroundColor Cyan
    docker rm -f $ContainerName | Out-Null
  }
}
