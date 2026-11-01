# BIG BROTHER - Stock Source Accounting V2 Step 1 (ISOLATED ONLY)
# Real Local: read-only pg_dump. Cloud: never connected. SQL runs in no-network Docker.
# NO migration, V2 deployment, Cloud->Local sync, or production changes.
param([string]$ExistingSnapshot='')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$live = 'supabase_db_Local_Brain'
$base = 'https://raw.githubusercontent.com/angsokhey11-cloud/big-brother-dashboard/8c98b0165263cb15af8dc4c7ed3c1fe4b1509401/docs/stock-source-accounting-v2'
$work = Join-Path $env:USERPROFILE 'Desktop\BB-STOCK-SOURCE-V2-STEP1'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $work "LOCAL-V2-READONLY-SNAPSHOT-$stamp.dump"
$log = Join-Path $work "V2-STEP1-COMPILE-$stamp.log"
$dumpInContainer = "/tmp/bb-v2-readonly-snapshot-$stamp.dump"

$expected = [ordered]@{
  'TEST-ISOLATED-POSTGRES.ps1' = '792a92debba3bc3d97aec1999e5de97098f75372'
  '20261031_source_aware_batch_sale_and_back_sale_STAGED.sql' = '8f8bafe3ea0d430c265c701a46eb97f379cee30d'
  '20261031_exact_batch_reversal_sources_STAGED.sql' = 'efd42b5e39c119aaa34195e23db0e6e69f14d17d'
  '20261031_reversal_source_snapshot_STAGED.sql' = '6b29ca6bb270e3b269b4526eab2a3eb29b79780d'
  'SOURCE-ARITHMETIC-SMOKE-READONLY.sql' = '101ee862d38269841dd286f121724996bc91f6fa'
  'WAREHOUSE-BATCH-VALUATION-RECONCILIATION-READONLY.sql' = '9a46841fa3b2595457bf8b0745a34cd3036e4a3a'
  'BACK-SALE-SOURCE-LEDGER-AUDIT-READONLY.sql' = 'e58e5b352480510d69035afd52b6205e5ce11c21'
}
function Assert-Exit([string]$action) {
  if ($LASTEXITCODE -ne 0) { throw "$action failed (exit code $LASTEXITCODE). Do NOT sync or deploy." }
}
function Get-GitBlobSha1([string]$file) {
  $bytes = [System.IO.File]::ReadAllBytes($file)
  $prefix = [System.Text.Encoding]::ASCII.GetBytes("blob " + $bytes.Length + [char]0)
  $inputBytes = New-Object byte[] ($prefix.Length + $bytes.Length)
  [Array]::Copy($prefix, 0, $inputBytes, 0, $prefix.Length)
  [Array]::Copy($bytes, 0, $inputBytes, $prefix.Length, $bytes.Length)
  $sha = [System.Security.Cryptography.SHA1]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($inputBytes))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
New-Item -ItemType Directory -Path $work -Force | Out-Null
Start-Transcript -Path $log -Force | Out-Null
try {
  Write-Host 'BIG BROTHER - Stock Source V2 ISOLATED compilation' -ForegroundColor Cyan
  Write-Host 'Production Local is read only; Cloud is not connected.' -ForegroundColor Yellow
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop is required.' }
  if (-not [string]::IsNullOrWhiteSpace($ExistingSnapshot)) {
    $backup = $ExistingSnapshot
    if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw "Previous snapshot missing: $backup" }
    if ([IO.Path]::GetExtension($backup).ToLowerInvariant() -ne '.dump') { throw 'Expected an existing .dump snapshot file.' }
    if ((Get-Item -LiteralPath $backup).Length -lt 1000000) { throw 'Previous snapshot too small. Stop.' }
    Write-Host "REUSING previous snapshot, without contacting live Local: $backup" -ForegroundColor Green
  } else {
  $names = @(docker ps --format '{{.Names}}')
  Assert-Exit 'List running containers'
  if ($live -notin $names) { throw 'Local Brain database container is not running. Stop.' }
  $db = @(docker exec $live psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -tAc 'SELECT current_database();')
  Assert-Exit 'Confirm Local database'
  if (($db -join '').Trim() -ne 'postgres') { throw 'Wrong Local database. Stop.' }
  Write-Host 'Taking consistent read-only pg_dump snapshot...' -ForegroundColor Cyan
  docker exec $live pg_dump -U postgres -d postgres -Fc -f $dumpInContainer
  Assert-Exit 'Read-only pg_dump'
  docker exec $live pg_restore --list $dumpInContainer | Out-Null
  Assert-Exit 'Verify dump'
  $dockerSrc = $live + ':' + $dumpInContainer
  docker cp $dockerSrc $backup | Out-Null
  Assert-Exit 'Copy dump to Desktop'
  if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw 'Missing backup. Stop.' }
  if ((Get-Item -LiteralPath $backup).Length -lt 1000000) { throw 'Backup too small. Stop.' }
  docker exec $live rm -f $dumpInContainer
  Assert-Exit 'Remove only the temporary dump file'
  Write-Host "Snapshot saved: $backup" -ForegroundColor Green
  }
  foreach ($name in $expected.Keys) {
    $dest = Join-Path $work $name
    Invoke-WebRequest -Uri "$base/$name" -OutFile $dest -UseBasicParsing -ErrorAction Stop
    if ((Get-GitBlobSha1 $dest) -ne $expected[$name]) { throw "Hash mismatch: $name. Stop." }
    Write-Host "Verified: $name" -ForegroundColor DarkGreen
  }
  # Reject a malformed staged reversal SQL before launching the test Docker container.
  $revFile = Join-Path $work '20261031_exact_batch_reversal_sources_STAGED.sql'
  $openCount = @(Select-String -LiteralPath $revFile -Pattern '^CREATE OR REPLACE FUNCTION ').Count
  $endCount = @(Select-String -LiteralPath $revFile -Pattern '^\$function\$;$').Count
  if ($openCount -ne 6 -or $endCount -ne 6) { throw "Reversal SQL delimiter mismatch: $openCount starts / $endCount ends" }
  Write-Host "Reversal SQL statement delimiters passed: $endCount/6" -ForegroundColor Green
  $runner = Join-Path $work 'TEST-ISOLATED-POSTGRES.ps1'
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) { $errors | Format-List; throw 'PowerShell runner syntax invalid. Stop.' }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BackupFile $backup -StagedDir $work
  Assert-Exit 'Isolated SQL compile and audit'
  Write-Host 'STEP 1 PASSED: STAGED SQL COMPILED + READ-ONLY AUDITS RAN IN ISOLATED DATABASE' -ForegroundColor Green
  Write-Host 'Actual sale, Back Sale and reversal integration tests remain pending.' -ForegroundColor Yellow
} catch {
  Write-Host "STEP 1 FAILED: $($_.Exception.Message)" -ForegroundColor Red
  throw
} finally {
  Write-Host "Test transcript: $log" -ForegroundColor Cyan
  Stop-Transcript | Out-Null
}
