# BIG BROTHER - Stock Source Accounting V2 Step 2 / Real Invoice Trigger (ISOLATED ONLY)
# ONLY an existing pg_dump is read. Neither Cloud nor real Local are connected.
# NO migration, V2 deployment, Cloud->Local sync, or production changes.
param([Parameter(Mandatory=$true)][string]$ExistingSnapshot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/angsokhey11-cloud/big-brother-dashboard/6f6a1b3f408e3ef6d7cdb210acb793acb32b0a10/docs/stock-source-accounting-v2'
$work = Join-Path $env:USERPROFILE 'Desktop\BB-STOCK-SOURCE-V2-STEP2-INVOICE'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = $ExistingSnapshot
$log = Join-Path $work "V2-STEP2-INVOICE-$stamp.log"

$expected = [ordered]@{
  'TEST-ISOLATED-POSTGRES-STEP2-INVOICE.ps1' = '9c967601edbf4daf379826533af90bfb5a9f674f'
  '20261031_source_aware_batch_sale_and_back_sale_STAGED.sql' = '05ac68af720e44702bf0c326cf68d8b50e2d0761'
  '20261031_exact_batch_reversal_sources_STAGED.sql' = 'efd42b5e39c119aaa34195e23db0e6e69f14d17d'
  '20261031_reversal_source_snapshot_STAGED.sql' = '6b29ca6bb270e3b269b4526eab2a3eb29b79780d'
  'SOURCE-ARITHMETIC-SMOKE-READONLY.sql' = '101ee862d38269841dd286f121724996bc91f6fa'
  'WAREHOUSE-BATCH-VALUATION-RECONCILIATION-READONLY.sql' = '9a46841fa3b2595457bf8b0745a34cd3036e4a3a'
  'BACK-SALE-SOURCE-LEDGER-AUDIT-READONLY.sql' = 'e58e5b352480510d69035afd52b6205e5ce11c21'
  'ACTUAL-BATCH-INVOICE-SOURCE-ROLLBACK-ISOLATED.sql' = '5ee654a48b5928f9ad2d3d9cdb5994fed88edc19'
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
  Write-Host 'BIG BROTHER - Stock Source V2 Step 2: REAL Batch Invoice trigger test' -ForegroundColor Cyan
  Write-Host 'ONLY an existing Local dump is read. No Local/Cloud database connections.' -ForegroundColor Yellow
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop is required.' }
  $backup = $ExistingSnapshot
  if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw "Previous snapshot missing: $backup" }
  if ([IO.Path]::GetExtension($backup).ToLowerInvariant() -ne '.dump') { throw 'Previous snapshot must be a .dump file' }
  if ((Get-Item -LiteralPath $backup).Length -lt 1000000) { throw 'Previous snapshot too small' }
  Write-Host "Existing snapshot verified. No live database access: $backup" -ForegroundColor Green
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
  $runner = Join-Path $work 'TEST-ISOLATED-POSTGRES-STEP2-INVOICE.ps1'
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) { $errors | Format-List; throw 'PowerShell runner syntax invalid. Stop.' }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BackupFile $backup -StagedDir $work
  Assert-Exit 'Isolated SQL compile and audit'
  Write-Host 'STEP 2 INVOICE: STAGED FUNCTIONS COMPILED + REAL INVOICE TRIGGER TEST COMPLETED' -ForegroundColor Green
  Write-Host 'Back Sale, Reversal and UI integration tests remain pending.' -ForegroundColor Yellow
} catch {
  Write-Host "STEP 2 INVOICE FAILED: $($_.Exception.Message)" -ForegroundColor Red
  throw
} finally {
  Write-Host "Test transcript: $log" -ForegroundColor Cyan
  Stop-Transcript | Out-Null
}
