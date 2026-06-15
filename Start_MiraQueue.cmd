@echo off
setlocal EnableExtensions
title MiraQueue

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%MiraQueue.ps1"

if not exist "%SCRIPT_PATH%" (
    echo MiraQueue.ps1 was not found next to this launcher.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
set "PS_EXIT=%ERRORLEVEL%"

if not "%PS_EXIT%"=="0" (
    echo.
    echo MiraQueue exited with error code %PS_EXIT%.
    echo.
    pause
)

exit /b %PS_EXIT%

