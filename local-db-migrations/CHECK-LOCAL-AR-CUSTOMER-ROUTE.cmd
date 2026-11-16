@echo off
setlocal
title BIG BROTHER Local A/R Customer Route PRECHECK
echo.
echo Check ONLY local database compatibility for Customer Location A/R collections.
echo No cash, invoices, permissions, customer locations, or Cloud records changed.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-LOCAL-AR-CUSTOMER-ROUTE-V1.ps1"
if errorlevel 1 (
 echo PRECHECK BLOCKED - capture the error and stop.
 pause
 exit /b 1
)
echo PRECHECK PASSED.
pause
