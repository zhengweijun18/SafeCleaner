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
set "EXE_NAME="

if not exist "%SOURCE%\" (
  echo.
  echo 错误：未找到构建输出目录：
  echo %SOURCE%
  pause
  exit /b 1
)

if exist "%SOURCE%\SafeMacCleanerLite.exe" set "EXE_NAME=SafeMacCleanerLite.exe"
if not defined EXE_NAME (
  for /f "delims=" %%F in ('dir /b /a-d "%SOURCE%\*.exe" 2^>nul') do if not defined EXE_NAME set "EXE_NAME=%%F"
)

if not defined EXE_NAME (
  echo.
  echo 错误：构建输出中没有找到 Windows 可执行文件。
  echo 请查看上方 dotnet publish 的具体错误信息。
  pause
  exit /b 1
)

echo.
echo 安装到：
echo %TARGET%
echo 可执行文件：%EXE_NAME%
echo.

if exist "%TARGET%" rmdir /s /q "%TARGET%"
mkdir "%TARGET%"
xcopy "%SOURCE%\*" "%TARGET%\" /E /I /Y >nul
if errorlevel 1 (
  echo.
  echo 错误：复制程序文件失败。
  pause
  exit /b 1
)

if not exist "%TARGET%\%EXE_NAME%" (
  echo.
  echo 错误：安装后未找到可执行文件：
  echo %TARGET%\%EXE_NAME%
  echo 如果刚刚被 Windows 安全中心隔离，请检查“保护历史记录”。
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ws=New-Object -ComObject WScript.Shell;" ^
 "$s=$ws.CreateShortcut([Environment]::GetFolderPath('StartMenu') + '\Programs\SafeMac Cleaner Lite.lnk');" ^
 "$s.TargetPath='%TARGET%\%EXE_NAME%';" ^
 "$s.WorkingDirectory='%TARGET%';" ^
 "$s.Save()"

start "" "%TARGET%\%EXE_NAME%"
if errorlevel 1 (
  echo.
  echo 错误：程序启动失败：%TARGET%\%EXE_NAME%
  pause
  exit /b 1
)

echo.
echo 安装完成，已启动 SafeMac Cleaner Lite。
pause
