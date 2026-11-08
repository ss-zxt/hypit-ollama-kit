@echo off
rem Graphical launcher for the local assistant (video-draft-gui.ps1).
rem Pure ASCII + CRLF on purpose: cmd.exe misparses non-ASCII batch
rem files. The window itself is Chinese (rendered by PowerShell).
setlocal
rem Same data-location default as video-draft.bat (D:\HypitData when a
rem D: drive exists, unless HYPIT_DATA_DIR is already set).
if not defined HYPIT_DATA_DIR if exist D:\ set "HYPIT_DATA_DIR=D:\HypitData"
rem Refresh the kit-root shortcut (a working .lnk can only be made
rem on this machine - see create-shortcut.ps1). Silent on purpose.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-shortcut.ps1" >nul 2>&1
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0video-draft-gui.ps1" %*
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo The assistant window exited with code %ERRORLEVEL%.
  pause
)
