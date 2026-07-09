@echo off
setlocal

pushd "%~dp0" >nul || (
    echo ERROR: Could not open the project folder.
    echo.
    pause
    exit /b 1
)

echo Building Sports Panel installer...
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found.
    set "EXITCODE=1"
    goto done
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-installer.ps1"
set "EXITCODE=%ERRORLEVEL%"
echo.

if "%EXITCODE%"=="0" (
    echo Build finished successfully.
    echo Installer:
    echo "%~dp0artifacts\installer\SportsPanelSetup.exe"
) else (
    echo Build failed with exit code %EXITCODE%.
)

:done
echo.
pause
popd >nul
exit /b %EXITCODE%
