# BIG BROTHER V3.4 — Cloud -> Local Stage Payment Index Compatibility Installer V2
# Source delivered by Code Sync. This edits ONLY the verified Windows controller
# and installs the stage helper next to it, with backups. NO SQL executes here.
[CmdletBinding()]
param(
    [string]$LocalBrainRoot='D:\BIG BROTHER Local Backup\Local Brain',
    [string]$SyncScript=''
)
$ErrorActionPreference='Stop'
$scriptName='08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2.ps1'
$stageName='08D-CHECK-STAGE-PAYMENTS-INDEX-V1.sql'
$stageSource=Join-Path $PSScriptRoot $stageName
$stageHash='6A46BB1F021AF82E930B0E8E6E300E7E1CD453395225BE92B904FFD9FADF6E40'
$originalSha='A2073E47A898391F166C7867CBEFC0B70FAD58BA5686EB13CCF1F59F33DB674E'
function Get-BBTextSha256([string]$Path){
    # Hash normalized UTF-8 source content: Windows checkout may add CRLF
    # without changing this Code Synced SQL file's semantics.
    $text=[System.IO.File]::ReadAllText($Path,[System.Text.Encoding]::UTF8)
    $text=$text.TrimStart([char]0xFEFF).Replace("`r`n","`n")
    $utf8=New-Object System.Text.UTF8Encoding($false)
    $sha=[System.Security.Cryptography.SHA256]::Create()
    try {
        $digest=$sha.ComputeHash($utf8.GetBytes($text))
        return [System.BitConverter]::ToString($digest).Replace('-','').ToUpperInvariant()
    }finally{$sha.Dispose()}
}

if(!(Test-Path -LiteralPath $stageSource -PathType Leaf)){
    throw "BANK_STAGE_INSTALL_STOP: $stageName was not downloaded by Code Sync."
}
if((Get-BBTextSha256 $stageSource) -ne $stageHash){
    throw "BANK_STAGE_INSTALL_STOP: stage helper checksum mismatch. Do not install."
}

if(-not $SyncScript){
    $candidates=@(Get-ChildItem -LiteralPath $LocalBrainRoot -Filter $scriptName -Recurse -File -ErrorAction Stop)
    if($candidates.Count -ne 1){
        throw "BANK_STAGE_INSTALL_STOP: found $($candidates.Count) controllers named $scriptName. Select the exact controller with -SyncScript."
    }
    $SyncScript=$candidates[0].FullName
}
if(!(Test-Path -LiteralPath $SyncScript -PathType Leaf)){
    throw "BANK_STAGE_INSTALL_STOP: cannot find controller: $SyncScript"
}
$oldHash=(Get-FileHash -LiteralPath $SyncScript -Algorithm SHA256).Hash.ToUpperInvariant()
$source=[System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)

# If the controller is still the exact original V1.2 file, upgrade it via the
# already approved V1 business-only installer before adding the stage guard.
if($oldHash -eq $originalSha -and
    -not $source.Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables')){
    $legacyInstaller=Join-Path $PSScriptRoot 'V34-INSTALL-BUSINESS-ONLY-STAGING-V1.ps1'
    if(!(Test-Path -LiteralPath $legacyInstaller -PathType Leaf)){
        throw 'BANK_STAGE_INSTALL_STOP: original controller needs V1 business-only updater from Code Sync.'
    }
    Write-Host 'Applying verified business-only controller prerequisite...' -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $legacyInstaller -SyncScript $SyncScript
    if($LASTEXITCODE -ne 0){
        throw 'BANK_STAGE_INSTALL_STOP: V1 controller prerequisite failed; no V2 update attempted.'
    }
    $source=[System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)
}
if(-not($source.Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables') -and
         $source.Contains('CODE_SYNC_GATE_CHECK_ONLY') -and
         $source.Contains('LOCAL_FOUNDATION_READ_ONLY'))){
    throw 'BANK_STAGE_INSTALL_STOP: controller not the reviewed business-only/read-only-code version. Nothing changed by V2.'
}

$stageTarget=Join-Path (Split-Path -Parent $SyncScript) $stageName
if(Test-Path -LiteralPath $stageTarget -PathType Leaf){
    if((Get-BBTextSha256 $stageTarget) -ne $stageHash){
        throw 'BANK_STAGE_INSTALL_STOP: an unrecognized stage SQL helper exists beside controller. No overwrite.'
    }
}
$marker='BANK_STAGE_PARITY_STEP_V1'
if($source.Contains($marker)){
    if(-not (Test-Path -LiteralPath $stageTarget -PathType Leaf)){
        Copy-Item -LiteralPath $stageSource -Destination $stageTarget -ErrorAction Stop
    }
    Write-Host 'Already installed: Step 6 stage index parity guard is active.' -ForegroundColor Green
    exit 0
}
$anchor=@'
Invoke-PsqlFile $dbContainer $prepareSql "/tmp/08B-prepare-stage-v1.2.sql"
Rewrite-CloudDumpForStage $cloudDump $stageDump
'@
$injection=@'
Invoke-PsqlFile $dbContainer $prepareSql "/tmp/08B-prepare-stage-v1.2.sql"
# BANK_STAGE_PARITY_STEP_V1: Local code was installed by Code Sync; now align
# the isolated staging payment INDEX before copying Cloud payment rows.
# This stage-only SQL checks permanent public indexes READ-ONLY. It cannot
# drop indexes or modify data in public.payments.
$stageIndexGuardSql=Join-Path $scriptDir "08D-CHECK-STAGE-PAYMENTS-INDEX-V1.sql"
if(!(Test-Path -LiteralPath $stageIndexGuardSql)){Fail 'Stage payment index guard missing. Run Code Sync installer first.'}
Write-Step "6A/8 Verify Local and staging payment index compatibility"
Invoke-PsqlFile $dbContainer $stageIndexGuardSql "/tmp/08D-stage-payments-index-v1.sql"
Rewrite-CloudDumpForStage $cloudDump $stageDump
'@
if($source.IndexOf($anchor) -lt 0 -or $source.IndexOf($anchor) -ne $source.LastIndexOf($anchor)){
    throw 'BANK_STAGE_INSTALL_STOP: cannot verify exact Step 6 insertion point; controller unchanged.'
}
$patched=$source.Replace($anchor,$injection)
if($patched.Contains($marker) -eq $false){
    throw 'BANK_STAGE_INSTALL_STOP: patched controller verification failed'
}

$backup=$SyncScript+'.before-stage-payment-parity-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $SyncScript -Destination $backup -ErrorAction Stop
$copiedStage=$false
try{
    if(!(Test-Path -LiteralPath $stageTarget -PathType Leaf)){
        Copy-Item -LiteralPath $stageSource -Destination $stageTarget -ErrorAction Stop
        $copiedStage=$true
    }
    if((Get-BBTextSha256 $stageTarget) -ne $stageHash){
        throw 'Stage SQL helper verification failed after copy'
    }
    # UTF-8 BOM is compatible with the existing Windows PowerShell 5.1 controller.
    [System.IO.File]::WriteAllText($SyncScript,$patched,(New-Object System.Text.UTF8Encoding($true)))
    $installed=[System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)
    if(-not $installed.Contains($marker)){throw 'Updated controller verification failed'}
}catch{
    Copy-Item -LiteralPath $backup -Destination $SyncScript -Force
    if($copiedStage){Remove-Item -LiteralPath $stageTarget -Force -ErrorAction SilentlyContinue}
    throw
}
Write-Host 'BIG BROTHER: Stage 6 payment-index compatibility check INSTALLED.' -ForegroundColor Green
Write-Host ('Controller backup: '+$backup)
Write-Host 'No SQL run, no business records changed. Next: Code Sync status, then fresh Cloud -> Local.' -ForegroundColor Cyan
