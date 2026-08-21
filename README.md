# SafeMac Cleaner Lite

本仓库用于维护和分发 **SafeMac Cleaner Lite**：一款本地运行、以安全和可恢复为前提的磁盘清理与应用卸载工具。

当前代码已经进入跨平台同步维护模式：macOS Intel、macOS Apple Silicon / Universal2 与 Windows 保持同一套功能、交互和视觉基线；平台差异仅存在于系统路径、权限模型和底层 API。

## 按需下载

| 使用场景 | 下载入口 | 使用方式 |
| --- | --- | --- |
| 最新跨平台完整工程 v4.14 | [下载 v4.14 跨平台完整包](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeCleaner_v414_CrossPlatform.zip) | 同时包含 macOS、Windows 和 Shared 设计/功能锁。推荐用于继续开发和统一维护。 |
| macOS v4.14 | [下载 v4.14 macOS 包](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeCleaner_v414_macOS.zip) | Intel Mac 可直接构建 x86_64；新版 Xcode / SDK 可构建 Universal2（Intel + Apple Silicon）。解压后双击 `双击安装-macOS.command`。 |
| Windows v4.14 | [下载 v4.14 Windows 包](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeCleaner_v414_Windows.zip) | 支持 Windows 10/11、x64/ARM64。解压后双击 `双击安装-Windows.cmd`。首次本地构建需要 .NET 8 SDK。 |
| macOS v4.13.1 | [下载 v4.13.1](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v4131.zip) | Swift 5.2 兼容修复版，适合老 Intel Mac / macOS 10.15 工具链。 |

## 历史版本下载

| 版本 | 下载 | 主要变化 |
| --- | --- | --- |
| v4.13 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v413.zip) | 左侧切换与扫描任务解耦；页面切换不自动扫描；按钮补齐 Hover / Pressed 等状态。 |
| v4.12 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v412.zip) | 扫描状态下顶部“重新扫描”改为“取消扫描”；修复并发页面扫描导致的进度失控问题。 |
| v4.11 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v411.zip) | 新增暂停 / 继续；降低扫描文本和进度条刷新频率，减少抖动。 |
| v4.10 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v410.zip) | 修复主按钮文字重叠、扫描路径撑开窗口、Badge 垂直居中和 App 图标边缘问题。 |
| v4.9 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v49.zip) | 确立当前深黑蓝 + 蓝紫渐变视觉基线；加入一键安装和稳定签名复用逻辑。 |
| v4.8 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v48.zip) | 使用自定义进度条替换系统 `NSProgressIndicator`，修复窗口被进度控件撑开的核心问题。 |
| v4.7 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v47.zip) | 切换深色主题；完善窗口最小尺寸、侧栏固定宽度和可视区域约束。 |
| v4.6 | [下载](https://github.com/zhengweijun18/SafeCleaner/raw/refs/heads/main/downloads/SafeMacCleaner_v46.zip) | 响应式统计卡、自定义侧栏图标、渐变主按钮、App 图标和扫描动效。 |

> v4.1–v4.5 属于早期内部迭代阶段。本仓库当前保存的是从 v4.6 开始仍可完整恢复的发行包，以及最新跨平台源码。

## 当前功能

- **智能扫描**：缓存、日志、开发缓存、Crashpad 和项目可重建产物。
- **大文件**：按体积筛选，仅用于人工判断，不默认勾选。
- **应用卸载**：应用本体 + 精确关联配置、缓存、容器 / AppData 等。
- **应用残留**：保守识别疑似孤儿配置和残留目录。
- **后台扫描**：扫描过程中可切换左侧页面，原扫描任务继续运行，不重置进度。
- **暂停 / 继续 / 取消**：扫描任务支持协作式暂停与安全取消。
- **安全清理**：不自动删除；用户手动勾选；默认移到 macOS 废纸篓 / Windows 回收站；不提供默认永久删除。

## 平台支持

| 平台 | 架构 | 最低目标 | 实现 |
| --- | --- | --- | --- |
| macOS | Intel x86_64 | macOS 10.15 | AppKit / Swift |
| macOS | Apple Silicon arm64 | macOS 11 | AppKit / Swift |
| macOS | Universal2 | x86_64 + arm64 | 同一套 AppKit 源码 |
| Windows | x64 | Windows 10 1809+ | WPF / .NET 8 |
| Windows | ARM64 | Windows 10/11 ARM64 | WPF / .NET 8 |

## 目录说明

- `macOS/`：最新 macOS v4.14 源码、资源、构建与安装脚本。
- `Windows/`：最新 Windows v4.14 WPF 源码、发布与安装脚本。
- `Shared/`：跨平台功能锁、视觉设计锁和平台兼容矩阵。
- `downloads/`：v4.6 至 v4.14 的可下载 ZIP 发行包。
- `CHANGELOG.md`：版本演进记录。
- `downloads/manifest.json`：下载包大小与 SHA-256 校验值。

## macOS 使用方式

进入 `macOS/` 后双击：

```text
双击安装-macOS.command
```

构建逻辑：

1. 老 Intel Mac + macOS 10.15 SDK：输出 x86_64 兼容版。
2. 新版 Xcode / SDK：自动编译 x86_64 + arm64 并合成 Universal2。
3. 安装目标固定为 `/Applications/SafeMac Cleaner Lite.app`；没有写入权限时由 macOS 弹出管理员授权。
4. 不关闭 Gatekeeper，不修改系统全局安全策略。

## Windows 使用方式

进入 `Windows/` 后双击：

```text
双击安装-Windows.cmd
```

脚本会自动识别 x64 / ARM64，并发布 self-contained 程序，然后安装到：

```text
%LOCALAPPDATA%\Programs\SafeMac Cleaner Lite
```

同时创建开始菜单快捷方式。

## 设计与功能锁

从 v4.14 开始，以下内容视为跨平台锁定基线：

1. 左侧四个一级入口及信息层级一致。
2. 深黑蓝背景、玻璃卡片、蓝紫渐变、圆角和间距原则一致。
3. 所有按钮统一具有 Default / Hover / Pressed / Selected / Disabled 状态。
4. 点击左侧菜单只切换页面，不自动启动扫描。
5. 扫描过程中允许切换页面，原任务继续运行。
6. 同一时间仅运行一个扫描任务。
7. 删除默认进入废纸篓 / 回收站，可恢复。
8. 平台差异仅用于系统路径和底层 API，不允许自行改变产品交互。

详细规则见：

- [`Shared/FEATURE_LOCK.md`](Shared/FEATURE_LOCK.md)
- [`Shared/design-lock.json`](Shared/design-lock.json)
- [`Shared/PLATFORM_MATRIX.md`](Shared/PLATFORM_MATRIX.md)

## 安全说明

本工具采用保守策略：

- 不自动执行破坏性清理。
- 不使用运行时 `rm -rf` 清理用户数据。
- 不默认使用 `sudo` 扫描或删除。
- 系统高风险数据默认仅查看或要求人工判断。
- 模糊匹配项默认不勾选。
- macOS 完全磁盘访问权限必须由用户在系统设置中手动授权。

## 校验下载文件

下载包的 SHA-256 记录在 [`downloads/manifest.json`](downloads/manifest.json)。macOS 可执行：

```bash
shasum -a 256 SafeCleaner_v414_CrossPlatform.zip
```

Windows PowerShell 可执行：

```powershell
Get-FileHash .\SafeCleaner_v414_Windows.zip -Algorithm SHA256
```
