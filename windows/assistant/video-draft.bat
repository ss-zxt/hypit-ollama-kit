@echo off
rem Local assistant launcher: give it a TikTok URL or a video file
rem (drag a video file onto this .bat, or double-click and paste a URL).
rem It downloads (for URLs), cuts frame grids, lets the local vision
rem model read them, and writes DRAFT_NOTES.md into the project folder.
setlocal
set "SRC=%~1"
if "%SRC%"=="" (
  echo Paste a TikTok URL, or a local video file path:
  set /p SRC="> "
)
if "%SRC%"=="" (
  echo Nothing entered. Exiting.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0video-draft.ps1" "%SRC%"
echo.
echo Assistant finished with exit code %ERRORLEVEL%.
pause
