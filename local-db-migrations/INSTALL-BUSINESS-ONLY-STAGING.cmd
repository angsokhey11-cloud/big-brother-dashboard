@echo off
setlocal
title BIG BROTHER - Business Only Cloud-to-Local Controller Update
echo.
echo BIG BROTHER - V3.4 One-Time Business-Only Sync Controller Update
echo This step does NOT run SQL, sync Cloud data, or restart Local Brain.
echo Run normal Code Sync successfully before using this installer.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-INSTALL-BUSINESS-ONLY-STAGING-V1.ps1"
if errorlevel 1 (
  echo.
  echo UPDATE BLOCKED - original controller was not changed. Review the error above.
  pause
  exit /b 1
)
echo.
echo Controller file updated or already current. No database records changed.
pause
