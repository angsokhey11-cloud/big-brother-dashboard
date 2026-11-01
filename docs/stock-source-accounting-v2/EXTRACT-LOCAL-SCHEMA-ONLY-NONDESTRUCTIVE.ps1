# BIG BROTHER: read-only schema-only snapshot from a PREVIOUSLY CAPTURED .dump.
# No contact with real Local V5/V6, Supabase Cloud, or external network.
# Uses a temporary no-network Docker container and pg_restore --schema-only.
# Does not include customer/invoice/bank/salary DATA ROWS, but function bodies
# may contain hardcoded config/secrets: inspect output before sharing.
param(
  [string]$BackupFile="$env:USERPROFILE\Desktop\BB-STOCK-SOURCE-V2-STEP1\LOCAL-V2-READONLY-SNAPSHOT-20261101-112831.dump",
  [string]$OutputFile="$env:USERPROFILE\Desktop\BIG-BROTHER-LOCAL-SCHEMA-ONLY.sql"
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$image='public.ecr.aws/supabase/postgres:17.6.1.166'
$name='bb-v2-schema-export-'+(Get-Date -Format 'yyyyMMddHHmmss')
$started=$false
function Assert-Exit([string]$step) {
  if($LASTEXITCODE -ne 0){throw "$step failed (exit code $LASTEXITCODE). No live database access performed."}
}
if(-not(Test-Path -LiteralPath $BackupFile -PathType Leaf)){throw "Snapshot missing: $BackupFile"}
if([IO.Path]::GetExtension($BackupFile).ToLowerInvariant() -ne '.dump'){throw 'Only previous custom-format .dump snapshot accepted.'}
if((Get-Item -LiteralPath $BackupFile).Length -lt 1000000){throw 'Snapshot unexpectedly small.'}
if(-not(Get-Command docker -ErrorAction SilentlyContinue)){throw 'Docker Desktop not found.'}
docker image inspect $image *> $null
Assert-Exit 'Inspect locally available Supabase PostgreSQL 17 image'
if(Test-Path -LiteralPath $OutputFile){throw "Output file already exists. Refusing overwrite: $OutputFile"}
try {
  Write-Host 'Creating temporary NO-NETWORK schema export container only.' -ForegroundColor Cyan
  docker run -d --rm --network none --name $name --entrypoint sleep $image 600 | Out-Null
  Assert-Exit 'Start isolated schema exporter'
  $started=$true
  $source=$name+':/tmp/source.dump'
  docker cp $BackupFile $source | Out-Null
  Assert-Exit 'Copy existing backup into isolated exporter'
  docker exec $name pg_restore --list /tmp/source.dump | Out-Null
  Assert-Exit 'Verify existing backup archive'
  docker exec $name pg_restore --schema-only --no-owner -f /tmp/schema-only.sql /tmp/source.dump
  Assert-Exit 'Extract schema-only SQL'
  $copySource=$name+':/tmp/schema-only.sql'
  docker cp $copySource $OutputFile | Out-Null
  Assert-Exit 'Copy schema-only SQL to Desktop'
  if(-not(Test-Path -LiteralPath $OutputFile -PathType Leaf)){throw 'Exported file not found.'}
  $bytes=(Get-Item -LiteralPath $OutputFile).Length
  if($bytes -lt 50000){throw 'Schema file suspiciously small. Inspect the output before using.'}
  $sha=(Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash
  Write-Host "SCHEMA-ONLY EXPORT SUCCESS: $bytes bytes" -ForegroundColor Green
  Write-Host "Output: $OutputFile"
  Write-Host "SHA256: $sha"
  Write-Host 'Contains DDL only; does NOT contain production business table data.' -ForegroundColor Green
  Write-Host 'REVIEW FOR HARDCODED SECRETS before uploading or committing. Do not publish automatically.' -ForegroundColor Yellow
}
finally {
  if($started){
    Write-Host 'Removing only temporary schema-export container.' -ForegroundColor Cyan
    docker rm -f $name | Out-Null
  }
}
