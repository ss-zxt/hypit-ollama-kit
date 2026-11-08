@echo off
chcp 65001 >nul
rem Double-click launcher for install.ps1.
rem Opens PowerShell with a one-off execution-policy bypass (nothing is
rem changed permanently), runs the installer from this folder, then
rem pauses so the result stays readable.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
echo 安装结束，退出码：%ERRORLEVEL%
pause
