@echo off
setlocal
title BIG BROTHER V3.4 - Fix Approved SQL Check Only Gate
echo.
echo BIG BROTHER - Approved SQL preflight status compatibility fix
echo This checks the exact active gate SHA, takes a backup and changes status validation only.
echo It makes no PostgreSQL schema changes and does not run Cloud to Local.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-INSTALL-APPROVED-SQL-GATE-CHECKONLY-V2.ps1"
if errorlevel 1 (
 echo.
 echo STOPPED SAFELY - no full Cloud to Local sync yet.
 pause
 exit /b 1
)
echo.
echo Gate repair installed. Use the Control Center's PREFLIGHT ONLY check next.
pause
