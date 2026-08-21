@echo off
chcp 65001 >nul
setlocal

cd /d "%~dp0"

echo ================================================
echo   SafeMac Cleaner Lite v4.14 - Windows 安装
echo ================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_windows.ps1" -Architecture auto
if errorlevel 1 (
  echo.
  echo 构建失败，请查看上面的提示。
  pause
  exit /b 1
)

if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
  set "RID=win-arm64"
) else (
  set "RID=win-x64"
)

set "SOURCE=%~dp0dist\%RID%"
set "TARGET=%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite"

echo.
echo 安装到：
echo %TARGET%
echo.

if exist "%TARGET%" rmdir /s /q "%TARGET%"
mkdir "%TARGET%"
xcopy "%SOURCE%\*" "%TARGET%\" /E /I /Y >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ws=New-Object -ComObject WScript.Shell;" ^
 "$s=$ws.CreateShortcut([Environment]::GetFolderPath('StartMenu') + '\Programs\SafeMac Cleaner Lite.lnk');" ^
 "$s.TargetPath='%TARGET%\SafeMacCleanerLite.exe';" ^
 "$s.WorkingDirectory='%TARGET%';" ^
 "$s.Save()"

start "" "%TARGET%\SafeMacCleanerLite.exe"

echo.
echo 安装完成，已启动 SafeMac Cleaner Lite。
pause
