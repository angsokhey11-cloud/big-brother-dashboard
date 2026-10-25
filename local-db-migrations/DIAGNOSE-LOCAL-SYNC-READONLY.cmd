@echo off
setlocal
title BIG BROTHER - Local Brain Read-Only Sync Diagnostic
echo.
echo BIG BROTHER - READ-ONLY LOCAL SYNC DIAGNOSTIC
echo This checks actual Windows controller files and Local payment indexes.
echo It does NOT run Code Sync, Cloud-to-Local, or SQL changes.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-READONLY-LOCAL-SYNC-DIAGNOSTIC-V1.ps1"
if errorlevel 1 (
  echo.
  echo Diagnostic could not complete. Report the error shown above.
  pause
  exit /b 1
)
echo.
echo The report path is printed above. Upload the report TXT to ChatGPT.
echo Do not upload any key, .env file, backups, or dump content.
pause
