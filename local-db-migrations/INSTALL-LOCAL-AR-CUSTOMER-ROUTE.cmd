@echo off
setlocal
title BIG BROTHER Local A/R Customer Route INSTALL
echo.
echo ONLY LOCAL Docker Postgres will be changed, with a mandatory full backup.
echo No Cloud sync, stock edits, payment, A/R clearing or bank operations.
echo Do not install during Cloud-to-Local or Local-to-Cloud sync.
echo.
set /p confirm=Type APPLY to install Customer Route A/R permission correction: 
if /I not "%confirm%"=="APPLY" (
 echo Cancelled safely.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-LOCAL-AR-CUSTOMER-ROUTE-V1.ps1" -Apply
if errorlevel 1 (
 echo INSTALL STOPPED - preserve the error and avoid forcing SQL.
 pause
 exit /b 1
)
echo Local A/R Customer Location update installed. Refresh Local app.
pause
