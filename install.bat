@echo off
setlocal enabledelayedexpansion

:: ==============================================================================
:: DEV SEC IT - Universal Multi-Platform Installer (Windows Launcher)
:: Detects Windows OS and launches native Windows Setup Wizard.
:: ==============================================================================

title DevSecIt Installer

echo ==============================================================================
echo        DEV SEC IT - UNIVERSAL MULTI-PLATFORM INSTALLER
echo ==============================================================================
echo.
echo [*] Operating System: Microsoft Windows [Version %OS%]
echo [*] Platform: Windows NT (%PROCESSOR_ARCHITECTURE%)
echo.

set "SCRIPT_DIR=%~dp0"
set "WIN_INSTALLER="

if exist "%SCRIPT_DIR%windows\windows.exe" (
    set "WIN_INSTALLER=%SCRIPT_DIR%windows\windows.exe"
) else if exist "%SCRIPT_DIR%windows.exe" (
    set "WIN_INSTALLER=%SCRIPT_DIR%windows.exe"
) else if exist "%SCRIPT_DIR%windows\setup.exe" (
    set "WIN_INSTALLER=%SCRIPT_DIR%windows\setup.exe"
)

if defined WIN_INSTALLER (
    echo [+] Found Windows Installation Wizard:
    echo     !WIN_INSTALLER!
    echo.
    echo [*] Launching Setup Wizard...
    start "" "!WIN_INSTALLER!"
    echo [+] Windows Setup launched successfully.
    echo.
) else (
    echo [ERROR] Windows setup executable was not found in:
    echo         %SCRIPT_DIR%windows\windows.exe
    echo.
    pause
    exit /b 1
)

endlocal

