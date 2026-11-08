@echo off
chcp 65001 >nul
rem Local assistant launcher: give it a TikTok URL or a video file
rem (drag a video file onto this .bat, or double-click and paste a URL).
rem It downloads (for URLs), cuts frame grids, lets the local vision
rem model read them, and writes DRAFT_NOTES.md into the project folder.
setlocal
rem Data location for this run (downloads + projects): default to
rem D:\HypitData when a D: drive exists, so the double-click flow does
rem not depend on the HYPIT_DATA_DIR environment variable having
rem propagated to Explorer (a running Explorer serves stale env to
rem double-clicked .bat files - field finding 2026-11-08). An env var
rem you set yourself always wins; edit the path below to change it.
if not defined HYPIT_DATA_DIR if exist D:\ set "HYPIT_DATA_DIR=D:\HypitData"
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
