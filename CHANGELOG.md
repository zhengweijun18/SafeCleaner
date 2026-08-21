# Changelog

## v4.14

- 建立 macOS / Windows 跨平台同步基线。
- macOS 使用同一套 AppKit 源码兼容 Intel、Apple Silicon 与 Universal2。
- Windows 使用 WPF / .NET 8，对齐同一套功能和视觉语言。
- 左侧菜单切换不自动启动扫描。
- 扫描中允许切换页面，原任务继续运行并保持进度。
- 支持暂停、继续和取消扫描。
- 所有主要按钮统一 Default / Hover / Pressed / Selected / Disabled 状态。
- 删除默认进入废纸篓 / 回收站，不提供默认永久删除。
- 锁定 `Shared/FEATURE_LOCK.md`、`Shared/design-lock.json` 与 `Shared/PLATFORM_MATRIX.md`。
