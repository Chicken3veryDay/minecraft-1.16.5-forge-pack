@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================================================
echo Updating Crazy Craft client QoL handshake fix from GitHub
echo ========================================================================
where git >nul 2>nul
if errorlevel 1 (
  echo [WARN] Git was not found in PATH; skipping git pull.
) else (
  git pull --ff-only
  if errorlevel 1 echo [WARN] Git pull failed; continuing with local files.
)

echo.
echo ========================================================================
echo Applying required client QoL/server handshake jars
echo ========================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Apply-CrazyCraftClientQol.ps1" -Force
set "EXITCODE=%ERRORLEVEL%"

echo.
echo ========================================================================
if "%EXITCODE%"=="0" (
  echo Client QoL handshake fix finished successfully.
) else (
  echo Client QoL handshake fix failed with exit code %EXITCODE%.
)
echo ========================================================================
echo Launch the 'Crazy Craft 4.0 Official' profile and join the server.
echo Press any key to close this window.
pause >nul
exit /b %EXITCODE%
