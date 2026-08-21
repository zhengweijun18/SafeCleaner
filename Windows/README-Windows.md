# Windows v4.14

支持：

- Windows 10 1809+
- Windows 11
- x64
- ARM64

默认安装方式：

双击 `双击安装-Windows.cmd`

脚本会自动识别 x64 / ARM64，使用 .NET 8 发布 self-contained 单文件程序，
然后安装到：

`%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite`

并创建开始菜单快捷方式。

如果希望一次输出两个架构：

```powershell
powershell -ExecutionPolicy Bypass -File .\publish_windows.ps1 -Architecture all
```

## 功能对齐

Windows 与 macOS 保持：

- 左侧四个入口一致
- 切换页面不自动扫描
- 扫描可后台继续
- 暂停 / 继续 / 取消
- 扫描结果按页面缓存
- Hover / Pressed / Selected / Disabled
- 默认移动到回收站
- 不提供默认永久删除

底层仅把 macOS Library / Containers 等路径换成 Windows Temp / AppData /
ProgramData / Registry 等等价系统位置。
