@echo off
setlocal EnableExtensions DisableDelayedExpansion

if /I "%~1"=="--inner" goto :inner
start "SafeMac Cleaner Lite Installer" "%ComSpec%" /d /k ""%~f0" --inner"
exit /b

:inner
shift
cd /d "%~dp0"
title SafeMac Cleaner Lite Installer

echo ================================================
echo   SafeMac Cleaner Lite v4.14 - Windows Installer
echo ================================================
echo.

set "TARGET=%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite"
set "BUNDLED_EXE=%~dp0SafeMacCleanerLite.exe"

if not exist "%BUNDLED_EXE%" (
  echo ERROR: SafeMacCleanerLite.exe was not found next to this installer.
  echo.
  echo Current folder:
  echo %~dp0
  echo.
  echo This usually means one of these happened:
  echo   1. The CMD file was run directly from inside the ZIP.
  echo   2. An older Windows package is still being used.
  echo.
  echo Fix:
  echo   - Delete the old ZIP and old extracted folder.
  echo   - Download the latest Windows x64 or ARM64 ZIP.
  echo   - Right-click the ZIP and choose Extract All.
  echo   - Open the extracted folder, then run this CMD again.
  echo.
  echo The extracted folder must contain BOTH:
  echo   SafeMacCleanerLite.exe
  echo   this installer CMD
  echo.
  pause
  exit /b 2
)

echo Prebuilt executable found.
echo Installing to:
echo %TARGET%
echo.

if exist "%TARGET%" rmdir /s /q "%TARGET%"
mkdir "%TARGET%"
if errorlevel 1 (
  echo ERROR: Failed to create install directory.
  pause
  exit /b 3
)

copy /Y "%BUNDLED_EXE%" "%TARGET%\SafeMacCleanerLite.exe" >nul
if errorlevel 1 (
  echo ERROR: Failed to copy SafeMacCleanerLite.exe.
  pause
  exit /b 4
)

if not exist "%TARGET%\SafeMacCleanerLite.exe" (
  echo ERROR: The installed executable is missing.
  echo Check Windows Security - Protection history in case the file was quarantined.
  pause
  exit /b 5
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ws=New-Object -ComObject WScript.Shell;" ^
 "$s=$ws.CreateShortcut([Environment]::GetFolderPath('StartMenu') + '\Programs\SafeMac Cleaner Lite.lnk');" ^
 "$s.TargetPath='%TARGET%\SafeMacCleanerLite.exe';" ^
 "$s.WorkingDirectory='%TARGET%';" ^
 "$s.Save()"

if errorlevel 1 (
  echo WARNING: Start Menu shortcut could not be created, but the app is installed.
)

echo.
echo Starting SafeMac Cleaner Lite...
start "" "%TARGET%\SafeMacCleanerLite.exe"

echo.
echo Installation completed.
echo This window will stay open so any startup error remains visible.
echo You can close it after the application opens normally.
exit /b 0
