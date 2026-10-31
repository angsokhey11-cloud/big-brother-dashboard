# BIG BROTHER — Identify Local V5 / V6 PostgreSQL containers safely
# READ-ONLY. This script runs no SQL, no backups, no container modifications,
# no network calls and never reads container environment variables/passwords.
$ErrorActionPreference = 'Stop'
Write-Host 'BIG BROTHER — LOCAL DB PRECHECK (READ ONLY)' -ForegroundColor Cyan

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host 'Docker CLI not found. Start Docker Desktop or add Docker to PATH.' -ForegroundColor Yellow
  exit 1
}

try {
  $version = docker version --format '{{.Server.Version}}' 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Docker daemon not responding.' }
  Write-Host "Docker server: $version"
} catch {
  Write-Host 'Docker Desktop is not running or cannot be reached.' -ForegroundColor Yellow
  exit 1
}

Write-Host ''
Write-Host 'Existing containers (running and stopped):' -ForegroundColor Cyan
# Names / images / status / ports only; no secrets, logs, mounts or credentials.
docker ps -a --format 'table {{.Names}}	{{.Image}}	{{.Status}}	{{.Ports}}'
if ($LASTEXITCODE -ne 0) { throw 'Cannot list Docker containers.' }

Write-Host ''
Write-Host 'PostgreSQL container candidates:' -ForegroundColor Cyan
$containers = @(docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}')
$candidates = @($containers | Where-Object { $_ -match '(?i)(postgres|postgis|supabase-db)' })
if ($candidates.Count) {
  $candidates | ForEach-Object { Write-Host "  $_" }
} else {
  Write-Host '  None identified by name/image; do not guess container names.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Local postgres:16 image availability:' -ForegroundColor Cyan
docker image inspect postgres:16 --format '{{.Id}}' *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Host '  Available locally.'
} else {
  Write-Host '  Not present locally. Isolated test runner must not pull an image without review.'
}
Write-Host ''
Write-Host 'SAFE: Read-only check complete. No database or container was changed.' -ForegroundColor Green
Write-Host 'Share a screenshot of the container list, but do not share passwords, tokens or .env files.'
