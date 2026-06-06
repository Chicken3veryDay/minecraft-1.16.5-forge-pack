@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================================================
echo Updating installer from GitHub
echo ========================================================================
where git >nul 2>nul
if errorlevel 1 (
  echo [WARN] Git was not found in PATH; skipping git pull.
) else (
  git pull --ff-only
  if errorlevel 1 (
    echo [WARN] Git pull failed; continuing with local installer files.
  )
)

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Minecraft-Pack.ps1" -Client -NoPrompt -SkipSelfUpdate
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Minecraft-Pack.ps1" %* -SkipSelfUpdate
)
set "EXITCODE=%ERRORLEVEL%"

echo.
echo ========================================================================
if "%EXITCODE%"=="0" (
  echo Installer finished successfully.
) else (
  echo Installer failed with exit code %EXITCODE%.
)
echo ========================================================================
echo Review the summary above, then press any key to close this window.
pause >nul

exit /b %EXITCODE%
