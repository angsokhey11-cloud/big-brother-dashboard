# BIG BROTHER V3.4 — One-time controller update after standard Code Sync.
# This DOES NOT run SQL, Cloud -> Local, Code Sync or business transactions.
# It backs up and updates the exact approved 08 PowerShell controller file.
# Refuses unknown files, multiple copies, and missing Code Sync schema.
[CmdletBinding()]
param(
  [string]$LocalBrainRoot = 'D:\BIG BROTHER Local Backup\Local Brain',
  [string]$SyncScript = ''
)
$ErrorActionPreference = 'Stop'
$scriptName = '08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2.ps1'
$originalSha = 'A2073E47A898391F166C7867CBEFC0B70FAD58BA5686EB13CCF1F59F33DB674E'
if(-not $SyncScript){
  $matches = @(Get-ChildItem -LiteralPath $LocalBrainRoot -Filter $scriptName -Recurse -File -ErrorAction Stop)
  if($matches.Count -ne 1){
    throw "CONTROLLER_UPDATE_STOP: expected one $scriptName inside Local Brain; found $($matches.Count). Pass -SyncScript with exact path."
  }
  $SyncScript = $matches[0].FullName
}
if(-not (Test-Path -LiteralPath $SyncScript)){
  throw "CONTROLLER_UPDATE_STOP: controller missing: $SyncScript"
}
$source = [System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)
if($source.Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables') -and
   $source.Contains('CODE_SYNC_GATE_CHECK_ONLY') -and
   $source.Contains('LOCAL_FOUNDATION_READ_ONLY')){
  Write-Host 'Already updated: business-only staging and read-only code gates present.' -ForegroundColor Green
  exit 0
}
$sha=(Get-FileHash -LiteralPath $SyncScript -Algorithm SHA256).Hash.ToUpperInvariant()
if($sha -ne $originalSha){
  throw "CONTROLLER_UPDATE_STOP: unknown 08 script version ($sha). No change made. Review this exact file before patching."
}
if(-not $source.Contains("V34-PRE-SYNC-SCHEMA-GUARD.ps1") -or
   -not $source.Contains('Rewrite-CloudDumpForStage $cloudDump $stageDump')){
  throw 'CONTROLLER_UPDATE_STOP: expected Schema Guard and staging flow missing.'
}
$func = @'
function Rewrite-CloudDumpForStage {
    param([string]$InputPath,[string]$OutputPath)
    # Keep COPY headers for staging parity; zero out the four infrastructure
    # DATA blocks. Never copy push credentials or device subscriptions to Local.
    $excluded=@{
        bb_notification_events_v2=0
        bb_push_config_v1=0
        bb_push_deliveries_v1=0
        bb_push_subscriptions_v1=0
    }
    $seen=@{}
    $skip=$false
    $current=''
    $skipped=0L
    $reader=New-Object System.IO.StreamReader($InputPath,$true)
    $writer=New-Object System.IO.StreamWriter($OutputPath,$false,(New-Object System.Text.UTF8Encoding($false)))
    try {
        while(($line=$reader.ReadLine()) -ne $null){
            if($skip){
                if($line -eq '\.'){
                    $writer.WriteLine($line)
                    $skip=$false
                    $current=''
                }else{$skipped++}
                continue
            }
            if($line -match '^\s*COPY\s+(?:"public"|public)\.(?:"?)(bb_notification_events_v2|bb_push_config_v1|bb_push_deliveries_v1|bb_push_subscriptions_v1)(?:"?)\s*\('){
                $current=$Matches[1]
                if($seen.ContainsKey($current)){throw "BUSINESS_SCOPE_STOP: duplicate COPY for $current"}
                $seen[$current]=$true
                $skip=$true
            }
            if($line -match '^COPY\s+"public"\.'){
                $line=$line -replace '^COPY\s+"public"\.','COPY "bb_cloud_stage".'
            }elseif($line -match '^COPY\s+public\.'){
                $line=$line -replace '^COPY\s+public\.','COPY bb_cloud_stage.'
            }
            if($line -match '^\s*SELECT\s+pg_catalog\.setval\('){continue}
            $writer.WriteLine($line)
        }
        if($skip){throw "BUSINESS_SCOPE_STOP: unterminated COPY for $current"}
        foreach($name in $excluded.Keys){
            if(-not $seen.ContainsKey($name)){
                throw "BUSINESS_SCOPE_STOP: expected infrastructure COPY missing: $name"
            }
        }
    }finally{$reader.Dispose();$writer.Dispose()}
    Write-Host "BUSINESS_ONLY_STAGE: 4 device infrastructure tables have empty stage data (skipped $skipped rows); Cloud capture unchanged." -ForegroundColor Green
}
'@
$pattern='(?s)function Rewrite-CloudDumpForStage \{.*?(?=\r?\nWrite-Host ""\r?\n)'
$m=[regex]::Matches($source,$pattern)
if($m.Count -ne 1){throw "CONTROLLER_UPDATE_STOP: cannot isolate existing stage function safely (matches $($m.Count))."}
$replacement=$func + [Environment]::NewLine
$patched=$source.Substring(0,$m[0].Index)+$replacement+$source.Substring($m[0].Index+$m[0].Length)
# Cloud -> Local is strictly business-data-only; no Code SQL migrations run here.
$gateOld="if("+ '
$backup=$SyncScript+'.before-business-only-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $SyncScript -Destination $backup -ErrorAction Stop
try {
  # BOM allows Windows PowerShell 5.1 to decode original and replacement safely.
  [System.IO.File]::WriteAllText($SyncScript,$patched,(New-Object System.Text.UTF8Encoding($true)))
  if(-not ([System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)).Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables')){
    throw 'Write verification failed'
  }
}catch{
  Copy-Item -LiteralPath $backup -Destination $SyncScript -Force
  throw
}
Write-Host 'BIG BROTHER Cloud -> Local controller: BUSINESS-ONLY stage filter INSTALLED.' -ForegroundColor Green
Write-Host ('Controller backup: '+$backup)
Write-Host 'Schema Guard and exact 08C rollback rehearsal remain unchanged. SQL Gate/foundation are READ-ONLY.' -ForegroundColor Cyan
 +"PreflightOnly){"+ '
$backup=$SyncScript+'.before-business-only-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $SyncScript -Destination $backup -ErrorAction Stop
try {
  # BOM allows Windows PowerShell 5.1 to decode original and replacement safely.
  [System.IO.File]::WriteAllText($SyncScript,$patched,(New-Object System.Text.UTF8Encoding($true)))
  if(-not ([System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)).Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables')){
    throw 'Write verification failed'
  }
}catch{
  Copy-Item -LiteralPath $backup -Destination $SyncScript -Force
  throw
}
Write-Host 'BIG BROTHER Cloud -> Local controller: BUSINESS-ONLY stage filter INSTALLED.' -ForegroundColor Green
Write-Host ('Controller backup: '+$backup)
Write-Host 'Schema Guard, SQL Code Gate, exact rollback rehearsal and 08C remain unchanged.' -ForegroundColor Cyan
 +"sqlGateArgs+='-CheckOnly'}"
$gateNew=@'
# CODE_SYNC_GATE_CHECK_ONLY: only verify Code Sync state; never apply SQL code here.
$sqlGateArgs+='-CheckOnly'
'@
if($patched.IndexOf($gateOld) -lt 0 -or $patched.IndexOf($gateOld) -ne $patched.LastIndexOf($gateOld)){
  throw 'CONTROLLER_UPDATE_STOP: unable to locate approved SQL code gate for read-only mode.'
}
$patched=$patched.Replace($gateOld,$gateNew)
$foundationOld=@'
Write-Step "5/8 Install/verify Local permanent-ID foundation"
Invoke-PsqlFile $dbContainer $foundationSql "/tmp/08A-foundation-v1.2.sql"
'@
$foundationNew=@'
Write-Step "5/8 Verify Local permanent-ID foundation (READ ONLY)"
# LOCAL_FOUNDATION_READ_ONLY: Code Sync installs the foundation, not business sync.
$readinessSql="select case when to_regclass('public.bb_id_counters') is not null and to_regclass('public.bb_permanent_id_registry') is not null then 'READY' else 'MISSING' end;"
$ready=& docker exec $dbContainer psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c $readinessSql
if($LASTEXITCODE -ne 0 -or (($ready -join "`n").Trim() -ne 'READY')){
  Fail 'Local permanent-ID foundation not ready. Run Code Sync first.'
}
'@
if($patched.IndexOf($foundationOld) -lt 0 -or $patched.IndexOf($foundationOld) -ne $patched.LastIndexOf($foundationOld)){
  throw 'CONTROLLER_UPDATE_STOP: unable to locate existing foundation installation step.'
}
$patched=$patched.Replace($foundationOld,$foundationNew)
$patched=$patched.Replace("Write-Step '4B/8 Verify approved Local SQL code updates'","Write-Step '4B/8 Verify Code Sync SQL state (READ ONLY)'")
if(-not ($patched.Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables') -and
         $patched.Contains('CODE_SYNC_GATE_CHECK_ONLY') -and
         $patched.Contains('LOCAL_FOUNDATION_READ_ONLY'))){
  throw 'CONTROLLER_UPDATE_STOP: business-only / no-SQL-write validation failed.'
}
$backup=$SyncScript+'.before-business-only-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $SyncScript -Destination $backup -ErrorAction Stop
try {
  # BOM allows Windows PowerShell 5.1 to decode original and replacement safely.
  [System.IO.File]::WriteAllText($SyncScript,$patched,(New-Object System.Text.UTF8Encoding($true)))
  if(-not ([System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)).Contains('BUSINESS_ONLY_STAGE: 4 device infrastructure tables')){
    throw 'Write verification failed'
  }
}catch{
  Copy-Item -LiteralPath $backup -Destination $SyncScript -Force
  throw
}
Write-Host 'BIG BROTHER Cloud -> Local controller: BUSINESS-ONLY stage filter INSTALLED.' -ForegroundColor Green
Write-Host ('Controller backup: '+$backup)
Write-Host 'Schema Guard, SQL Code Gate, exact rollback rehearsal and 08C remain unchanged.' -ForegroundColor Cyan
