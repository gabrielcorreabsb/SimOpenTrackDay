@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "SCRIPT_DIR=%~dp0"

echo.
echo ============================================================
echo  SimOpenTrackDay installer
echo ============================================================
echo.
echo This will copy the SimOpenTrackDay addon into:
echo   ^<Assetto Corsa install^>\apps\lua\SimOpenTrackDay\
echo The existing folder will be wiped first.
echo.

set "AC_ROOT="
:ask_path
set "INPUT="
set /p "INPUT=Path to your Assetto Corsa install (e.g. D:\Steam\steamapps\common\assettocorsa): "
if "%INPUT%"=="" goto :ask_path
if "%INPUT:~-1%"=="\" set "INPUT=%INPUT:~0,-1%"
set "AC_ROOT=%INPUT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%AC_ROOT%'; if (-not (Test-Path -LiteralPath $p -PathType Container)) { Write-Host ('Folder not found: ' + $p); exit 2 }; $apps=Join-Path $p 'apps\lua'; if (-not (Test-Path -LiteralPath $apps -PathType Container)) { Write-Host ('Missing apps\lua under: ' + $p); exit 3 }; exit 0"
if errorlevel 1 goto :ask_path

echo.
echo Target: %AC_ROOT%\apps\lua\SimOpenTrackDay\
echo.
set "CONFIRM="
set /p "CONFIRM=Type YES to continue (anything else aborts): "
if /I not "%CONFIRM%"=="YES" (
    echo Aborted.
    exit /b 1
)

echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%installer.ps1" -AssettoCorsaRoot "%AC_ROOT%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if %EXIT_CODE% NEQ 0 (
    echo Install failed. See the log printed above or check:
    echo   %LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs\
) else (
    echo Install finished.
)
echo.
pause
exit /b %EXIT_CODE%