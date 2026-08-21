# v4.14 平台矩阵

| 平台 | 架构 | 最低目标 | UI 实现 |
|---|---|---|---|
| macOS | Intel x86_64 | macOS 10.15 | AppKit |
| macOS | Apple Silicon arm64 | macOS 11 | AppKit |
| macOS | Universal2 | x86_64 + arm64 | AppKit，同一源码 |
| Windows | x64 | Windows 10 1809+ | WPF / .NET 8 |
| Windows | ARM64 | Windows 10/11 ARM64 | WPF / .NET 8 |

macOS 三个构建目标全部使用同一套 `LegacySources`，不再让 SwiftUI 与 AppKit
形成两套视觉分支，因此 Intel / M 芯片样式保持一致。

Windows 使用同一份 `design-lock.json` 对齐布局、颜色、圆角、按钮状态和行为。
