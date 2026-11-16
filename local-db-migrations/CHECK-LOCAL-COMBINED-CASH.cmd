@echo off
setlocal
title BIG BROTHER Local Brain - Combined Cash PRECHECK
echo Checking local Postgres dependencies only; no changes will be made.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-LOCAL-COMBINED-CASH-INSTALL-V1.ps1"
if errorlevel 1 (echo LOCAL PRECHECK FAILED - stopped safely.&pause&exit /b 1)
echo LOCAL PRECHECK PASSED.
pause
