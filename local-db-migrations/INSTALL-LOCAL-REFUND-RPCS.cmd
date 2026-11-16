@echo off
setlocal
title BIG BROTHER Local Refund RPC Repair
echo.
echo Repairs ONLY the Local Brain missing Salesman Refund RPC functions.
echo Makes a full LOCAL DB backup first. Does not change business data or cloud.
echo Ensure Cloud-to-Local and Local-to-Cloud sync are not running.
echo.
set /p confirm=Type APPLY to install local refund RPCs: 
if /I not "%confirm%"=="APPLY" (
 echo Cancelled - no changes made.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-LOCAL-REFUND-RPC-REPAIR-V1.ps1" -Apply
if errorlevel 1 (
 echo STOPPED - see error above. Do not retry blindly.
 pause
 exit /b 1
)
echo Local refund RPC installation finished. Refresh Local Daily Cash Collection.
pause
