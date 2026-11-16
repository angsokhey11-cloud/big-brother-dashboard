@echo off
setlocal
title BIG BROTHER Local Refund RPC Preflight
echo.
echo Local-only read-only refund RPC preflight. No database changes.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-LOCAL-REFUND-RPC-REPAIR-V1.ps1"
if errorlevel 1 (
 echo BLOCKED - share the error with ChatGPT. No changes made.
 pause
 exit /b 1
)
echo PASS - installer may be run after any active Local sync finishes.
pause
