@echo off
setlocal DisableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "ARGS=%*"
if "%ARGS%"=="" goto :interactive
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%installer.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
exit /b %EXIT_CODE%
:interactive
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%installer.ps1" -Interactive
set "EXIT_CODE=%ERRORLEVEL%"
if %EXIT_CODE% EQU 0 pause
exit /b %EXIT_CODE%
