@echo off
rem Double-click launcher for verify.ps1 (11 checks + inference smoke).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify.ps1" %*
echo.
echo Verify finished with exit code %ERRORLEVEL%.
pause
