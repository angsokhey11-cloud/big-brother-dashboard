# BIG BROTHER — AF-2L historical duplicate Local-only stock ledger repair
# 31-Oct-2026. LOCAL ONLY. NOT A V2 CODE SYNC OR CLOUD CHANGE.
# DEFAULT: Preview (READ ONLY). Apply requires explicit operator phrase.
# Tested ledger math in a separate no-network PostgreSQL 17.6 restore with rollback.
param([ValidateSet('Preview','Apply')][string]$Mode='Preview')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$container='supabase_db_Local_Brain'
$db='postgres'
$backup=Join-Path ([Environment]::GetFolderPath('Desktop')) 'BIG-BROTHER-LOCAL-BACKUP-20261031-175347.dump'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$archive=Join-Path ([Environment]::GetFolderPath('Desktop')) ("AUSFRESH-TWO-ORIGINAL-STOCK-ROWS-$stamp.csv")
$sqlFile=Join-Path $env:TEMP ("bb-af2l-local-correction-$stamp.sql")
$source='BATCH-INVOICE:LINE-1791033509925-ba44r4:AF-2L:PURCHASED'
$answer='REPAIR LOCAL AUSFRESH 11 UNITS'

function Check-Exit([string]$step) {
  if ($LASTEXITCODE -ne 0) { throw "$step failed. Stop; do not rerun automatically." }
}
function Query([string]$query) {
  $rows=@(docker exec $container psql -X -v ON_ERROR_STOP=1 -U postgres -d $db -tAc $query)
  Check-Exit 'Local read-only query'
  return ($rows -join '').Trim()
}
Write-Host "BIG BROTHER — $Mode — Local AF-2L stock preflight" -ForegroundColor Cyan
$containerCheck=Query("SELECT current_database();")
if($containerCheck -ne $db) { throw 'Unexpected Local database.' }
$activeContainer=(docker ps --format '{{.Names}}' | Where-Object {$_ -eq $container})
if(-not $activeContainer) { throw 'Expected Local Brain container not running.' }
if(-not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw "Backup missing: $backup" }
if((Get-Item -LiteralPath $backup).Length -lt 1000000) { throw 'Backup unexpectedly small.' }
Write-Host "Confirmed existing backup: $backup"

# Fail closed if anything changed since the known isolated test.
$count=Query('SELECT count(*) FROM public.stock_activity;')
if($count -ne '4247') { throw "Stock ledger count changed ($count). Stop; inspect current Local transactions." }
$matchSql=@"
SELECT count(*) FROM public.stock_activity
WHERE product_code='AF-2L' AND batch_id='BAT-000021'
 AND movement_type='BATCH_SALE' AND from_bucket='BATCH_PENDING'
 AND to_bucket='EXTERNAL' AND client_request_id='$source'
 AND ((transaction_id='TRX-000973' AND qty=6)
   OR (transaction_id='TRX-002412' AND qty=5));
"@
if((Query($matchSql)) -ne '2') { throw 'Two expected Local-only stock movements differ. Stop.' }
if((Query("SELECT count(*) FROM public.stock_activity WHERE client_request_id='$source'")) -ne '3') {
  throw 'Expected three movements linked to original source (6+5+6). Stop.'
}
$canonical=@"
SELECT count(*) FROM public.stock_activity
WHERE transaction_id='TRX-004408' AND product_code='AF-2L'
 AND batch_id='BAT-000021' AND qty=6 AND movement_type='BATCH_SALE'
 AND from_bucket='BATCH_PENDING' AND to_bucket='EXTERNAL'
 AND client_request_id='$source';
"@
if((Query($canonical)) -ne '1') { throw 'Canonical Cloud source deduction missing. Stop.' }
$invoice=@"
SELECT count(*) FROM public.invoice_lines il
JOIN public.invoices i ON i.invoice_id=il.invoice_id
WHERE il.line_id='LINE-1791033509925-ba44r4'
 AND il.product_code='AF-2L' AND il.qty=6
 AND i.invoice_no='INV-2346' AND i.batch_id='BAT-000021';
"@
if((Query($invoice)) -ne '1') { throw 'Original invoice does not match. Stop.' }
$beforeQty=Query("SELECT batch_pending FROM public.bb_stock_product_rows_zero_cost_v1_internal() WHERE product_code='AF-2L';")
$beforeCost=Query("SELECT average_cost FROM public.bb_stock_product_rows_zero_cost_v1_internal() WHERE product_code='AF-2L';")
$beforeProductValue=Query("SELECT total_value FROM public.bb_stock_product_rows_zero_cost_v1_internal() WHERE product_code='AF-2L';")
$beforeCompanyValue=Query("SELECT round(sum(total_value),2) FROM public.bb_stock_product_rows_zero_cost_v1_internal();")
# PowerShell 5.1-safe checks: never break an -or expression across lines.
if ([decimal]$beforeQty -ne [decimal]3860) {
  throw "Local AF-2L batch qty changed ($beforeQty). Stop."
}
if ([decimal]$beforeCost -ne [decimal]'3.988749') {
  throw "Local AF-2L average cost changed ($beforeCost). Stop."
}
if ([decimal]$beforeProductValue -ne [decimal]'18116.90') {
  throw "Local AF-2L inventory value changed ($beforeProductValue). Stop."
}
if ([decimal]$beforeCompanyValue -ne [decimal]'75346.90') {
  throw "Local company stock value changed ($beforeCompanyValue). Stop."
}
# Preserve complete row evidence OUTSIDE DB before any optional repair.
$csvSql="COPY (SELECT * FROM public.stock_activity WHERE transaction_id IN ('TRX-000973','TRX-002412') ORDER BY transaction_id) TO STDOUT WITH CSV HEADER;"
$archiveLines=@(docker exec $container psql -X -v ON_ERROR_STOP=1 -U postgres -d $db -c $csvSql)
Check-Exit 'Export complete original stock records'
[IO.File]::WriteAllLines($archive,[string[]]$archiveLines,[System.Text.UTF8Encoding]::new($false))
if((Get-Item -LiteralPath $archive).Length -lt 100) {throw 'Stock-row archive unexpectedly small. Stop.'}
Write-Host "Evidence archived: $archive" -ForegroundColor Green
Write-Host "BEFORE: 3860 Purchased Batch units; Ausfresh value 18116.90; company total 75346.90"
if($Mode -eq 'Preview') {
  Write-Host 'READ-ONLY PREVIEW PASSED. No stock records changed.' -ForegroundColor Green
  Write-Host 'Review the archive and obtain explicit accounting approval before Apply.'
  exit 0
}

Write-Host ''
Write-Host 'APPLY WILL PERMANENTLY REMOVE ONLY TRX-000973 (6) AND TRX-002412 (5) FROM THE LIVE LOCAL STOCK LEDGER.' -ForegroundColor Yellow
Write-Host 'Close other Local staff work/sales before proceeding. Cloud will NOT change.'
$confirm=Read-Host "Type EXACTLY: $answer"
if($confirm -cne $answer) { throw 'Cancelled. Live Local ledger unchanged.' }

# Locks + constraints + postcondition run in ONE transaction.
$sql=@'
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
LOCK TABLE public.stock_activity IN SHARE ROW EXCLUSIVE MODE;
DO $guard$
DECLARE n integer;
BEGIN
 IF (SELECT count(*) FROM public.stock_activity) <> 4247
 THEN RAISE EXCEPTION 'Stock ledger count changed'; END IF;
 SELECT count(*) INTO n FROM public.stock_activity
 WHERE product_code='AF-2L' AND batch_id='BAT-000021'
 AND movement_type='BATCH_SALE' AND from_bucket='BATCH_PENDING'
 AND to_bucket='EXTERNAL'
 AND client_request_id='BATCH-INVOICE:LINE-1791033509925-ba44r4:AF-2L:PURCHASED'
 AND ((transaction_id='TRX-000973' AND qty=6)
 OR (transaction_id='TRX-002412' AND qty=5));
 IF n <> 2 THEN RAISE EXCEPTION 'Candidate rows changed: %',n; END IF;
 IF (SELECT count(*) FROM public.stock_activity
 WHERE client_request_id='BATCH-INVOICE:LINE-1791033509925-ba44r4:AF-2L:PURCHASED') <> 3
 THEN RAISE EXCEPTION 'Original invoice-line source count changed'; END IF;
 IF NOT EXISTS(
 SELECT 1 FROM public.stock_activity
 WHERE transaction_id='TRX-004408' AND qty=6 AND product_code='AF-2L'
 AND batch_id='BAT-000021' AND movement_type='BATCH_SALE'
 AND from_bucket='BATCH_PENDING' AND to_bucket='EXTERNAL'
 AND client_request_id='BATCH-INVOICE:LINE-1791033509925-ba44r4:AF-2L:PURCHASED')
 THEN RAISE EXCEPTION 'Canonical source movement missing'; END IF;
 IF (SELECT batch_pending FROM public.bb_stock_product_rows_zero_cost_v1_internal()
  WHERE product_code='AF-2L') <> 3860
 OR (SELECT total_value FROM public.bb_stock_product_rows_zero_cost_v1_internal()
  WHERE product_code='AF-2L') <> 18116.90
 OR (SELECT round(sum(total_value),2) FROM public.bb_stock_product_rows_zero_cost_v1_internal()) <> 75346.90
 THEN RAISE EXCEPTION 'Local baseline changed'; END IF;
END $guard$;

DELETE FROM public.stock_activity
WHERE product_code='AF-2L' AND batch_id='BAT-000021'
 AND movement_type='BATCH_SALE' AND from_bucket='BATCH_PENDING'
 AND to_bucket='EXTERNAL'
 AND client_request_id='BATCH-INVOICE:LINE-1791033509925-ba44r4:AF-2L:PURCHASED'
 AND ((transaction_id='TRX-000973' AND qty=6)
 OR (transaction_id='TRX-002412' AND qty=5));

DO $verify$
DECLARE q numeric; v numeric; a numeric; t numeric;
BEGIN
 SELECT batch_pending,average_cost,total_value INTO q,a,v
 FROM public.bb_stock_product_rows_zero_cost_v1_internal()
 WHERE product_code='AF-2L';
 SELECT round(sum(total_value),2) INTO t
 FROM public.bb_stock_product_rows_zero_cost_v1_internal();
 IF (SELECT count(*) FROM public.stock_activity) <> 4245
 OR q <> 3871 OR a <> 3.988650 OR v <> 18160.32 OR t <> 75390.32
 OR (SELECT count(*) FROM public.stock_activity WHERE transaction_id IN ('TRX-000973','TRX-002412')) <> 0
 THEN RAISE EXCEPTION 'POSTCHECK FAILED; transaction automatically rolls back (qty %, avg %, product %, company %)',q,a,v,t;
 END IF;
 RAISE NOTICE 'VERIFIED: Ausfresh batch %, avg %, AF-2L stock %, company stock %',q,a,v,t;
END $verify$;
COMMIT;
'@
[IO.File]::WriteAllText($sqlFile,$sql,[System.Text.UTF8Encoding]::new($false))
docker cp $sqlFile "$($container):/tmp/bb-af2l-guarded-repair.sql" | Out-Null
Check-Exit 'Copy audited repair SQL'
docker exec $container psql -X -v ON_ERROR_STOP=1 -P pager=off -U supabase_admin -d $db -f /tmp/bb-af2l-guarded-repair.sql
Check-Exit 'Guarded Local-only repair'
$now=Query("SELECT round(sum(total_value),2) FROM public.bb_stock_product_rows_zero_cost_v1_internal();")
if($now -ne '75390.32') { throw "Post-commit company valuation differs: $now. Investigate immediately." }
Write-Host "LOCAL-ONLY RECONCILIATION COMMITTED. Company inventory now USD $now." -ForegroundColor Green
Write-Host "Keep backup and evidence CSV permanently; do not rerun the repair." -ForegroundColor Yellow
