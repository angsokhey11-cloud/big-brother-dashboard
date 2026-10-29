# BIG BROTHER V3.4 — targeted Approved SQL CHECK ONLY gate repair.
# Based on actual approved gate uploaded 29-Oct-2026.
# No SQL, schema, business data, bank, expenses, salary or Cloud writes.
# Only replaces the audited Schema Guard status-check block, with a backup.
[CmdletBinding()]
param([string]$LocalBrainRoot='D:\BIG BROTHER Local Backup\Local Brain')
$ErrorActionPreference='Stop'
$active=Join-Path $LocalBrainRoot '3.4 Controller\BIG_BROTHER_V34_DEVELOPER\helpers\V34-LOCAL-APPROVED-SQL-CODE-GATE.ps1'
$originalHash='B1C6D7C26FD30C8D731597F4985915C5575FFF46248F2C1E396CC77B91B3BC8A'
$fixedHash='DFE20DDADF96503D0338FC8F9B8D9F412801F06169F9EC57C4DEF2FBA2D2F756'
function NormalizedHash([string]$text) {
  $s=$text.Replace(([string][char]13+[char]10),[string][char]10)
  $bytes=(New-Object System.Text.UTF8Encoding($false)).GetBytes($s)
  $digest=[System.Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($digest.ComputeHash($bytes)).Replace('-','') }
  finally { $digest.Dispose() }
}
if(-not (Test-Path -LiteralPath $active -PathType Leaf)){
  throw "APPROVAL_GATE_STOP: active V3.4 SQL gate not found: $active"
}
$original=[System.IO.File]::ReadAllText($active,[System.Text.Encoding]::UTF8)
$normalized=$original.Replace(([string][char]13+[char]10),[string][char]10)
$sha=NormalizedHash $normalized
if($sha -eq $fixedHash){
  Write-Host 'Already updated: approved SQL gate supports safe PASSED preflight status.' -ForegroundColor Green
  exit 0
}
if($sha -ne $originalHash){
  throw "APPROVAL_GATE_STOP: unrecognized active SQL gate version ($sha). No change made."
}
$old=@'
  if($CheckOnly){
    if($schemaText -notmatch 'STATUS: CHECK ONLY - SAFE MIGRATIONS IDENTIFIED'){throw 'Read-only schema guard not passed'}
  } elseif ($schemaText -notmatch 'STATUS: PASSED - SAFE ADDITIVE SCHEMA READY') {
    throw 'Real schema guard did not pass'
  }
'@
$new=@'
  # A successful AUTO SAFE-ADDITIVE schema guard can legitimately report
  # STATUS: PASSED - ... during a CheckOnly Cloud -> Local preflight. The
  # legacy gate only accepted CHECK ONLY - SAFE MIGRATIONS IDENTIFIED,
  # incorrectly blocking already-valid Local functions.
  # Require exactly one clean status and an explicit ZERO blockers result;
  # never accept BLOCKED, FAILED or a missing/ambiguous guard result.
  $statusMatches=[regex]::Matches($schemaText,'(?m)^STATUS:\s*(.+?)\s*$')
  $blockerMatches=[regex]::Matches($schemaText,'(?m)^BLOCKERS:\s*(\d+)\s*$')
  if($statusMatches.Count -ne 1 -or $blockerMatches.Count -ne 1){
    throw 'Schema guard status or blockers count missing/ambiguous'
  }
  $guardStatus=$statusMatches[0].Groups[1].Value.Trim()
  $blockers=[int]$blockerMatches[0].Groups[1].Value
  if($blockers -ne 0){throw ('Schema guard has '+$blockers+' blockers')}
  $guardPassed=$guardStatus -match '^PASSED(?:\s*-\s*.+)?$'
  $guardCheckSafe=$guardStatus -eq 'CHECK ONLY - SAFE MIGRATIONS IDENTIFIED'
  if($CheckOnly){
    if(-not ($guardPassed -or $guardCheckSafe)){
      throw ('Read-only schema guard not passed: '+$guardStatus)
    }
  } elseif(-not $guardPassed){
    throw ('Real schema guard did not pass: '+$guardStatus)
  }
'@
# Git on Windows can check out this installer as CRLF while the active file
# is normalized to LF. Normalize both reviewed snippets before exact matching.
$old=$old.Replace(([string][char]13+[char]10),[string][char]10)
$new=$new.Replace(([string][char]13+[char]10),[string][char]10)
if($normalized.IndexOf($old,[StringComparison]::Ordinal) -lt 0 -or
   $normalized.IndexOf($old,[StringComparison]::Ordinal) -ne
   $normalized.LastIndexOf($old,[StringComparison]::Ordinal)){
  throw 'APPROVAL_GATE_STOP: exact reviewed status check not unique. No change made.'
}
$patched=$normalized.Replace($old,$new)
if((NormalizedHash $patched) -ne $fixedHash){
  throw 'APPROVAL_GATE_STOP: patched gate differs from reviewed result. No change made.'
}
$tokens=$null;$errors=$null
$null=[System.Management.Automation.Language.Parser]::ParseInput($patched,[ref]$tokens,[ref]$errors)
if($errors -and $errors.Count -gt 0){
  throw 'APPROVAL_GATE_STOP: edited PowerShell failed parser validation. No change made.'
}
$backup=$active+'.before-safe-preflight-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak'
Copy-Item -LiteralPath $active -Destination $backup -ErrorAction Stop
try{
  # UTF8 BOM keeps Windows PowerShell 5.1 UTF8 handling deterministic.
  [System.IO.File]::WriteAllText($active,$patched,(New-Object System.Text.UTF8Encoding($true)))
  $after=[System.IO.File]::ReadAllText($active,[System.Text.Encoding]::UTF8)
  if((NormalizedHash $after) -ne $fixedHash){
    throw 'APPROVAL_GATE_STOP: verification of installed gate hash failed'
  }
}catch{
  Copy-Item -LiteralPath $backup -Destination $active -Force
  throw
}
Write-Host 'BIG BROTHER V3.4: APPROVED SQL GATE SAFELY UPDATED.' -ForegroundColor Green
Write-Host ('Backup: '+$backup) -ForegroundColor Cyan
Write-Host 'This installs no SQL and leaves all existing Batch Editor/Salary/Bank records untouched.' -ForegroundColor Cyan
