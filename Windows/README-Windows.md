# Windows v4.14

支持 Windows 10 1809+ / Windows 11，提供 **x64** 与 **ARM64** 两个预编译 self-contained 版本。

## 推荐使用方式

从仓库 README 的“按需下载”中选择与你系统架构一致的 Windows ZIP：

- `SafeCleaner_v414_Windows_x64.zip`
- `SafeCleaner_v414_Windows_ARM64.zip`

完整解压后双击：

```text
双击安装-Windows.cmd
```

正式下载包已经包含 `SafeMacCleanerLite.exe`，**不需要安装 .NET 8 SDK，也不需要在用户电脑上现场编译**。安装脚本会把程序复制到：

```text
%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite
```

并创建开始菜单快捷方式。

安装窗口会保持打开，若安装或启动失败，可以直接看到具体错误，不再一闪而过。

## 源码构建

只有从源码仓库直接运行、且目录中没有预编译 EXE 时，安装脚本才会回退到 `publish_windows.ps1` 本地构建；这种情况下需要 .NET 8 SDK。

一次输出两个架构：

```powershell
powershell -ExecutionPolicy Bypass -File .\publish_windows.ps1 -Architecture all
```

## 功能对齐

Windows 与 macOS 保持：左侧四个入口一致；切换页面不自动扫描；扫描可后台继续；支持暂停 / 继续 / 取消；扫描结果按页面缓存；按钮具备 Hover / Pressed / Selected / Disabled；默认移动到回收站；不提供默认永久删除。

底层仅把 macOS Library / Containers 等路径换成 Windows Temp / AppData / ProgramData / Registry 等等价系统位置。
