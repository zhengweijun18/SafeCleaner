# macOS v4.14

直接双击：

`双击安装-macOS.command`

构建策略：

- 老 Intel Mac + macOS 10.15 SDK：输出 Intel x86_64。
- 新版 Xcode / SDK：自动输出 Universal2（x86_64 + arm64）。
- Intel 最低目标 macOS 10.15。
- Apple Silicon 最低目标 macOS 11。
- 两种架构使用完全相同的 AppKit UI 源码，视觉和功能不分叉。

如果 `/Applications` 需要管理员权限，安装时由 macOS 正常弹出管理员授权窗口。
