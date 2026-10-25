@echo off
setlocal
title BIG BROTHER - Code Sync Business-only Stage Payment Compatibility V2
echo.
echo BIG BROTHER - Cloud to Local Stage Payment Compatibility V2
echo This step installs approved controller files from Code Sync.
echo It DOES NOT execute SQL, sync business records, or change Cloud.
echo Run Code Sync first and verify both payment-related migrations.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-INSTALL-STAGE-PAYMENTS-PARITY-V2.ps1"
if errorlevel 1 (
  echo.
  echo INSTALLATION BLOCKED - review the precise error above. No Cloud data merged.
  pause
  exit /b 1
)
echo.
echo Controller stage-payment parity installed/verified. Run a FRESH Cloud to Local sync.
pause
