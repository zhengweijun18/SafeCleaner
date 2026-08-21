# Plan A 皮肤分支静态验收

分支：`skin/plan-a-v414`

范围：仅修改 macOS / Windows 的视觉皮肤、应用图标与跨平台视觉锁；扫描、删除、卸载、权限、页面切换和后台任务逻辑保持 v4.14 基线不变。

## 皮肤目标

- 深蓝黑背景
- 深色半透明卡片
- 紫色 / 蓝色高光
- 主操作按钮使用亮蓝到紫色的渐变
- 四个一级功能图标按方案一分色：
  - 智能扫描：紫色
  - 大文件：蓝色
  - 应用卸载：青绿色
  - 应用残留：橙红色
- App 图标改为方案一的紫蓝圆角方形 + 白色扫帚 + 星光
- 所有按钮继续保留 Default / Hover / Pressed / Selected / Disabled 状态

## 收尾检查结果

- 已移除临时拆分的 `PlanA*.swift` 文件，避免与 `LegacyUI.swift` 重复定义主题和控件：PASS
- macOS `LegacyUI.swift` 与 v4.14 Legacy 其余源码组合执行 Swift 语法解析：PASS
- Windows `MainWindow.xaml` XML 解析：PASS
- Windows `.csproj` XML 解析：PASS
- Windows XAML 保留全部现有事件处理器绑定：PASS
- Windows XAML 事件处理器均能在原 `MainWindow.xaml.cs` 中找到：PASS
- Windows XAML `StaticResource` 引用无缺失：PASS
- Windows XAML 顶层控件名无异常重复；模板内部 `Root` / `Scale` 位于独立 NameScope：PASS
- App 图标主资源尺寸 1024×1024：PASS
- App 图标圆角主体及扫帚 / 星光均位于安全区，没有裁切：PASS
- App 图标外围为透明区，不使用黑色矩形底：PASS
- Windows 窗口图标直接使用 `AppIcon.png`：PASS
- Windows 构建前自动从同一 `AppIcon.png` 生成 256 px PNG-in-ICO，并作为 EXE `ApplicationIcon`：PASS
- macOS 构建脚本继续从同一 `AppIcon.png` 生成 ICNS，因此 Intel / Apple Silicon / Universal2 使用同一图标：PASS
- 主文字 / 卡片对比度：17.05:1
- 次级文字 / 卡片对比度：10.99:1
- 表格文字 / 表格背景对比度：18.02:1

## 功能锁审计

与 `main` 比较，本分支没有修改以下业务逻辑文件：

- `macOS/LegacySources/LegacyApp.swift`
- `macOS/LegacySources/LegacyScanner.swift`
- `macOS/LegacySources/LegacyScanProgress.swift`
- `macOS/LegacySources/LegacyTrashWatcher.swift`
- `macOS/LegacySources/LegacyModels.swift`
- `Windows/ScanEngine.cs`
- `Windows/ScanSession.cs`
- `Windows/Models.cs`
- `Windows/MainWindow.xaml.cs`

因此以下行为继续锁定为 v4.14 基线：

- 点击左侧菜单只切换页面，不自动启动扫描
- 扫描过程中允许切换页面，原扫描继续运行
- 同一时间只允许一个扫描任务
- 暂停 / 继续
- 取消扫描
- 扫描结果按所属页面缓存
- 应用卸载与残留识别逻辑
- 用户手动勾选
- 默认移动到废纸篓 / 回收站
- 不默认执行永久删除

## 最终差异范围

允许出现差异的文件限定为：

- `macOS/LegacySources/LegacyUI.swift`
- `macOS/Resources/AppIcon.png`
- `Windows/MainWindow.xaml`
- `Windows/AppIcon.png`
- `Windows/SafeMacCleaner.Windows.csproj`（仅用于绑定方案一 EXE 图标）
- `Windows/prepare_app_icon.ps1`（仅用于从方案一 PNG 生成 ICO）
- `Shared/design-lock.json`
- `Shared/SKIN_AUDIT_PLAN_A.md`

> 当前执行环境不是 macOS / Windows 原生 GUI 桌面，因此已经完成源码语法、XAML 结构、控件绑定、图标安全区、透明区、对比度和 diff 范围检查。实际 AppKit / WPF 的最终像素级渲染仍以目标系统启动截图为最终确认；本次静态检查未发现皮肤缺失、控件绑定缺失、重复类型或业务逻辑漂移。
