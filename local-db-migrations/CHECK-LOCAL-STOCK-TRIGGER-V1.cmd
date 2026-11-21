@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CHECK-LOCAL-STOCK-TRIGGER-V1.ps1"
echo.
echo The report is saved in this folder. Nothing was changed in the database.
pause
