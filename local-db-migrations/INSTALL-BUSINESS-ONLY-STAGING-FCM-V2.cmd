@echo off
setlocal
title BIG BROTHER V3.4 - Install Android Notification Sync Protection
echo.
echo BIG BROTHER Cloud to Local - FCM Business-Only Permanent Controller
echo This patches the ONE active V3.4 08 helper, with SHA guard and backup.
echo Do not run Cloud to Local until Code Sync installed FCM schema.
echo No invoice, salary, bank, or expense records are changed here.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0V34-INSTALL-BUSINESS-ONLY-STAGING-FCM-V2.ps1"
if errorlevel 1 (
  echo.
  echo STOPPED SAFELY. Review the error above, do not run Cloud to Local.
  pause
  exit /b 1
)
echo.
echo Active controller updated. Run the READ-ONLY diagnostic before Cloud to Local.
pause
