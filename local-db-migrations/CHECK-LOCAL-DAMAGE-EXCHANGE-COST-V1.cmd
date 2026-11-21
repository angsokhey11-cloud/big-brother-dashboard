@echo off
setlocal
cd /d "%~dp0"
set "PS1=%~dp0CHECK-LOCAL-DAMAGE-EXCHANGE-COST-V1.ps1"
if not exist "%PS1%" (
  echo Retrieving pinned, read-only Local Brain diagnostic...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/angsokhey11-cloud/big-brother-dashboard/c1ee041a9d17ec2bbfa0986d5803066f870162e0/local-db-migrations/CHECK-LOCAL-DAMAGE-EXCHANGE-COST-V1.ps1' -OutFile '%PS1%'"
  if errorlevel 1 (
    echo Cannot retrieve diagnostic. Save CHECK-LOCAL-DAMAGE-EXCHANGE-COST-V1.ps1 beside this file and retry.
    pause
    exit /b 1
  )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
echo The LOCAL-DAMAGE-EXCHANGE-CHECK report is saved beside this CMD file.
echo No stock, invoices, costs, or migrations were modified.
pause
