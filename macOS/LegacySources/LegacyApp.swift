import Foundation
import AppKit
import QuartzCore

final class LegacyAppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var tableView: NSTableView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var scanButton: LegacySecondaryButton!
    private var actionButton: LegacyProminentButton!
    private var statusLabel: NSTextField!
    private var freeLabel: NSTextField!
    private var progressIndicator: LegacyProgressBar!
    private var scanDetailLabel: NSTextField!
    private var scanMetricsLabel: NSTextField!
    private var pauseScanButton: LegacyTextButton!
    private var cancelScanButton: NSButton!
    private var windowSizeLabel: NSTextField!
    private var headerBadgeLabel: LegacyBadgeView!
    private var sidebarButtons: [String: LegacyFeatureButton] = [:]
    private var reclaimableCard: LegacyMetricCard!
    private var selectedCard: LegacyMetricCard!
    private var foundCard: LegacyMetricCard!
    private var scanPulseView: LegacyScanPulseView!
    private var sidebarWidthConstraint: NSLayoutConstraint!

    private var scanStartedAt: Date?
    private var scanTimer: Timer?
    private var latestProgress: LegacyScanProgress?
    private var lastProgressRenderAt = Date.distantPast
    private var lastRenderedPhaseIndex = -1
    private let cancellationToken = LegacyCancellationToken()
    private var mode: String = "junk"
    private var isScanning = false
    private var scanMode: String?

    private var junkItemsCache: [LegacyCleanupItem] = []
    private var largeItemsCache: [LegacyCleanupItem] = []
    private var leftoverItemsCache: [LegacyCleanupItem] = []
    private var relatedItemsCache: [LegacyCleanupItem] = []

    private var junkHasScanned = false
    private var largeHasScanned = false
    private var appsHasScanned = false
    private var leftoversHasScanned = false
    private var relatedHasScanned = false

    private var items: [LegacyCleanupItem] = []
    private var apps: [LegacyAppInfo] = []
    private var installedAppsCache: [LegacyAppInfo] = []
    private var selectedApp: LegacyAppInfo?

    private let trashWatcher = LegacyTrashWatcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        buildWindow()
        configureTrashWatcher()
        switchMode("junk")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.showFullDiskAccessGuideIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func windowDidResize(_ notification: Notification) {
        updateResponsiveLayout()
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard let screen = sender.screen ?? NSScreen.main else {
            return frameSize
        }

        let visible = screen.visibleFrame
        let minWidth = min(CGFloat(880), visible.width)
        let minHeight = min(CGFloat(600), visible.height)

        return NSSize(
            width: min(max(frameSize.width, minWidth), visible.width),
            height: min(max(frameSize.height, minHeight), visible.height)
        )
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        keepWindowInsideVisibleScreen()
    }

    private func buildWindow() {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let initialWidth = min(CGFloat(1180), max(CGFloat(880), visible.width * 0.82))
        let initialHeight = min(CGFloat(760), max(CGFloat(600), visible.height * 0.82))

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "SafeMac Cleaner Lite"
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentMinSize = NSSize(width: 880, height: 600)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()

        // Important: keep the window content view on its normal autoresizing mask.
        // Disabling translatesAutoresizingMaskIntoConstraints on NSWindow.contentView can
        // make AppKit fight the live-resize operation and grow the window unexpectedly.
        let root = NSView(frame: NSRect(origin: .zero, size: window.contentView?.bounds.size ?? NSSize(width: initialWidth, height: initialHeight)))
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.backgroundColor = LegacyTheme.backgroundBottom.cgColor
        window.contentView = root

        let sidebar = LegacyGradientView(
            colors: [LegacyTheme.sidebarTop, LegacyTheme.sidebarBottom],
            startPoint: CGPoint(x: 0, y: 1),
            endPoint: CGPoint(x: 1, y: 0)
        )
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.boxType = .separator

        let content = LegacyGradientView(
            colors: [LegacyTheme.backgroundTop, LegacyTheme.backgroundBottom],
            startPoint: CGPoint(x: 0, y: 1),
            endPoint: CGPoint(x: 1, y: 0)
        )
        content.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(sidebar)
        root.addSubview(divider)
        root.addSubview(content)

        sidebarWidthConstraint = sidebar.widthAnchor.constraint(equalToConstant: 236)
        sidebarWidthConstraint.isActive = true

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            divider.topAnchor.constraint(equalTo: root.topAnchor),
            divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            content.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        buildSidebar(sidebar)
        buildContent(content)
        updateResponsiveLayout()
        keepWindowInsideVisibleScreen()
    }

    private func buildSidebar(_ sidebar: NSView) {
        let appIcon = NSImageView()
        appIcon.image = NSApp.applicationIconImage
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.wantsLayer = true
        appIcon.layer?.shadowColor = LegacyTheme.accentPurple.cgColor
        appIcon.layer?.shadowOpacity = 0.32
        appIcon.layer?.shadowRadius = 14
        appIcon.layer?.shadowOffset = CGSize(width: 0, height: 5)
        sidebar.addSubview(appIcon)

        let logo = NSTextField(labelWithString: "SafeMac Cleaner")
        logo.font = NSFont.systemFont(ofSize: 17, weight: .bold)
        logo.textColor = LegacyTheme.text
        logo.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(logo)

        let compat = NSTextField(labelWithString: "Lite · 本地安全清理")
        compat.textColor = LegacyTheme.textSecondary
        compat.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        compat.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(compat)

        let sectionTitle = NSTextField(labelWithString: "核心功能")
        sectionTitle.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        sectionTitle.textColor = LegacyTheme.textMuted
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sectionTitle)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 9
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        let configs: [(String, String, String, String)] = [
            ("junk", "spark", "智能扫描", "缓存 / 日志 / 项目垃圾"),
            ("large", "file", "大文件", "Downloads / Work / Movies"),
            ("apps", "broom", "应用卸载", "本体 + 配置 + 关联文件"),
            ("leftovers", "puzzle", "应用残留", "孤儿配置 / 容器 / Agent")
        ]

        for (key, icon, title, subtitle) in configs {
            let button = LegacyFeatureButton(
                modeKey: key,
                icon: icon,
                title: title,
                subtitle: subtitle
            )
            button.target = self
            button.action = #selector(sidebarClicked(_:))

            stack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 62).isActive = true
            sidebarButtons[key] = button
        }

        let hintCard = LegacyGradientView(
            colors: [
                NSColor(calibratedRed: 0.075, green: 0.075, blue: 0.16, alpha: 0.96),
                NSColor(calibratedRed: 0.035, green: 0.042, blue: 0.075, alpha: 0.96)
            ]
        )
        hintCard.translatesAutoresizingMaskIntoConstraints = false
        hintCard.layer?.cornerRadius = 15
        hintCard.layer?.borderWidth = 1
        hintCard.layer?.borderColor = LegacyTheme.borderStrong.cgColor
        hintCard.layer?.shadowColor = LegacyTheme.accentPurple.cgColor
        hintCard.layer?.shadowOpacity = 0.12
        hintCard.layer?.shadowRadius = 14
        hintCard.layer?.shadowOffset = CGSize(width: 0, height: 5)
        sidebar.addSubview(hintCard)

        let hintTitle = NSTextField(labelWithString: "安全清理")
        hintTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        hintTitle.textColor = LegacyTheme.text
        hintTitle.translatesAutoresizingMaskIntoConstraints = false

        let hintText = NSTextField(
            wrappingLabelWithString: "默认移到废纸篓，可恢复；不使用 sudo，不执行 rm -rf。"
        )
        hintText.font = NSFont.systemFont(ofSize: 10.5)
        hintText.textColor = LegacyTheme.textSecondary
        hintText.translatesAutoresizingMaskIntoConstraints = false

        hintCard.addSubview(hintTitle)
        hintCard.addSubview(hintText)

        freeLabel = NSTextField(labelWithString: "")
        freeLabel.textColor = LegacyTheme.textSecondary
        freeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        freeLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(freeLabel)

        let permission = LegacyTextButton(frame: .zero)
        permission.title = "完全磁盘访问权限…"
        permission.target = self
        permission.action = #selector(openFullDiskAccess)
        sidebar.addSubview(permission)

        NSLayoutConstraint.activate([
            appIcon.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            appIcon.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 16),
            appIcon.widthAnchor.constraint(equalToConstant: 44),
            appIcon.heightAnchor.constraint(equalToConstant: 44),

            logo.leadingAnchor.constraint(equalTo: appIcon.trailingAnchor, constant: 10),
            logo.trailingAnchor.constraint(lessThanOrEqualTo: sidebar.trailingAnchor, constant: -12),
            logo.topAnchor.constraint(equalTo: appIcon.topAnchor, constant: 4),

            compat.leadingAnchor.constraint(equalTo: logo.leadingAnchor),
            compat.trailingAnchor.constraint(lessThanOrEqualTo: sidebar.trailingAnchor, constant: -12),
            compat.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 3),

            sectionTitle.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            sectionTitle.topAnchor.constraint(equalTo: appIcon.bottomAnchor, constant: 22),

            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 9),

            hintCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            hintCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            hintCard.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 15),

            hintTitle.leadingAnchor.constraint(equalTo: hintCard.leadingAnchor, constant: 12),
            hintTitle.trailingAnchor.constraint(equalTo: hintCard.trailingAnchor, constant: -12),
            hintTitle.topAnchor.constraint(equalTo: hintCard.topAnchor, constant: 12),

            hintText.leadingAnchor.constraint(equalTo: hintTitle.leadingAnchor),
            hintText.trailingAnchor.constraint(equalTo: hintTitle.trailingAnchor),
            hintText.topAnchor.constraint(equalTo: hintTitle.bottomAnchor, constant: 6),
            hintText.bottomAnchor.constraint(equalTo: hintCard.bottomAnchor, constant: -12),

            permission.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            permission.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -12),

            freeLabel.leadingAnchor.constraint(equalTo: permission.leadingAnchor),
            freeLabel.bottomAnchor.constraint(equalTo: permission.topAnchor, constant: -8)
        ])
    }

    private func buildContent(_ content: NSView) {
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 27, weight: .bold)
        titleLabel.textColor = LegacyTheme.text
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.textColor = LegacyTheme.textSecondary
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerBadgeLabel = LegacyBadgeView(frame: .zero)

        scanButton = LegacySecondaryButton(frame: .zero)
        scanButton.title = "重新扫描"
        scanButton.target = self
        scanButton.action = #selector(scanCurrent)

        actionButton = LegacyProminentButton(frame: .zero)
        actionButton.title = "立即清理"
        actionButton.target = self
        actionButton.action = #selector(primaryAction)

        reclaimableCard = LegacyMetricCard(
            title: "可处理空间",
            subtitle: "当前页面候选"
        )
        selectedCard = LegacyMetricCard(
            title: "已勾选",
            subtitle: "将移到废纸篓"
        )
        foundCard = LegacyMetricCard(
            title: "发现项目",
            subtitle: "扫描结果"
        )

        let metricsStack = NSStackView(
            views: [reclaimableCard, selectedCard, foundCard]
        )
        metricsStack.orientation = .horizontal
        metricsStack.spacing = 12
        metricsStack.distribution = .fillEqually
        metricsStack.translatesAutoresizingMaskIntoConstraints = false

        scanPulseView = LegacyScanPulseView(frame: .zero)
        scanPulseView.isHidden = true

        progressIndicator = LegacyProgressBar(frame: .zero)

        scanDetailLabel = NSTextField(labelWithString: "当前：—")
        scanDetailLabel.textColor = LegacyTheme.textSecondary
        scanDetailLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 11,
            weight: .regular
        )
        scanDetailLabel.lineBreakMode = .byTruncatingMiddle
        scanDetailLabel.setContentCompressionResistancePriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )
        scanDetailLabel.setContentHuggingPriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )
        scanDetailLabel.translatesAutoresizingMaskIntoConstraints = false

        scanMetricsLabel = NSTextField(
            labelWithString: "阶段 — · 已扫描 0 · 已发现 0 · 用时 00:00"
        )
        scanMetricsLabel.textColor = LegacyTheme.textMuted
        scanMetricsLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 11,
            weight: .regular
        )
        scanMetricsLabel.lineBreakMode = .byTruncatingTail
        scanMetricsLabel.setContentCompressionResistancePriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )
        scanMetricsLabel.setContentHuggingPriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )
        scanMetricsLabel.translatesAutoresizingMaskIntoConstraints = false

        pauseScanButton = LegacyTextButton(frame: .zero)
        pauseScanButton.title = "暂停"
        pauseScanButton.target = self
        pauseScanButton.action = #selector(togglePauseScan)
        pauseScanButton.isHidden = true
        pauseScanButton.setContentHuggingPriority(.required, for: .horizontal)
        pauseScanButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        cancelScanButton = NSButton(
            title: "取消",
            target: self,
            action: #selector(cancelCurrentScan)
        )
        cancelScanButton.bezelStyle = .inline
        cancelScanButton.contentTintColor = LegacyTheme.textSecondary
        cancelScanButton.isHidden = true
        cancelScanButton.translatesAutoresizingMaskIntoConstraints = false
        cancelScanButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelScanButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = LegacyTheme.table
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 14
        scroll.layer?.borderWidth = 1
        scroll.layer?.borderColor = LegacyTheme.border.cgColor
        scroll.layer?.masksToBounds = true

        tableView = NSTableView()
        tableView.appearance = NSAppearance(named: .darkAqua)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = LegacyTheme.table
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 36
        tableView.allowsMultipleSelection = true
        tableView.columnAutoresizingStyle = .sequentialColumnAutoresizingStyle
        tableView.gridStyleMask = []
        scroll.documentView = tableView

        statusLabel = NSTextField(labelWithString: "准备就绪")
        statusLabel.textColor = LegacyTheme.textSecondary
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        windowSizeLabel = NSTextField(labelWithString: "安全删除 · 可恢复")
        windowSizeLabel.textColor = LegacyTheme.textMuted
        windowSizeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        windowSizeLabel.alignment = .right
        windowSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(titleLabel)
        content.addSubview(subtitleLabel)
        content.addSubview(headerBadgeLabel)
        content.addSubview(scanButton)
        content.addSubview(actionButton)
        content.addSubview(metricsStack)
        content.addSubview(scanPulseView)
        content.addSubview(progressIndicator)
        content.addSubview(scanDetailLabel)
        content.addSubview(scanMetricsLabel)
        content.addSubview(pauseScanButton)
        content.addSubview(scroll)
        content.addSubview(statusLabel)
        content.addSubview(windowSizeLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: content.leadingAnchor,
                constant: 24
            ),
            titleLabel.topAnchor.constraint(
                equalTo: content.topAnchor,
                constant: 18
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: scanButton.leadingAnchor,
                constant: -14
            ),

            subtitleLabel.leadingAnchor.constraint(
                equalTo: titleLabel.leadingAnchor
            ),
            subtitleLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 5
            ),
            subtitleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: scanButton.leadingAnchor,
                constant: -14
            ),

            headerBadgeLabel.leadingAnchor.constraint(
                equalTo: subtitleLabel.leadingAnchor
            ),
            headerBadgeLabel.topAnchor.constraint(
                equalTo: subtitleLabel.bottomAnchor,
                constant: 10
            ),
            headerBadgeLabel.heightAnchor.constraint(equalToConstant: 22),
            headerBadgeLabel.widthAnchor.constraint(equalToConstant: 118),

            actionButton.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -24
            ),
            actionButton.topAnchor.constraint(
                equalTo: content.topAnchor,
                constant: 20
            ),
            actionButton.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 210
            ),
            actionButton.widthAnchor.constraint(
                lessThanOrEqualToConstant: 250
            ),

            scanButton.trailingAnchor.constraint(
                equalTo: actionButton.leadingAnchor,
                constant: -10
            ),
            scanButton.centerYAnchor.constraint(
                equalTo: actionButton.centerYAnchor
            ),
            scanButton.widthAnchor.constraint(equalToConstant: 132),

            metricsStack.leadingAnchor.constraint(
                equalTo: content.leadingAnchor,
                constant: 24
            ),
            metricsStack.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -24
            ),
            metricsStack.topAnchor.constraint(
                equalTo: headerBadgeLabel.bottomAnchor,
                constant: 14
            ),

            progressIndicator.leadingAnchor.constraint(
                equalTo: content.leadingAnchor,
                constant: 24
            ),
            progressIndicator.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -24
            ),
            progressIndicator.topAnchor.constraint(
                equalTo: metricsStack.bottomAnchor,
                constant: 12
            ),
            progressIndicator.heightAnchor.constraint(equalToConstant: 8),

            scanPulseView.leadingAnchor.constraint(
                equalTo: progressIndicator.leadingAnchor
            ),
            scanPulseView.topAnchor.constraint(
                equalTo: progressIndicator.bottomAnchor,
                constant: 9
            ),
            scanPulseView.widthAnchor.constraint(equalToConstant: 10),
            scanPulseView.heightAnchor.constraint(equalToConstant: 10),

            scanDetailLabel.leadingAnchor.constraint(
                equalTo: scanPulseView.trailingAnchor,
                constant: 7
            ),
            scanDetailLabel.trailingAnchor.constraint(
                equalTo: pauseScanButton.leadingAnchor,
                constant: -10
            ),
            scanDetailLabel.topAnchor.constraint(
                equalTo: progressIndicator.bottomAnchor,
                constant: 7
            ),

            pauseScanButton.trailingAnchor.constraint(
                equalTo: progressIndicator.trailingAnchor
            ),
            pauseScanButton.widthAnchor.constraint(equalToConstant: 68),
            pauseScanButton.centerYAnchor.constraint(
                equalTo: scanDetailLabel.centerYAnchor
            ),

            scanMetricsLabel.leadingAnchor.constraint(
                equalTo: progressIndicator.leadingAnchor
            ),
            scanMetricsLabel.trailingAnchor.constraint(
                equalTo: progressIndicator.trailingAnchor
            ),
            scanMetricsLabel.topAnchor.constraint(
                equalTo: scanDetailLabel.bottomAnchor,
                constant: 3
            ),

            scroll.leadingAnchor.constraint(
                equalTo: content.leadingAnchor,
                constant: 24
            ),
            scroll.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -24
            ),
            scroll.topAnchor.constraint(
                equalTo: scanMetricsLabel.bottomAnchor,
                constant: 12
            ),
            scroll.bottomAnchor.constraint(
                equalTo: statusLabel.topAnchor,
                constant: -10
            ),

            statusLabel.leadingAnchor.constraint(
                equalTo: scroll.leadingAnchor
            ),
            statusLabel.centerYAnchor.constraint(
                equalTo: windowSizeLabel.centerYAnchor
            ),
            statusLabel.bottomAnchor.constraint(
                equalTo: content.bottomAnchor,
                constant: -12
            ),

            windowSizeLabel.trailingAnchor.constraint(
                equalTo: scroll.trailingAnchor
            ),
            windowSizeLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: statusLabel.trailingAnchor,
                constant: 12
            ),
            windowSizeLabel.bottomAnchor.constraint(
                equalTo: content.bottomAnchor,
                constant: -12
            )
        ])
    }

    private func configureTrashWatcher() {
        trashWatcher.onNewApp = { [weak self] url in
            guard let strongSelf = self else { return }
            if strongSelf.isScanning {
                strongSelf.statusLabel.stringValue =
                    "检测到废纸篓中的 App；当前扫描完成后可在“应用卸载”中处理。"
                return
            }

            if let app = LegacyScanner.appInfo(url) {
                strongSelf.selectedApp = app
                strongSelf.mode = "related"
                strongSelf.selectSidebarButton(nil)
                strongSelf.titleLabel.stringValue = "完整卸载：\(app.name)"
                strongSelf.subtitleLabel.stringValue = "SmartDelete 发现 App 已进入废纸篓；以下是仍可能残留的关联文件。"
                strongSelf.headerBadgeLabel.setText("智能识别")
                strongSelf.items = LegacyScanner.relatedFiles(for: app, appAlreadyInTrash: true, token: nil, progress: nil)
                strongSelf.configureCleanupColumns()
                strongSelf.animateTableReload()
                strongSelf.tableView.reloadData()
                strongSelf.updateStatus()
                strongSelf.actionButton.title = "移到废纸篓"
                strongSelf.actionButton.pulse()
            }
        }
        trashWatcher.start()
    }

    @objc private func sidebarClicked(_ sender: AnyObject) {
        guard let sender = sender as? LegacyFeatureButton else { return }
        switchMode(sender.modeKey)
    }

    private func setSidebarNavigationLocked(_ locked: Bool) {
        // Kept for compatibility with older call sites.
        // v4.13 intentionally allows navigation during background scans.
        for (_, button) in sidebarButtons {
            button.isEnabled = true
            button.alphaValue = 1.0
        }
    }

    private func switchMode(_ key: String) {
        mode = key
        if key != "related" {
            selectedApp = nil
        }

        selectSidebarButton(key)

        let badgeText: String
        switch key {
        case "junk": badgeText = "智能清理"
        case "large": badgeText = "大文件筛选"
        case "apps": badgeText = "完整卸载"
        case "leftovers": badgeText = "残留识别"
        default: badgeText = ""
        }
        headerBadgeLabel.setText(badgeText)

        if key == "junk" {
            titleLabel.stringValue = "智能扫描"
            subtitleLabel.stringValue = "缓存、日志、Crashpad、开发缓存和项目可重建产物。"
            configureCleanupColumns()
            items = junkItemsCache
        } else if key == "large" {
            titleLabel.stringValue = "大文件"
            subtitleLabel.stringValue = "默认扫描 ≥ 500 MB；仅人工判断，不默认勾选。"
            configureCleanupColumns()
            items = largeItemsCache
        } else if key == "apps" {
            titleLabel.stringValue = "应用卸载"
            subtitleLabel.stringValue = "选择应用后分析本体、配置、缓存、容器与关联文件。"
            configureAppColumns()
        } else if key == "leftovers" {
            titleLabel.stringValue = "应用残留"
            subtitleLabel.stringValue = "保守识别当前没有对应已安装 App 的 Bundle 风格文件；全部需要人工确认。"
            configureCleanupColumns()
            items = leftoverItemsCache
        } else if key == "related" {
            titleLabel.stringValue = selectedApp == nil
                ? "完整卸载"
                : "完整卸载：\(selectedApp!.name)"
            subtitleLabel.stringValue = "精确 Bundle ID 匹配默认勾选；宽松匹配项默认不勾选。"
            configureCleanupColumns()
            items = relatedItemsCache
        }

        animateHeader()
        tableView.reloadData()
        renderCurrentPageState()
    }

    private func selectSidebarButton(_ selectedKey: String?) {
        for (key, button) in sidebarButtons {
            button.setSelected(key == selectedKey, animated: true)
        }
    }

    @objc private func scanCurrent() {
        if isScanning {
            cancelCurrentScan()
            return
        }

        startScanForCurrentPage()
    }

    private func normalScanButtonTitle() -> String {
        if mode == "apps" || mode == "related" {
            return "重新扫描 App"
        }
        return "重新扫描"
    }

    private func startScanForCurrentPage() {
        if isScanning {
            return
        }

        if mode == "junk" {
            performScan(ownerMode: "junk") { token, progress in
                LegacyScanner.scanJunk(token: token, progress: progress)
            }
        } else if mode == "large" {
            performScan(ownerMode: "large") { token, progress in
                LegacyScanner.scanLargeFiles(
                    threshold: 500 * 1024 * 1024,
                    token: token,
                    progress: progress
                )
            }
        } else if mode == "apps" {
            performAppScan(ownerMode: "apps")
        } else if mode == "leftovers" {
            performLeftoverScan(ownerMode: "leftovers")
        } else if mode == "related", let app = selectedApp {
            performRelatedScan(app: app, ownerMode: "related")
        }
    }

    private func performScan(
        ownerMode: String,
        _ block: @escaping (
            LegacyCancellationToken,
            @escaping (LegacyScanProgress) -> Void
        ) -> [LegacyCleanupItem]
    ) {
        beginScanUI(ownerMode: ownerMode)

        let progressHandler: (LegacyScanProgress) -> Void = { progress in
            DispatchQueue.main.async {
                self.applyProgress(progress)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let scanned = block(self.cancellationToken, progressHandler)
            let cancelled = self.cancellationToken.isCancelled()

            DispatchQueue.main.async {
                if !cancelled {
                    if ownerMode == "junk" {
                        self.junkItemsCache = scanned
                        self.junkHasScanned = true
                    } else if ownerMode == "large" {
                        self.largeItemsCache = scanned
                        self.largeHasScanned = true
                    }
                }

                if self.mode == ownerMode && !cancelled {
                    self.items = scanned
                    self.animateTableReload()
                    self.tableView.reloadData()
                }

                self.endScanUI(cancelled: cancelled)
                self.renderCurrentPageState()
            }
        }
    }

    private func performAppScan(ownerMode: String) {
        beginScanUI(ownerMode: ownerMode)

        let progressHandler: (LegacyScanProgress) -> Void = { progress in
            DispatchQueue.main.async {
                self.applyProgress(progress)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let scanned = LegacyScanner.scanApps(
                includeSystem: false,
                token: self.cancellationToken,
                progress: progressHandler
            )
            let cancelled = self.cancellationToken.isCancelled()

            DispatchQueue.main.async {
                if !cancelled {
                    self.apps = scanned
                    self.installedAppsCache = scanned
                    self.appsHasScanned = true
                }

                if self.mode == "apps" && !cancelled {
                    self.animateTableReload()
                    self.tableView.reloadData()
                }

                self.endScanUI(cancelled: cancelled)
                self.renderCurrentPageState()
            }
        }
    }

    private func performLeftoverScan(ownerMode: String) {
        beginScanUI(ownerMode: ownerMode)

        let progressHandler: (LegacyScanProgress) -> Void = { progress in
            DispatchQueue.main.async {
                self.applyProgress(progress)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let appList: [LegacyAppInfo]
            if self.installedAppsCache.isEmpty {
                appList = LegacyScanner.scanApps(
                    includeSystem: true,
                    token: self.cancellationToken,
                    progress: progressHandler
                )
            } else {
                appList = self.installedAppsCache
            }

            let leftovers: [LegacyCleanupItem]
            if self.cancellationToken.isCancelled() {
                leftovers = []
            } else {
                leftovers = LegacyScanner.scanLeftovers(
                    installedApps: appList,
                    token: self.cancellationToken,
                    progress: progressHandler
                )
            }

            let cancelled = self.cancellationToken.isCancelled()

            DispatchQueue.main.async {
                if !cancelled {
                    self.installedAppsCache = appList
                    self.leftoverItemsCache = leftovers
                    self.leftoversHasScanned = true
                }

                if self.mode == "leftovers" && !cancelled {
                    self.items = leftovers
                    self.animateTableReload()
                    self.tableView.reloadData()
                }

                self.endScanUI(cancelled: cancelled)
                self.renderCurrentPageState()
            }
        }
    }

    private func performRelatedScan(app: LegacyAppInfo, ownerMode: String) {
        selectedApp = app
        relatedItemsCache = []
        relatedHasScanned = false
        beginScanUI(ownerMode: ownerMode)

        let progressHandler: (LegacyScanProgress) -> Void = { progress in
            DispatchQueue.main.async {
                self.applyProgress(progress)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let related = LegacyScanner.relatedFiles(
                for: app,
                appAlreadyInTrash: false,
                token: self.cancellationToken,
                progress: progressHandler
            )
            let cancelled = self.cancellationToken.isCancelled()

            DispatchQueue.main.async {
                if !cancelled {
                    self.relatedItemsCache = related
                    self.relatedHasScanned = true
                }

                if self.mode == "related" && !cancelled {
                    self.items = related
                    self.configureCleanupColumns()
                    self.animateTableReload()
                    self.tableView.reloadData()
                }

                self.endScanUI(cancelled: cancelled)
                self.renderCurrentPageState()
            }
        }
    }

    @objc private func primaryAction() {
        guard !isScanning else { return }

        if mode == "junk" && !junkHasScanned {
            startScanForCurrentPage()
            return
        }

        if mode == "large" && !largeHasScanned {
            startScanForCurrentPage()
            return
        }

        if mode == "leftovers" && !leftoversHasScanned {
            startScanForCurrentPage()
            return
        }

        if mode == "apps" {
            if !appsHasScanned {
                startScanForCurrentPage()
                return
            }

            let row = tableView.selectedRow
            if row < 0 || row >= apps.count {
                showAlert("请选择一个应用", "先在表格中选择要分析的 App。")
                return
            }

            let app = apps[row]
            selectedApp = app
            relatedItemsCache = []
            relatedHasScanned = false
            switchMode("related")
            performRelatedScan(app: app, ownerMode: "related")
            return
        }

        let targets = items.filter { $0.checked && $0.canDelete }
        if targets.isEmpty {
            showAlert("没有已勾选项目", "请先勾选要清理的项目。")
            return
        }

        let total = targets.reduce(Int64(0)) { $0 + $1.size }
        let alert = NSAlert()
        alert.messageText = "确认移到废纸篓？"
        alert.informativeText =
            "共 \(targets.count) 项，约 \(LegacyFormat.bytes(total))。不会永久删除，可从废纸篓恢复。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() != .alertFirstButtonReturn {
            return
        }

        var failed: [String] = []
        var removedPaths = Set<String>()

        for item in targets {
            do {
                try FileManager.default.trashItem(
                    at: item.url,
                    resultingItemURL: nil
                )
                removedPaths.insert(item.url.standardizedFileURL.path)
            } catch {
                failed.append(
                    "\(item.name)：\(error.localizedDescription)"
                )
            }
        }

        items.removeAll {
            removedPaths.contains($0.url.standardizedFileURL.path)
        }

        if mode == "junk" {
            junkItemsCache = items
        } else if mode == "large" {
            largeItemsCache = items
        } else if mode == "leftovers" {
            leftoverItemsCache = items
        } else if mode == "related" {
            relatedItemsCache = items
        }

        animateTableReload()
        tableView.reloadData()
        renderCurrentPageState()
        actionButton.pulse()

        if !failed.isEmpty {
            showAlert(
                "部分项目未能移动",
                failed.prefix(6).joined(separator: "\n")
            )
        }
    }

    private func configureCleanupColumns() {
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }

        addColumn("check", title: "", width: 42, minWidth: 42, autoresize: false)
        addColumn("name", title: "名称", width: 220, minWidth: 180, autoresize: false)
        addColumn("size", title: "大小", width: 100, minWidth: 90, autoresize: false)
        addColumn("category", title: "类型", width: 130, minWidth: 110, autoresize: false)
        addColumn("recommendation", title: "建议", width: 100, minWidth: 90, autoresize: false)
        addColumn("path", title: "路径", width: 420, minWidth: 220, autoresize: true)
    }

    private func configureAppColumns() {
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }

        addColumn("appName", title: "应用", width: 220, minWidth: 180, autoresize: false)
        addColumn("appSize", title: "大小", width: 100, minWidth: 90, autoresize: false)
        addColumn("version", title: "版本", width: 90, minWidth: 80, autoresize: false)
        addColumn("bundleID", title: "Bundle ID", width: 220, minWidth: 180, autoresize: false)
        addColumn("appPath", title: "路径", width: 360, minWidth: 220, autoresize: true)
    }

    private func addColumn(_ id: String,
                           title: String,
                           width: CGFloat,
                           minWidth: CGFloat,
                           autoresize: Bool) {
        let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: id))
        c.title = title
        c.width = width
        c.minWidth = minWidth
        c.resizingMask = autoresize ? [.autoresizingMask] : []
        tableView.addTableColumn(c)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return mode == "apps" ? apps.count : items.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let id = column.identifier.rawValue

        if mode == "apps" {
            if row < 0 || row >= apps.count { return nil }
            let app = apps[row]
            let value: String

            switch id {
            case "appName": value = app.name
            case "appSize": value = app.sizeText
            case "version": value = app.versionText
            case "bundleID": value = app.bundleID ?? "—"
            case "appPath": value = app.url.path
            default: value = ""
            }

            if id == "appName" {
                return makeAppNameCell(app)
            }
            let cell = makeTextCell()
            cell.textField?.stringValue = value
            return cell
        }

        if row < 0 || row >= items.count { return nil }
        let item = items[row]

        if id == "check" {
            let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkChanged(_:)))
            button.tag = row
            button.state = item.checked ? .on : .off
            button.isEnabled = item.canDelete
            return button
        }

        let value: String
        switch id {
        case "name": value = item.name
        case "size": value = item.sizeText
        case "category": value = item.category
        case "recommendation": value = item.recommendation
        case "path": value = item.url.path
        default: value = ""
        }

        let cell = makeTextCell()
        cell.textField?.stringValue = value
        if id == "recommendation" {
            if item.recommendation == "推荐清理" {
                cell.textField?.textColor = LegacyTheme.green
            } else if item.recommendation == "人工判断" {
                cell.textField?.textColor = LegacyTheme.orange
            } else {
                cell.textField?.textColor = LegacyTheme.textSecondary
            }
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateStatus()
        if mode == "apps" &&
            tableView.selectedRow >= 0 &&
            !isScanning {
            actionButton.pulse()
        }
    }

    private func makeAppNameCell(_ app: LegacyAppInfo) -> NSTableCellView {
        let cell = NSTableCellView()
        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: app.url.path)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let text = NSTextField(labelWithString: app.name)
        text.lineBreakMode = .byTruncatingTail
        text.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(icon)
        cell.addSubview(text)
        cell.textField = text

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func makeTextCell() -> NSTableCellView {
        let cell = NSTableCellView()
        let text = NSTextField(labelWithString: "")
        text.textColor = LegacyTheme.text
        text.lineBreakMode = .byTruncatingMiddle
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = text
        cell.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    @objc private func checkChanged(_ sender: NSButton) {
        let row = sender.tag
        if row >= 0 && row < items.count {
            items[row].checked = (sender.state == .on)
            updateStatus()
        }
    }

    private func updateStatus() {
        renderCurrentPageState()
    }

    private func renderCurrentPageState() {
        freeLabel.stringValue = "剩余 \(LegacyScanner.diskFreeText())"
        updateWindowSizeLabel()

        if mode == "apps" {
            if !appsHasScanned {
                reclaimableCard.update(
                    value: "—",
                    subtitle: "尚未扫描"
                )
                selectedCard.update(
                    value: "—",
                    subtitle: "等待扫描"
                )
                foundCard.update(
                    value: "0",
                    subtitle: "已安装应用"
                )

                actionButton.title = isScanning
                    ? "后台扫描中…"
                    : "扫描应用"
                actionButton.isEnabled = !isScanning

                statusLabel.stringValue = isScanning
                    ? backgroundScanStatusText()
                    : "尚未扫描 · 点击主按钮开始扫描应用"
            } else {
                let total = apps.reduce(Int64(0)) { $0 + $1.size }
                let selectedSize: Int64

                if tableView.selectedRow >= 0 &&
                    tableView.selectedRow < apps.count {
                    selectedSize = apps[tableView.selectedRow].size
                } else {
                    selectedSize = 0
                }

                reclaimableCard.update(
                    value: LegacyFormat.bytes(total),
                    subtitle: "已安装 App 总体积"
                )
                selectedCard.update(
                    value: selectedSize > 0
                        ? LegacyFormat.bytes(selectedSize)
                        : "—",
                    subtitle: "当前选择"
                )
                foundCard.update(
                    value: "\(apps.count)",
                    subtitle: "已安装应用"
                )

                if isScanning {
                    actionButton.title = "后台扫描中…"
                    actionButton.isEnabled = false
                    statusLabel.stringValue = backgroundScanStatusText()
                } else {
                    actionButton.title =
                        tableView.selectedRow >= 0
                        ? "分析卸载"
                        : "请选择 App"
                    actionButton.isEnabled = tableView.selectedRow >= 0
                    statusLabel.stringValue =
                        "已找到 \(apps.count) 个应用 · 磁盘剩余 \(LegacyScanner.diskFreeText())"
                }
            }

            updateScanControlForCurrentPage()
            return
        }

        let hasScanned: Bool
        if mode == "junk" {
            hasScanned = junkHasScanned
        } else if mode == "large" {
            hasScanned = largeHasScanned
        } else if mode == "leftovers" {
            hasScanned = leftoversHasScanned
        } else {
            hasScanned = relatedHasScanned
        }

        if !hasScanned {
            reclaimableCard.update(value: "—", subtitle: "尚未扫描")
            selectedCard.update(value: "—", subtitle: "等待扫描")
            foundCard.update(value: "0", subtitle: "扫描结果")

            if isScanning {
                actionButton.title = "后台扫描中…"
                actionButton.isEnabled = false
                statusLabel.stringValue = backgroundScanStatusText()
            } else {
                if mode == "junk" {
                    actionButton.title = "开始智能扫描"
                    statusLabel.stringValue =
                        "尚未扫描 · 点击主按钮开始智能扫描"
                } else if mode == "large" {
                    actionButton.title = "扫描大文件"
                    statusLabel.stringValue =
                        "尚未扫描 · 点击主按钮开始查找大文件"
                } else if mode == "leftovers" {
                    actionButton.title = "扫描应用残留"
                    statusLabel.stringValue =
                        "尚未扫描 · 点击主按钮开始扫描残留"
                } else {
                    actionButton.title = "分析关联文件"
                    statusLabel.stringValue =
                        "尚未分析 · 点击主按钮开始分析"
                }
                actionButton.isEnabled = true
            }

            updateScanControlForCurrentPage()
            return
        }

        let checked = items.filter { $0.checked && $0.canDelete }
        let selectedBytes =
            checked.reduce(Int64(0)) { $0 + $1.size }
        let candidateBytes =
            items.filter { $0.canDelete }
                .reduce(Int64(0)) { $0 + $1.size }

        reclaimableCard.update(
            value: LegacyFormat.bytes(candidateBytes),
            subtitle: "当前页面候选"
        )
        selectedCard.update(
            value: LegacyFormat.bytes(selectedBytes),
            subtitle: "\(checked.count) 项将处理"
        )
        foundCard.update(
            value: "\(items.count)",
            subtitle: "发现项目"
        )

        if isScanning {
            actionButton.title = "后台扫描中…"
            actionButton.isEnabled = false
            statusLabel.stringValue = backgroundScanStatusText()
        } else {
            if mode == "related" {
                actionButton.title = selectedBytes > 0
                    ? "卸载并清理 \(LegacyFormat.bytes(selectedBytes))"
                    : "勾选后卸载"
            } else {
                actionButton.title = selectedBytes > 0
                    ? "立即清理 \(LegacyFormat.bytes(selectedBytes))"
                    : "勾选后清理"
            }

            actionButton.isEnabled = selectedBytes > 0
            statusLabel.stringValue =
                "\(items.count) 项 · 已勾选 \(checked.count) 项 / \(LegacyFormat.bytes(selectedBytes)) · 磁盘剩余 \(LegacyScanner.diskFreeText())"
        }

        updateScanControlForCurrentPage()
    }

    private func backgroundScanStatusText() -> String {
        guard let owner = scanMode else {
            return "后台扫描中…"
        }

        let name: String
        switch owner {
        case "junk": name = "智能扫描"
        case "large": name = "大文件"
        case "apps": name = "应用"
        case "leftovers": name = "应用残留"
        case "related": name = "关联文件"
        default: name = "任务"
        }

        return "\(name)正在后台扫描 · 可切换页面，进度不会中断"
    }

    private func updateScanControlForCurrentPage() {
        if isScanning {
            scanButton.isHidden = false
            scanButton.title = "取消扫描"
            scanButton.isEnabled = true

            pauseScanButton.isHidden = false
            pauseScanButton.title =
                cancellationToken.isPaused()
                ? "继续"
                : "暂停"
            pauseScanButton.isEnabled = true
            return
        }

        pauseScanButton.isHidden = true

        let hasScanned: Bool
        if mode == "junk" {
            hasScanned = junkHasScanned
        } else if mode == "large" {
            hasScanned = largeHasScanned
        } else if mode == "apps" {
            hasScanned = appsHasScanned
        } else if mode == "leftovers" {
            hasScanned = leftoversHasScanned
        } else {
            hasScanned = relatedHasScanned
        }

        scanButton.isHidden = !hasScanned
        scanButton.title = normalScanButtonTitle()
        scanButton.isEnabled = hasScanned
    }

    private func beginScanUI(ownerMode: String) {
        cancellationToken.reset()
        latestProgress = nil
        lastProgressRenderAt = Date.distantPast
        lastRenderedPhaseIndex = -1
        scanStartedAt = Date()
        isScanning = true
        scanMode = ownerMode

        scanButton.isHidden = false
        scanButton.title = "取消扫描"
        scanButton.isEnabled = true

        actionButton.isEnabled = false
        pauseScanButton.isHidden = false
        pauseScanButton.title = "暂停"
        pauseScanButton.isEnabled = true

        cancelScanButton.isHidden = true
        cancelScanButton.isEnabled = false
        progressIndicator.setProgress(0, animated: false)
        scanDetailLabel.stringValue = "当前：准备扫描…"
        scanMetricsLabel.stringValue = "阶段 0/0 · 0% · 已扫描 0 · 已发现 0 · 用时 00:00"
        statusLabel.stringValue = "正在扫描…"
        if mode == "apps" {
            actionButton.title = "扫描中…"
        } else if mode == "related" {
            actionButton.title = "分析中…"
        } else {
            actionButton.title = "扫描中…"
        }
        scanPulseView.start()
        actionButton.isEnabled = false

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(timeInterval: 0.5,
                                         target: self,
                                         selector: #selector(updateElapsedTime),
                                         userInfo: nil,
                                         repeats: true)
    }

    private func applyProgress(_ progress: LegacyScanProgress) {
        latestProgress = progress

        let now = Date()
        let phaseChanged = progress.phaseIndex != lastRenderedPhaseIndex

        // The scanner can produce callbacks far faster than a human can read.
        // Updating the path row only 4 times/second removes visible jitter while
        // still feeling live. Phase changes render immediately.
        if phaseChanged || now.timeIntervalSince(lastProgressRenderAt) >= 0.25 {
            renderProgress(progress)
        }
    }

    private func renderProgress(_ progress: LegacyScanProgress) {
        lastProgressRenderAt = Date()
        lastRenderedPhaseIndex = progress.phaseIndex

        let phase = min(progress.phaseIndex, progress.phaseCount)
        progressIndicator.setProgress(progress.fraction, animated: true)

        scanDetailLabel.stringValue =
            "当前：\(compactDisplayPath(progress.currentPath))"
        scanDetailLabel.toolTip = progress.currentPath

        scanMetricsLabel.stringValue =
            "阶段 \(phase)/\(progress.phaseCount) · \(progress.percentText) · 已扫描 \(progress.processedCount) · 已发现 \(progress.foundCount) · 用时 \(elapsedText())"
    }

    private func endScanUI(cancelled: Bool) {
        scanTimer?.invalidate()
        scanTimer = nil

        isScanning = false
        scanMode = nil

        actionButton.isEnabled = true
        pauseScanButton.isHidden = true
        pauseScanButton.title = "暂停"
        cancelScanButton.isHidden = true

        if !cancelled {
            progressIndicator.setProgress(1, animated: false)
        }

        if let progress = latestProgress {
            let phase = min(progress.phaseIndex, progress.phaseCount)
            scanMetricsLabel.stringValue =
                "阶段 \(phase)/\(progress.phaseCount) · \(cancelled ? "已取消" : "100%") · 已扫描 \(progress.processedCount) · 已发现 \(progress.foundCount) · 用时 \(elapsedText())"
        }

        scanDetailLabel.stringValue = cancelled ? "当前：扫描已取消" : "当前：扫描完成"
        scanDetailLabel.toolTip = nil
        scanPulseView.stop()
    }

    @objc private func togglePauseScan() {
        let paused = cancellationToken.togglePause()

        pauseScanButton.title = paused ? "继续" : "暂停"

        if paused {
            scanPulseView.stop()
        } else {
            scanPulseView.start()
        }

        renderCurrentPageState()
    }

    @objc private func cancelCurrentScan() {
        guard isScanning else { return }

        cancellationToken.cancel()
        pauseScanButton.isEnabled = false

        scanButton.title = "正在取消…"
        scanButton.isEnabled = false

        cancelScanButton.isEnabled = false
        statusLabel.stringValue = "正在停止扫描，请等待当前文件操作结束…"
    }

    @objc private func updateElapsedTime() {
        guard let progress = latestProgress else {
            scanMetricsLabel.stringValue =
                "阶段 0/0 · 已扫描 0 · 已发现 0 · 用时 \(elapsedText())"
            return
        }

        let phase = min(progress.phaseIndex, progress.phaseCount)
        let stateText = cancellationToken.isPaused()
            ? "已暂停"
            : progress.percentText

        // Only the numeric line is refreshed by the timer. The file path is
        // rendered separately at a throttled cadence and therefore stays calm.
        scanMetricsLabel.stringValue =
            "阶段 \(phase)/\(progress.phaseCount) · \(stateText) · 已扫描 \(progress.processedCount) · 已发现 \(progress.foundCount) · 用时 \(elapsedText())"
    }

    private func compactDisplayPath(_ path: String) -> String {
        if path == "扫描完成" || path == "扫描已取消" {
            return path
        }

        var display = path
        let home = NSHomeDirectory()
        if display.hasPrefix(home) {
            display = "~" + String(display.dropFirst(home.count))
        }

        // Keep a stable, short one-line form. The complete path remains in the
        // tooltip, so the UI does not need to negotiate width for every file.
        let url = URL(fileURLWithPath: display)
        let name = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent

        var compact = name
        if !parent.isEmpty && parent != "/" {
            compact = "…/\(parent)/\(name)"
        }

        if compact.count <= 82 {
            return compact
        }

        return "…/\(parent)/…\(String(name.suffix(54)))"
    }

    private func elapsedText() -> String {
        guard let start = scanStartedAt else { return "00:00" }
        let seconds = max(Int(Date().timeIntervalSince(start)), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func animateTableReload() {
        guard let scroll = tableView.enclosingScrollView else { return }
        scroll.alphaValue = 0.82
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            scroll.animator().alphaValue = 1.0
        }, completionHandler: nil)
    }

    private func animateHeader() {
        titleLabel.alphaValue = 0.75
        subtitleLabel.alphaValue = 0.65
        actionButton.pulse()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            titleLabel.animator().alphaValue = 1
            subtitleLabel.animator().alphaValue = 1
        }, completionHandler: nil)
    }

    private func updateWindowSizeLabel() {
        windowSizeLabel?.stringValue = "本地处理 · 可恢复"
    }

    private func updateResponsiveLayout() {
        // Keep sidebar width stable during live resize.
        // Changing fixed layout constants while the mouse is dragging can make
        // AppKit continuously recompute the fitting size and cause a "bounce"
        // or unexpected growth.
        sidebarWidthConstraint.constant = 236
        updateWindowSizeLabel()
    }

    private func keepWindowInsideVisibleScreen() {
        guard let window = window,
              let screen = window.screen ?? NSScreen.main else {
            return
        }

        let visible = screen.visibleFrame
        var frame = window.frame

        frame.size.width = min(frame.size.width, visible.width)
        frame.size.height = min(frame.size.height, visible.height)

        if frame.maxX > visible.maxX {
            frame.origin.x = visible.maxX - frame.width
        }
        if frame.minX < visible.minX {
            frame.origin.x = visible.minX
        }
        if frame.maxY > visible.maxY {
            frame.origin.y = visible.maxY - frame.height
        }
        if frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }

        if !NSEqualRects(frame, window.frame) {
            window.setFrame(frame, display: true, animate: false)
        }
    }

    private func showFullDiskAccessGuideIfNeeded() {
        let key = "SafeMacCleanerDidShowFullDiskAccessGuide_v1"
        if UserDefaults.standard.bool(forKey: key) {
            return
        }

        UserDefaults.standard.set(true, forKey: key)

        let alert = NSAlert()
        alert.messageText = "建议开启“完全磁盘访问权限”"
        alert.informativeText = """
macOS 不会像相机或麦克风那样主动弹出“允许完全磁盘访问”的授权框。

为了更完整地扫描 Library、Containers 和部分应用残留，需要你手动在：
系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问权限
中添加并勾选 SafeMac Cleaner Lite。

设置后请完全退出本 App，再重新打开。
"""
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            openFullDiskAccess()
        }
    }

    @objc private func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: "好")
        a.runModal()
    }
}
