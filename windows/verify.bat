@echo off
chcp 65001 >nul
rem Double-click launcher for verify.ps1 (11 checks + inference smoke).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify.ps1" %*
echo.
echo 验证结束，退出码：%ERRORLEVEL%
pause
