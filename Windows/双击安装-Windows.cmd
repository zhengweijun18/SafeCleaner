@echo off
setlocal EnableExtensions

if /I not "%~1"=="--inner" (
  start "SafeMac Cleaner Lite Installer" "%ComSpec%" /k ""%~f0" --inner"
  exit /b
)

shift
chcp 65001 >nul
cd /d "%~dp0"

echo ================================================
echo   SafeMac Cleaner Lite v4.14 - Windows 安装
echo ================================================
echo.

set "TARGET=%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite"
set "SOURCE_EXE="
set "BUNDLED_EXE=%~dp0SafeMacCleanerLite.exe"

if exist "%BUNDLED_EXE%" (
  echo 检测到预编译版本，直接安装，无需 .NET SDK。
  set "SOURCE_EXE=%BUNDLED_EXE%"
) else (
  echo 未检测到预编译 EXE，将从源码构建。
  echo.

  if not exist "%~dp0publish_windows.ps1" (
    echo 错误：当前压缩包缺少 SafeMacCleanerLite.exe 和 publish_windows.ps1。
    echo 请重新下载对应架构的 Windows 预编译 ZIP，并先完整解压。
    goto :fail
  )

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_windows.ps1" -Architecture auto
  if errorlevel 1 (
    echo.
    echo 错误：Windows 构建失败，请查看上面的具体错误。
    goto :fail
  )

  set "ARCH=%PROCESSOR_ARCHITECTURE%"
  if defined PROCESSOR_ARCHITEW6432 set "ARCH=%PROCESSOR_ARCHITEW6432%"

  if /I "%ARCH%"=="ARM64" (
    set "RID=win-arm64"
  ) else (
    set "RID=win-x64"
  )

  set "SOURCE=%~dp0dist\%RID%"
  if exist "%SOURCE%\SafeMacCleanerLite.exe" set "SOURCE_EXE=%SOURCE%\SafeMacCleanerLite.exe"

  if not defined SOURCE_EXE (
    for /f "delims=" %%F in ('dir /b /a-d "%SOURCE%\*.exe" 2^>nul') do if not defined SOURCE_EXE set "SOURCE_EXE=%SOURCE%\%%F"
  )
)

if not defined SOURCE_EXE (
  echo 错误：没有找到可安装的 Windows 可执行文件。
  goto :fail
)

if not exist "%SOURCE_EXE%" (
  echo 错误：可执行文件路径不存在：
  echo %SOURCE_EXE%
  goto :fail
)

echo.
echo 安装到：
echo %TARGET%
echo.

if exist "%TARGET%" rmdir /s /q "%TARGET%"
mkdir "%TARGET%"
if errorlevel 1 (
  echo 错误：无法创建安装目录。
  goto :fail
)

copy /Y "%SOURCE_EXE%" "%TARGET%\SafeMacCleanerLite.exe" >nul
if errorlevel 1 (
  echo 错误：复制程序文件失败。
  goto :fail
)

if not exist "%TARGET%\SafeMacCleanerLite.exe" (
  echo 错误：安装后未找到 SafeMacCleanerLite.exe。
  echo 如果 Windows 安全中心刚刚隔离了程序，请检查“保护历史记录”。
  goto :fail
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ws=New-Object -ComObject WScript.Shell;" ^
 "$s=$ws.CreateShortcut([Environment]::GetFolderPath('StartMenu') + '\Programs\SafeMac Cleaner Lite.lnk');" ^
 "$s.TargetPath='%TARGET%\SafeMacCleanerLite.exe';" ^
 "$s.WorkingDirectory='%TARGET%';" ^
 "$s.Save()"

if errorlevel 1 (
  echo 警告：开始菜单快捷方式创建失败，但程序已经安装。
)

echo.
echo 正在启动 SafeMac Cleaner Lite...
start "" "%TARGET%\SafeMacCleanerLite.exe"

echo.
echo 安装完成。
echo 为了便于排查问题，此窗口会保持打开；确认程序正常启动后可直接关闭本窗口。
exit /b 0

:fail
echo.
echo 安装未完成。
echo 请保留此窗口中的错误信息；窗口不会自动关闭。
exit /b 1
