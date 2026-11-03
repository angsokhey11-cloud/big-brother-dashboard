# BIG BROTHER -- V2 Cloud-to-Local PREFLIGHT ONLY.
# This launcher will never replace 08C, never run a merge, and never set CloudWinsConfirmed.
# It invokes the installed controller's -PreflightOnly mode only.
# Controller may start Local Supabase, capture Cloud read-only schema/data,
# and create a LOCAL backup. These are intended preflight side effects.
[CmdletBinding()]
param(
    [string]$LocalBrainRoot = 'D:\BIG BROTHER Local Backup\Local Brain',
    [string]$ControllerScriptPath = ''
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $LocalBrainRoot -PathType Container)) {
    throw "Local Brain root not found: $LocalBrainRoot"
}
if ($ControllerScriptPath -ne '') {
    $matches = @(Get-Item -LiteralPath $ControllerScriptPath -ErrorAction Stop)
} else {
    $matches = @(Get-ChildItem -LiteralPath $LocalBrainRoot -Recurse -File -Filter '08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2*.ps1' -ErrorAction Stop |
        Where-Object { $_.FullName -notmatch '[\\/](brain-backups|node_modules|\.git)[\\/]' })
}
if ($matches.Count -ne 1) {
    Write-Host "Found $($matches.Count) possible sync controllers." -ForegroundColor Yellow
    $matches | ForEach-Object { Write-Host $_.FullName }
    throw 'Select the installed controller with -ControllerScriptPath. Nothing ran.'
}
$controller = $matches[0].FullName
$dir = Split-Path -Parent $controller
$merge = Join-Path $dir '08C-MERGE-CLOUD-STAGE-PERMANENT-V1.2.sql'
$schemaGuard = Join-Path $dir 'V34-PRE-SYNC-SCHEMA-GUARD.ps1'
$codeGuard = Join-Path $dir 'V34-LOCAL-APPROVED-SQL-CODE-GATE.ps1'
foreach ($path in @($merge, $schemaGuard, $codeGuard)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required installed controller component missing: $path"
    }
}
$controllerText = Get-Content -LiteralPath $controller -Raw
if ($controllerText -notmatch '\[switch\]\$PreflightOnly' -or
    $controllerText -notmatch 'READ-ONLY CHECK COMPLETE' -or
    $controllerText -notmatch 'if\s*\(\$PreflightOnly\)') {
    throw 'Controller does not match the verified PRE-FLIGHT implementation. Nothing ran.'
}
Write-Host 'BIG BROTHER V2 -- READ-ONLY SCHEMA PREFLIGHT' -ForegroundColor Cyan
Write-Host "Installed controller: $controller"
Write-Host "Controller SHA256: $((Get-FileHash -LiteralPath $controller -Algorithm SHA256).Hash)"
Write-Host "Canonical 08C SQL: $merge"
Write-Host "08C SHA256: $((Get-FileHash -LiteralPath $merge -Algorithm SHA256).Hash)"
Write-Host 'The staged V2 SQL will NOT be installed, replaced, or run.' -ForegroundColor Yellow
Write-Host 'Preflight may start Local Supabase, capture Cloud data read-only and make a local backup.' -ForegroundColor Yellow
Write-Host 'It must stop BEFORE the staging import or 08C merge. Cloud is not changed.' -ForegroundColor Yellow
$confirmation = Read-Host 'Type RUN-READONLY-CHECK to proceed; anything else cancels'
if ($confirmation.Trim() -cne 'RUN-READONLY-CHECK') {
    Write-Host 'CANCELLED -- nothing changed.' -ForegroundColor Yellow
    exit 0
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $controller -PreflightOnly -LocalBrainRoot $LocalBrainRoot
$code = $LASTEXITCODE
if ($code -ne 0) {
    throw "Preflight failed with exit code $code. DO NOT RUN LIVE SYNC."
}
Write-Host 'READ-ONLY PREFLIGHT COMPLETED. The 08C merge was not requested.' -ForegroundColor Green
Write-Host 'Share only SCHEMA-GUARD-REPORT.txt and APPROVED-SQL-CODE-REPORT.txt.' -ForegroundColor Green
Write-Host 'Keep local-full-before-sync.dump and cloud-public-data.sql on your PC.' -ForegroundColor Yellow
