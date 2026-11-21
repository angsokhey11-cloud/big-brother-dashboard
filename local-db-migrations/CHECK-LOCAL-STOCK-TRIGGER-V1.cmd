@echo off
setlocal
cd /d "%~dp0"
set "PS1=%~dp0CHECK-LOCAL-STOCK-TRIGGER-V1.ps1"
if not exist "%PS1%" (
  echo Fetching pinned read-only diagnostic script...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/angsokhey11-cloud/big-brother-dashboard/b40b37e1a8f56c09ff7ba18cc3af35957893afd9/local-db-migrations/CHECK-LOCAL-STOCK-TRIGGER-V1.ps1' -OutFile '%PS1%'"
  if errorlevel 1 (
    echo Download failed. Save CHECK-LOCAL-STOCK-TRIGGER-V1.ps1 beside this CMD file and retry.
    pause
    exit /b 1
  )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
echo The report is saved in this folder. Nothing was changed in the database.
pause
