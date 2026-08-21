# SafeMac Cleaner Lite

本仓库仅维护和分发当前最新的 **v4.14 跨平台同步基线版**。

SafeMac Cleaner Lite 是一款本地运行、以安全和可恢复为前提的磁盘清理与应用卸载工具。当前版本已经统一 macOS Intel、macOS Apple Silicon / Universal2 与 Windows 的功能、交互和视觉基线；平台差异仅存在于系统路径、权限模型和底层 API。

## 按需下载

| 使用场景 | 下载入口 | 使用方式 |
| --- | --- | --- |
| v4.14 完整工程 | [下载仓库 ZIP](https://github.com/zhengweijun18/SafeCleaner/archive/refs/heads/main.zip) | 包含 macOS、Windows 与 Shared 跨平台规则。推荐用于保存、继续开发或同步到其它机器。 |
| macOS | [`macOS/`](macOS/) | Intel Mac 可构建 x86_64；新版 Xcode / SDK 可构建 Universal2。进入目录后双击 `双击安装-macOS.command`。 |
| Windows | [`Windows/`](Windows/) | 支持 Windows 10/11、x64/ARM64。进入目录后双击 `双击安装-Windows.cmd`，首次构建需要 .NET 8 SDK。 |

## 当前功能

- **智能扫描**：缓存、日志、开发缓存、Crashpad 和项目可重建产物。
- **大文件**：按体积筛选，仅用于人工判断，不默认勾选。
- **应用卸载**：应用本体 + 精确关联配置、缓存、容器 / AppData 等。
- **应用残留**：保守识别疑似孤儿配置和残留目录。
- **后台扫描**：扫描过程中允许切换左侧页面，原扫描任务继续运行，不重置进度。
- **手动触发**：点击左侧菜单只切换页面，不自动扫描；必须手动点击主按钮开始。
- **暂停 / 继续 / 取消**：扫描任务支持协作式暂停与安全取消。
- **按钮状态**：Default / Hover / Pressed / Selected / Disabled 全局统一。
- **安全清理**：不自动删除；用户手动勾选；默认移到 macOS 废纸篓 / Windows 回收站；不提供默认永久删除。

## 平台支持

| 平台 | 架构 | 最低目标 | 实现 |
| --- | --- | --- | --- |
| macOS | Intel x86_64 | macOS 10.15 | AppKit / Swift |
| macOS | Apple Silicon arm64 | macOS 11 | AppKit / Swift |
| macOS | Universal2 | x86_64 + arm64 | 同一套 AppKit 源码 |
| Windows | x64 | Windows 10 1809+ | WPF / .NET 8 |
| Windows | ARM64 | Windows 10/11 ARM64 | WPF / .NET 8 |

## macOS 使用方式

进入 `macOS/`，双击：

```text
双击安装-macOS.command
```

构建策略：

1. 老 Intel Mac + macOS 10.15 SDK：输出 Intel x86_64 兼容版。
2. 新版 Xcode / SDK：自动编译 x86_64 + arm64，并合成 Universal2。
3. 安装到 `/Applications/SafeMac Cleaner Lite.app`。
4. `/Applications` 没有写入权限时，由 macOS 正常弹出管理员授权窗口。
5. 不关闭 Gatekeeper，不修改系统全局安全策略。

## Windows 使用方式

进入 `Windows/`，双击：

```text
双击安装-Windows.cmd
```

脚本自动识别 x64 / ARM64，并发布 self-contained 程序，默认安装到：

```text
%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite
```

同时创建开始菜单快捷方式。

## 设计与功能锁

从 v4.14 开始，以下内容作为跨平台锁定基线：

1. 左侧四个一级入口与信息层级一致。
2. 深黑蓝背景、玻璃卡片、蓝紫渐变、圆角和间距原则一致。
3. 所有按钮统一具备 Hover / Pressed / Selected / Disabled 状态。
4. 点击左侧菜单不自动启动扫描。
5. 扫描期间允许切换页面，原任务继续运行。
6. 同一时间仅运行一个扫描任务。
7. 扫描结果保存到所属页面，不强行切回扫描页。
8. 删除默认进入废纸篓 / 回收站，可恢复。
9. 平台差异仅用于系统路径和底层 API，不允许自行改变产品交互。

详细规则见：

- [`Shared/FEATURE_LOCK.md`](Shared/FEATURE_LOCK.md)
- [`Shared/design-lock.json`](Shared/design-lock.json)
- [`Shared/PLATFORM_MATRIX.md`](Shared/PLATFORM_MATRIX.md)

## 安全说明

- 不自动执行破坏性清理。
- 不默认使用管理员权限扫描或删除。
- 系统高风险数据默认仅查看或要求人工判断。
- 模糊匹配项默认不勾选。
- macOS 完全磁盘访问权限必须由用户在系统设置中手动授权。
- 默认删除方式始终为废纸篓 / 回收站，可恢复。
