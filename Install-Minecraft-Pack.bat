@echo off
setlocal
cd /d "%~dp0"

echo ========================================================================
echo Updating installer from GitHub
echo ========================================================================
git pull --ff-only

if "%*"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Minecraft-Pack.ps1" -Client -NoPrompt
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Minecraft-Pack.ps1" %*
)
set EXITCODE=%ERRORLEVEL%

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
