# BIG BROTHER Local Brain V3.4 — READ ONLY Sync Diagnostic V1
# Inspect actual LOCAL controller files and PostgreSQL index state.
# NO database updates, schema changes, Code Sync, Cloud sync, or payment changes.
# DO NOT include keys, passwords, env files, or raw business records in report.
[CmdletBinding()]
param(
    [string]$LocalBrainRoot='D:\BIG BROTHER Local Backup\Local Brain',
    [string]$DbContainer='supabase_db_Local_Brain'
)
$ErrorActionPreference='Stop'
$lines=New-Object System.Collections.Generic.List[string]
function Report([string]$message) {
    [void]$script:lines.Add($message)
    Write-Host $message
}
function Line { Report ('-'*72) }
function SafeFiles([string]$filter) {
    try {
        return @(Get-ChildItem -LiteralPath $LocalBrainRoot -Filter $filter -File -Recurse -ErrorAction Stop)
    } catch {
        Report ('FILE_SEARCH_ERROR ['+$filter+']: '+$_.Exception.Message)
        return @()
    }
}
function InspectScripts([string]$filter,[bool]$controller) {
    $found=@(SafeFiles $filter)
    Report ('FILE_SEARCH '+$filter+': '+$found.Count+' match(es)')
    foreach($file in $found) {
        $sha=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        Report ('  PATH: '+$file.FullName)
        Report ('  SHA256: '+$sha)
        Report ('  Modified: '+$file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        if($controller) {
            $raw=[System.IO.File]::ReadAllText($file.FullName,[System.Text.Encoding]::UTF8)
            foreach($marker in @(
                'BANK_STAGE_PARITY_STEP_V1',
                '6A/8 Verify Local and staging payment index compatibility',
                'BUSINESS_ONLY_STAGE: 4 device infrastructure tables',
                'CODE_SYNC_GATE_CHECK_ONLY',
                'LOCAL_FOUNDATION_READ_ONLY',
                '08D-CHECK-STAGE-PAYMENTS-INDEX-V1.sql',
                'Rewrite-CloudDumpForStage $cloudDump $stageDump'
            )) {
                Report ('  CONTROLLER_HAS ['+$marker+']: '+$raw.Contains($marker))
            }
        }
    }
}
function ReadOnlySQL([string]$title,[string]$sql) {
    Line
    Report ('QUERY: '+$title)
    # Session read-only, and SELECT only. No storage or payment writes.
    $query='BEGIN READ ONLY; '+$sql+' COMMIT;'
    try {
        $output=@(& docker exec $DbContainer psql -X -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -c $query 2>&1)
        $exit=$LASTEXITCODE
        foreach($item in $output) {
            $line=[string]$item
            if($line.Length -gt 1100){$line=$line.Substring(0,1100)+' [TRUNCATED]'}
            Report ('  '+$line)
        }
        if($exit -ne 0){Report ('  SQL_READONLY_EXIT_CODE: '+$exit)}
        else{Report '  SQL_READONLY_RESULT: SUCCESS'}
    }catch {
        Report ('  SQL_READONLY_ERROR: '+$_.Exception.Message)
    }
}
Report 'BIG BROTHER — LOCAL SYNC STAGING DIAGNOSTIC (READ ONLY)'
Report ('Captured on local PC: '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Report ('LocalBrainRoot: '+$LocalBrainRoot)
Report ('DB Container: '+$DbContainer)
Report 'This tool never runs Cloud sync, Code Sync, SQL DDL/DML or transactions.'
Line
Report 'SECTION 1: CONTROLLER FILES ACTUALLY PRESENT ON WINDOWS'
if(-not(Test-Path -LiteralPath $LocalBrainRoot -PathType Container)){
    Report 'LOCAL_ROOT_NOT_FOUND. Check configured LocalBrainRoot.'
}else{
    InspectScripts '08-SYNC-LIVE-TO-LOCAL-PERMANENT-V1.2.ps1' $true
    InspectScripts '08B-PREPARE-CLOUD-STAGE-V1.2.sql' $false
    InspectScripts '08C-MERGE-CLOUD-STAGE-PERMANENT-V1.2.sql' $false
    InspectScripts '08D-CHECK-STAGE-PAYMENTS-INDEX-V1.sql' $false
    InspectScripts 'V34-PRE-SYNC-SCHEMA-GUARD.ps1' $false
    InspectScripts 'V34-INSTALL-STAGE-PAYMENTS-PARITY-V2.ps1' $false
    $logs=@(SafeFiles '*CODE*SQL*MIGRATION*REPORT*.txt' | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach($file in $logs) {
        Report ('SQL_MIGRATION_REPORT_PATH: '+$file.FullName)
        Report ('  LastWrite: '+$file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        try{
            $hits=@(Select-String -LiteralPath $file.FullName -Pattern '20261025_payment_transaction_index_cloud_parity_v1','20261025_bank_partial_use_cloud_parity_v1' -SimpleMatch -ErrorAction Stop)
            foreach($hit in ($hits | Select-Object -Last 12)){
                $value=$hit.Line.Trim()
                if($value.Length -gt 350){$value=$value.Substring(0,350)+'...'}
                Report ('  MIGRATION_MATCH: '+$value)
            }
            if(!$hits.Count){Report '  MIGRATION_MATCH: none'}
        }catch {Report ('  MIGRATION_REPORT_READ_ERROR: '+$_.Exception.Message)}
    }
}
Line
Report 'SECTION 2: ACTUAL LOCAL POSTGRESQL — INDEXES, CODE SYNC, STAGING'
try{
    $docker=Get-Command docker -ErrorAction Stop
    Report ('docker located: '+$docker.Source)
    $containers=@(& docker ps --format '{{.Names}}' 2>&1)
    Report ('DB container RUNNING: '+(@($containers) -contains $DbContainer))
}catch {
    Report ('DOCKER_ERROR: '+$_.Exception.Message)
}
ReadOnlySQL 'Stage existence, and row counts for the reused reference' @'
SELECT 'public.payments rows with test reference' AS metric,
 count(*)::text AS value FROM public.payments
 WHERE lower(btrim(transaction_id))='179195231042684'
UNION ALL
SELECT 'Stage payments table exists', (to_regclass('bb_cloud_stage.payments') IS NOT NULL)::text;
'@
ReadOnlySQL 'All payment indexes in permanent LOCAL and isolated STAGE' @'
SELECT n.nspname||'.'||t.relname AS table_name,
       ix.relname AS index_name,
       'unique='||i.indisunique::text||'; primary='||i.indisprimary::text||
       '; valid='||i.indisvalid::text,
       pg_get_indexdef(i.indexrelid)
FROM pg_index i
JOIN pg_class t ON t.oid=i.indrelid
JOIN pg_namespace n ON n.oid=t.relnamespace
JOIN pg_class ix ON ix.oid=i.indexrelid
WHERE n.nspname IN ('public','bb_cloud_stage')
  AND t.relname='payments'
ORDER BY n.nspname,ix.relname;
'@
ReadOnlySQL 'Local bank partial-use function and migration prerequisites' @'
SELECT 'partial_use_guard_present',
       (to_regprocedure('private.bb_bank_guard_payment()') IS NOT NULL)::text
UNION ALL
SELECT 'allocation_ledger_present',
       (to_regclass('public.bb_bank_balance_allocations') IS NOT NULL)::text
UNION ALL
SELECT 'partial_use_guard_mentions_allocation',
       coalesce(
          position('bb_bank_balance_allocations' in
            pg_get_functiondef(to_regprocedure('private.bb_bank_guard_payment()'))) > 0,
          false)::text
UNION ALL
SELECT 'payment_index_migration_file_is_a_source_not_database_receipt',
       'confirm applied status from Code SQL Migration report';
'@
ReadOnlySQL 'Staging index owner — where payments_lower_idx actually lives' @'
SELECT n.nspname||'.'||idx.relname AS index_name,
       ns.nspname||'.'||t.relname AS on_table,
       i.indisunique::text AS is_unique,
       pg_get_indexdef(i.indexrelid) AS definition
FROM pg_index i
JOIN pg_class idx ON idx.oid=i.indexrelid
JOIN pg_namespace n ON n.oid=idx.relnamespace
JOIN pg_class t ON t.oid=i.indrelid
JOIN pg_namespace ns ON ns.oid=t.relnamespace
WHERE idx.relname LIKE 'payments_lower_idx%'
ORDER BY 1;
'@
Line
Report 'END — FILES, INDEXES AND SQL READ ONLY.'
$folder=Join-Path $LocalBrainRoot 'brain-backups\sync-diagnostics'
if(-not(Test-Path -LiteralPath $LocalBrainRoot -PathType Container)){
    $folder=Join-Path $env:TEMP 'BIG_BROTHER_SYNC_DIAGNOSTICS'
}
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$dest=Join-Path $folder ('LOCAL-STAGE-PAYMENT-DIAGNOSTIC-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt')
[System.IO.File]::WriteAllLines($dest,$lines.ToArray(),(New-Object System.Text.UTF8Encoding($true)))
Write-Host ''
Write-Host ('READ-ONLY DIAGNOSTIC SAVED: '+$dest) -ForegroundColor Green
Write-Host 'Upload this .txt report to ChatGPT; do not upload secrets, keys, .env or dump files.' -ForegroundColor Cyan
