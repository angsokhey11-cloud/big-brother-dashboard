# BIG BROTHER V3.4 — One-time guarded Android FCM business-only controller upgrade after Code Sync.
# This DOES NOT run SQL, Cloud -> Local, Code Sync or business transactions.
# It backs up and updates the exact approved 08 PowerShell controller file.
# Refuses unknown controller SHA, missing Code Sync schema and unsafe edits.
[CmdletBinding()]
param(
  [string]$LocalBrainRoot = 'D:\BIG BROTHER Local Backup\Local Brain',
  [string]$SyncScript = ''
)
$ErrorActionPreference = 'Stop'
$scriptName = '08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2.ps1'
$originalSha = 'A2073E47A898391F166C7867CBEFC0B70FAD58BA5686EB13CCF1F59F33DB674E'
# The 29-Oct diagnostic found 11 archived copies. Only patch the ACTIVE
# V3.4 controller helper, never a random old/legacy/tool copy.
if(-not $SyncScript){
  $SyncScript = Join-Path $LocalBrainRoot ('3.4 Controller\BIG_BROTHER_V34_DEVELOPER\helpers\'+$scriptName)
}
if(-not (Test-Path -LiteralPath $SyncScript)){
  throw "CONTROLLER_UPDATE_STOP: controller missing: $SyncScript"
}
$source = [System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)
if($source.Contains('BUSINESS_ONLY_STAGE: 8 notification infrastructure tables') -and
   $source.Contains('CODE_SYNC_GATE_CHECK_ONLY') -and
   $source.Contains('LOCAL_FOUNDATION_READ_ONLY')){
  Write-Host 'Already updated: business-only stage and read-only code gates present.' -ForegroundColor Green
  exit 0
}
# Confirm Code Sync installed the three empty FCM table structures first.
# This query is READ ONLY and never copies cloud Firebase credentials.
$checkSql = @'
SELECT CASE WHEN
  to_regclass('public.bb_fcm_config_v1') IS NOT NULL
  AND to_regclass('public.bb_fcm_devices_v1') IS NOT NULL
  AND to_regclass('public.bb_fcm_deliveries_v1') IS NOT NULL
  AND to_regprocedure('private.bb_local_reject_infrastructure_replay_v1()') IS NOT NULL
  AND (SELECT count(*) FROM pg_trigger t WHERE t.tgname='bb_local_business_only_replay_guard_v1'
       AND t.tgenabled='A' AND t.tgrelid IN ('public.bb_fcm_config_v1'::regclass,
                                            'public.bb_fcm_devices_v1'::regclass,
                                            'public.bb_fcm_deliveries_v1'::regclass))=3
 THEN 'READY' ELSE 'MISSING' END;
'@
$schemaCheck = @(& docker exec supabase_db_Local_Brain psql -X -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -c $checkSql 2>&1)
if($LASTEXITCODE -ne 0 -or (($schemaCheck -join "`n").Trim() -ne 'READY')){
  throw 'CONTROLLER_UPDATE_STOP: Android FCM Code Sync schema and ALWAYS guards not verified. Run Code Sync first; do NOT run Cloud->Local.'
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
    # Keep COPY headers for staging parity; zero out the eight notification infrastructure
    # DATA blocks. Never copy push credentials or device subscriptions to Local.
    $excluded=@{
        bb_notification_events_v2=0
        bb_push_config_v1=0
        bb_push_deliveries_v1=0
        bb_push_subscriptions_v1=0
        bb_fcm_config_v1=0
        bb_fcm_devices_v1=0
        bb_fcm_deliveries_v1=0
        app_notification_state=0
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
            if($line -match '^\s*COPY\s+(?:"public"|public)\.(?:"?)(bb_notification_events_v2|bb_push_config_v1|bb_push_deliveries_v1|bb_push_subscriptions_v1|bb_fcm_config_v1|bb_fcm_devices_v1|bb_fcm_deliveries_v1|app_notification_state)(?:"?)\s*\('){
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
    Write-Host "BUSINESS_ONLY_STAGE: 8 notification infrastructure tables have empty stage data (skipped $skipped rows); Cloud capture unchanged." -ForegroundColor Green
}
'@
# Parse exact function boundaries using PowerShell's own parser. Never
# splice based on a neighboring Write-Host line or match arbitrary helper code.
$parseTokens=$null
$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput(
  $source,[ref]$parseTokens,[ref]$parseErrors)
if($parseErrors -and $parseErrors.Count -gt 0){
  throw 'CONTROLLER_UPDATE_STOP: original controller PowerShell parse failed. No changes made.'
}
$functions=@($ast.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -eq 'Rewrite-CloudDumpForStage'
},$true))
if($functions.Count -ne 1){
  throw "CONTROLLER_UPDATE_STOP: expected exactly one stage rewrite function, found $($functions.Count)"
}
$start=$functions[0].Extent.StartOffset
$end=$functions[0].Extent.EndOffset
if($start -lt 0 -or $end -le $start -or
   $source.Substring($start,[Math]::Min(64,$end-$start)) -notmatch '^function Rewrite-CloudDumpForStage'){
  throw 'CONTROLLER_UPDATE_STOP: unsafe function range. No changes made.'
}
$patched=$source.Substring(0,$start)+$func+$source.Substring($end)
$gateOld='if($PreflightOnly){$sqlGateArgs+=''-CheckOnly''}'
$gateNew=@'
# CODE_SYNC_GATE_CHECK_ONLY: only verify Code Sync state; never apply SQL code here.
$sqlGateArgs+='-CheckOnly'
'@
if($patched.IndexOf($gateOld) -lt 0 -or $patched.IndexOf($gateOld) -ne $patched.LastIndexOf($gateOld)){
  throw 'CONTROLLER_UPDATE_STOP: unable to locate SQL code gate for read-only mode.'
}
$patched=$patched.Replace($gateOld,$gateNew)
# Windows CRLF did not match the previous LF-only two-line literal.
# Identify the unique actual permanent-ID foundation SQL invocation by AST.
$foundationTokens=$null
$foundationErrors=$null
$foundationAst=[System.Management.Automation.Language.Parser]::ParseInput(
  $patched,[ref]$foundationTokens,[ref]$foundationErrors)
if($foundationErrors -and $foundationErrors.Count -gt 0){
  throw 'CONTROLLER_UPDATE_STOP: controller has parse errors before foundation edit.'
}
$foundationCalls=@($foundationAst.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.CommandAst] -and
  $node.GetCommandName() -eq 'Invoke-PsqlFile' -and
  $node.Extent.Text -match '\$foundationSql\b'
},$true))
if($foundationCalls.Count -ne 1){
  throw "CONTROLLER_UPDATE_STOP: expected one foundation SQL invocation, found $($foundationCalls.Count). No changes made."
}
$call=$foundationCalls[0].Extent
$foundationNew=@'
# LOCAL_FOUNDATION_READ_ONLY: only Code Sync manages the ID foundation.
$readinessSql="select case when to_regclass('public.bb_id_counters') is not null and to_regclass('public.bb_permanent_id_registry') is not null then 'READY' else 'MISSING' end;"
$ready=@(& docker exec $dbContainer psql -X -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -c $readinessSql 2>&1)
if($LASTEXITCODE -ne 0 -or (($ready -join [Environment]::NewLine).Trim() -ne 'READY')){
  Fail 'Local permanent-ID foundation not ready. Run Code Sync first.'
}
'@
$patched=$patched.Substring(0,$call.StartOffset)+$foundationNew+$patched.Substring($call.EndOffset)
$patched=$patched.Replace(
  '5/8 Install/verify Local permanent-ID foundation',
  '5/8 Verify Local permanent-ID foundation (READ ONLY)')
if($patched -match '(?im)Invoke-PsqlFile[^\r\n]*\$foundationSql'){
  throw 'CONTROLLER_UPDATE_STOP: foundation SQL execution still present after patch.'
}
$finalTokens=$null
$finalErrors=$null
$null=[System.Management.Automation.Language.Parser]::ParseInput(
  $patched,[ref]$finalTokens,[ref]$finalErrors)
if($finalErrors -and $finalErrors.Count -gt 0){
  throw 'CONTROLLER_UPDATE_STOP: final controller parse failed. No changes made.'
}
$patched=$patched.Replace("Write-Step '4B/8 Verify approved Local SQL code updates'","Write-Step '4B/8 Verify Code Sync SQL state (READ ONLY)'")
if(-not ($patched.Contains('BUSINESS_ONLY_STAGE: 8 notification infrastructure tables') -and
         $patched.Contains('CODE_SYNC_GATE_CHECK_ONLY') -and
         $patched.Contains('LOCAL_FOUNDATION_READ_ONLY'))){
  throw 'CONTROLLER_UPDATE_STOP: business-only / no-SQL-write validation failed.'
}
$backup=$SyncScript+'.before-business-only-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $SyncScript -Destination $backup -ErrorAction Stop
try {
  # BOM allows Windows PowerShell 5.1 to decode original and replacement safely.
  [System.IO.File]::WriteAllText($SyncScript,$patched,(New-Object System.Text.UTF8Encoding($true)))
  if(-not ([System.IO.File]::ReadAllText($SyncScript,[System.Text.Encoding]::UTF8)).Contains('BUSINESS_ONLY_STAGE: 8 notification infrastructure tables')){
    throw 'Write verification failed'
  }
}catch{
  Copy-Item -LiteralPath $backup -Destination $SyncScript -Force
  throw
}
Write-Host 'BIG BROTHER Cloud -> Local controller: BUSINESS-ONLY stage filter INSTALLED.' -ForegroundColor Green
Write-Host ('Controller backup: '+$backup)
Write-Host 'Schema Guard and exact 08C rollback rehearsal remain unchanged. SQL Gate/foundation are READ-ONLY.' -ForegroundColor Cyan
