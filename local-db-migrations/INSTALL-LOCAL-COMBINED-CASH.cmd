@echo off
setlocal
title BIG BROTHER Local Brain - Combined Cash INSTALL
echo.
echo Only LOCAL Docker PostgreSQL will be changed. Full backup is mandatory.
echo Stop if Cloud/Local sync is running or local data has not been backed up.
echo.
set /p confirm=Type APPLY to install local combined Cash + A/R functions: 
if /I not "%confirm%"=="APPLY" (echo Cancelled safely.&pause&exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-LOCAL-COMBINED-CASH-INSTALL-V1.ps1" -Apply
if errorlevel 1 (echo LOCAL INSTALL FAILED - see error, no Cloud changes.&pause&exit /b 1)
echo LOCAL SQL INSTALL COMPLETED. Test UI after Code Sync.
pause
