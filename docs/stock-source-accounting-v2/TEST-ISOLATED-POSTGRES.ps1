# BIG BROTHER — Stock Source Accounting V2 isolated PostgreSQL compile/smoke test
# STAGING ONLY. Runs against a separate throwaway Docker container; no Cloud or V5/V6 connection.
# Requires an existing local PostgreSQL custom-format .dump/.backup exported separately.
# Does not create or merge any Supabase branch.
# Usage:
# .\TEST-ISOLATED-POSTGRES.ps1 -BackupFile 'C:\Path\LocalBrainV6.backup' -StagedDir 'C:\Path\stock-source-accounting-v2'
# StagedDir must contain the 3 STAGED.sql + 3 READONLY.sql files (see README).
param(
  [Parameter(Mandatory=$true)][string]$BackupFile,
  [Parameter(Mandatory=$true)][string]$StagedDir,
  [string]$Image='public.ecr.aws/supabase/postgres:17.6.1.166',
  [string]$ContainerName='bb-stock-source-v2-isolated-test'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Check-LastExit([string]$Step) {
  if($LASTEXITCODE -ne 0) { throw "$Step failed (exit code $LASTEXITCODE). Test is NOT approved." }
}
function RunSql([string]$FileName) {
  $file=Join-Path $StagedDir $FileName
  if(-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing staged SQL: $file" }
  Write-Host "Checking in isolated database: $FileName" -ForegroundColor Cyan
  docker cp "$file" "$($ContainerName):/tmp/$FileName" | Out-Null
  Check-LastExit 'Docker copy'
  docker exec $ContainerName psql -X -v ON_ERROR_STOP=1 -U postgres -d bb_stock_v2_sandbox -f "/tmp/$FileName"
  Check-LastExit "SQL $FileName"
}
$files=@(
  '20261031_source_aware_batch_sale_and_back_sale_STAGED.sql',
  '20261031_exact_batch_reversal_sources_STAGED.sql',
  '20261031_reversal_source_snapshot_STAGED.sql',
  'SOURCE-ARITHMETIC-SMOKE-READONLY.sql',
  'WAREHOUSE-BATCH-VALUATION-RECONCILIATION-READONLY.sql',
  'BACK-SALE-SOURCE-LEDGER-AUDIT-READONLY.sql'
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
  $ready=$false
  for($attempt=0;$attempt -lt 30;$attempt++){
    docker exec $ContainerName pg_isready -U postgres *> $null
    if($LASTEXITCODE -eq 0){ $ready=$true; break }
    Start-Sleep -Seconds 1
  }
  if(-not $ready){ throw 'Isolated PostgreSQL was not ready.' }
  # pg_cron only installs into cron.database_name (postgres by default).
  # Configure only this disposable container; disable restored scheduled jobs.
  docker exec $ContainerName psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -c "ALTER SYSTEM SET cron.database_name = 'bb_stock_v2_sandbox';"
  Check-LastExit 'Set sandbox pg_cron database'
  docker exec $ContainerName psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -c "ALTER SYSTEM SET cron.launch_active_jobs = off;"
  Check-LastExit 'Disable sandbox cron execution'
  docker restart $ContainerName | Out-Null
  Check-LastExit 'Restart isolated container for pg_cron setting'
  $ready=$false
  for($attempt=0;$attempt -lt 30;$attempt++){
    docker exec $ContainerName pg_isready -U postgres *> $null
    if($LASTEXITCODE -eq 0){ $ready=$true; break }
    Start-Sleep -Seconds 1
  }
  if(-not $ready){ throw 'Isolated PostgreSQL was not ready after pg_cron restart.' }
  $cronDatabase=(docker exec $ContainerName psql -X -U postgres -d postgres -tAc 'SHOW cron.database_name;').Trim()
  Check-LastExit 'Read sandbox pg_cron database'
  if($cronDatabase -ne 'bb_stock_v2_sandbox'){ throw "Unsafe cron database: $cronDatabase" }
  Write-Host 'Restoring backup COPY into isolated container (source remains unchanged).' -ForegroundColor Cyan
  docker cp "$BackupFile" "$($ContainerName):/tmp/local-source.backup" | Out-Null
  Check-LastExit 'Copy PostgreSQL dump'
  docker exec $ContainerName createdb -U postgres bb_stock_v2_sandbox
  Check-LastExit 'Create sandbox-only database'
  docker exec $ContainerName pg_restore --exit-on-error --no-owner --no-acl -U postgres -d bb_stock_v2_sandbox /tmp/local-source.backup
  Check-LastExit 'Restore isolated database'
  foreach($f in $files){ RunSql $f }
  Write-Host 'COMPILE + READ-ONLY SQL SMOKE COMPLETE in temporary database.' -ForegroundColor Green
  Write-Host 'NOTE: This alone does NOT validate authenticated UI, transactional transfers, reversals, or Local sync.' -ForegroundColor Yellow
} finally {
  if($started){
    Write-Host 'Removing ONLY the throwaway test container.' -ForegroundColor Cyan
    docker rm -f $ContainerName | Out-Null
  }
}
