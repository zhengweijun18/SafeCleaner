import Foundation
import AppKit

enum LegacyScanner {
    static let fm = FileManager.default
    static let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

    static func allocatedSize(_ url: URL,
                              reporter: LegacyScanReporter? = nil) -> Int64 {
        if let r = reporter, r.isCancelled() { return 0 }

        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            return 0
        }

        if !isDir.boolValue {
            reporter?.visited(url.path)
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            if let n = attrs?[.size] as? NSNumber {
                return n.int64Value
            }
            return 0
        }

        var total: Int64 = 0
        if let e = fm.enumerator(at: url,
                                 includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                 options: [],
                                 errorHandler: { _, _ in return true }) {
            for case let child as URL in e {
                if let r = reporter, r.isCancelled() {
                    break
                }

                reporter?.visited(child.path)

                let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if values?.isRegularFile == true {
                    total += Int64(values?.fileSize ?? 0)
                }
            }
        }
        return total
    }

    static func scanJunk(token: LegacyCancellationToken,
                         progress: ((LegacyScanProgress) -> Void)?) -> [LegacyCleanupItem] {
        let reporter = LegacyScanReporter(token: token, callback: progress)
        var result: [LegacyCleanupItem] = []

        let childRoots: [(URL, String, String, String)] = [
            (home.appendingPathComponent("Library/Caches", isDirectory: true),
             "缓存", "应用缓存，可重新生成。", "用户缓存"),
            (home.appendingPathComponent("Library/Logs", isDirectory: true),
             "日志", "历史日志，通常可清理。", "用户日志"),
            (home.appendingPathComponent(".cache", isDirectory: true),
             "缓存", "命令行工具缓存，可重新生成。", "命令行缓存")
        ]

        let safeWhole: [(URL, String, String)] = [
            (home.appendingPathComponent("Library/Application Support/Codex/Crashpad", isDirectory: true),
             "Codex Crashpad 崩溃报告 / dump；建议先退出 Codex。", "Codex Crashpad"),
            (home.appendingPathComponent("Library/Application Support/Code/Crashpad", isDirectory: true),
             "VS Code 崩溃报告；建议先退出 VS Code。", "VS Code Crashpad"),
            (home.appendingPathComponent(".npm/_cacache", isDirectory: true),
             "npm 下载缓存，可重新获取。", "npm 缓存"),
            (home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true),
             "Xcode DerivedData，可重新构建。", "Xcode DerivedData")
        ]

        let projectRoots = [
            home.appendingPathComponent("Work", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true)
        ]

        let phaseCount = childRoots.count + safeWhole.count + projectRoots.count
        var phase = 0

        for (root, category, reason, phaseName) in childRoots {
            if reporter.isCancelled() { break }
            phase += 1
            reporter.beginPhase(phaseName, index: phase, count: phaseCount, path: root.path)

            guard fm.fileExists(atPath: root.path) else { continue }
            let children = (try? fm.contentsOfDirectory(at: root,
                                                       includingPropertiesForKeys: nil,
                                                       options: [])) ?? []
            for child in children {
                if reporter.isCancelled() { break }
                let size = allocatedSize(child, reporter: reporter)
                if size <= 0 { continue }

                result.append(LegacyCleanupItem(
                    url: child,
                    size: size,
                    category: category,
                    recommendation: "推荐清理",
                    reason: reason,
                    canDelete: true,
                    checked: true
                ))
                reporter.found(child.path)
            }
        }

        for (url, reason, phaseName) in safeWhole {
            if reporter.isCancelled() { break }
            phase += 1
            reporter.beginPhase(phaseName, index: phase, count: phaseCount, path: url.path)

            if !fm.fileExists(atPath: url.path) { continue }
            let size = allocatedSize(url, reporter: reporter)
            if size <= 0 { continue }

            result.append(LegacyCleanupItem(
                url: url,
                size: size,
                category: "开发 / 崩溃缓存",
                recommendation: "推荐清理",
                reason: reason,
                canDelete: true,
                checked: true
            ))
            reporter.found(url.path)
        }

        let targetNames: Set<String> = [
            "node_modules", "dist", "build", ".next", ".nuxt",
            ".turbo", "coverage", ".parcel-cache", ".vite"
        ]

        for root in projectRoots {
            if reporter.isCancelled() { break }
            phase += 1
            reporter.beginPhase("项目垃圾 · \(root.lastPathComponent)",
                                index: phase,
                                count: phaseCount,
                                path: root.path)

            if !fm.fileExists(atPath: root.path) { continue }
            guard let e = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { _, _ in return true }
            ) else { continue }

            let baseDepth = root.pathComponents.count

            for case let url as URL in e {
                if reporter.isCancelled() { break }
                reporter.visited(url.path)

                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory != true { continue }

                let depth = url.pathComponents.count - baseDepth
                if depth > 6 {
                    e.skipDescendants()
                    continue
                }

                let name = url.lastPathComponent
                if name == ".git" {
                    e.skipDescendants()
                    continue
                }

                if targetNames.contains(name) {
                    let size = allocatedSize(url, reporter: reporter)
                    if size >= 50 * 1024 * 1024 {
                        let reason = name == "node_modules"
                            ? "项目依赖目录，可通过 npm/pnpm/yarn 重新安装。"
                            : "项目构建 / 测试产物，可重新生成。"

                        result.append(LegacyCleanupItem(
                            url: url,
                            size: size,
                            category: "项目垃圾",
                            recommendation: "推荐清理",
                            reason: reason,
                            canDelete: true,
                            checked: false
                        ))
                        reporter.found(url.path)
                    }
                    e.skipDescendants()
                }
            }
        }

        reporter.finish(path: reporter.isCancelled() ? "扫描已取消" : "扫描完成")
        return result.sorted { $0.size > $1.size }
    }

    static func scanLargeFiles(threshold: Int64,
                               token: LegacyCancellationToken,
                               progress: ((LegacyScanProgress) -> Void)?) -> [LegacyCleanupItem] {
        let reporter = LegacyScanReporter(token: token, callback: progress)
        let roots = [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Movies", isDirectory: true),
            home.appendingPathComponent("Work", isDirectory: true)
        ]

        var result: [LegacyCleanupItem] = []
        let phaseCount = roots.count

        for (offset, root) in roots.enumerated() {
            if reporter.isCancelled() { break }

            reporter.beginPhase("大文件 · \(root.lastPathComponent)",
                                index: offset + 1,
                                count: phaseCount,
                                path: root.path)

            if !fm.fileExists(atPath: root.path) { continue }

            guard let e = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { _, _ in return true }
            ) else { continue }

            for case let url as URL in e {
                if reporter.isCancelled() { break }
                reporter.visited(url.path)

                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey])

                if values?.isDirectory == true {
                    let n = url.lastPathComponent
                    if n == ".git" || n == "node_modules" {
                        e.skipDescendants()
                    }
                    continue
                }

                if values?.isRegularFile != true { continue }
                let size = Int64(values?.fileSize ?? 0)
                if size < threshold { continue }

                result.append(LegacyCleanupItem(
                    url: url,
                    size: size,
                    category: "大文件",
                    recommendation: "人工判断",
                    reason: "大型个人文件，只在确认不再需要后清理。",
                    canDelete: true,
                    checked: false
                ))
                reporter.found(url.path)
            }
        }

        reporter.finish(path: reporter.isCancelled() ? "扫描已取消" : "扫描完成")
        return result.sorted { $0.size > $1.size }
    }

    static func scanApps(includeSystem: Bool,
                         token: LegacyCancellationToken? = nil,
                         progress: ((LegacyScanProgress) -> Void)? = nil) -> [LegacyAppInfo] {
        var roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]

        if includeSystem {
            roots.append(URL(fileURLWithPath: "/System/Applications", isDirectory: true))
        }

        let localToken = token ?? LegacyCancellationToken()
        let reporter = LegacyScanReporter(token: localToken, callback: progress)

        var result: [LegacyAppInfo] = []
        var seen = Set<String>()

        for (offset, root) in roots.enumerated() {
            if reporter.isCancelled() { break }

            reporter.beginPhase("应用 · \(root.path)",
                                index: offset + 1,
                                count: roots.count,
                                path: root.path)

            if !fm.fileExists(atPath: root.path) { continue }

            guard let e = fm.enumerator(at: root,
                                        includingPropertiesForKeys: [.isDirectoryKey],
                                        options: [.skipsHiddenFiles],
                                        errorHandler: { _, _ in return true }) else {
                continue
            }

            for case let url as URL in e {
                if reporter.isCancelled() { break }
                reporter.visited(url.path)

                if url.pathExtension.lowercased() == "app" {
                    e.skipDescendants()
                    let path = url.standardizedFileURL.path
                    if seen.contains(path) { continue }
                    seen.insert(path)

                    if let app = appInfo(url, reporter: reporter) {
                        result.append(app)
                        reporter.found(url.path)
                    }
                    continue
                }

                let depth = url.pathComponents.count - root.pathComponents.count
                if depth > 3 {
                    e.skipDescendants()
                }
            }
        }

        reporter.finish(path: reporter.isCancelled() ? "扫描已取消" : "扫描完成")

        return result.sorted {
            return $0.size == $1.size
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.size > $1.size
        }
    }

    static func appInfo(_ url: URL,
                        reporter: LegacyScanReporter? = nil) -> LegacyAppInfo? {
        if url.pathExtension.lowercased() != "app" { return nil }

        let plist = url.appendingPathComponent("Contents/Info.plist")
        var dict: [String: Any]? = nil

        if let data = try? Data(contentsOf: plist),
           let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            dict = object as? [String: Any]
        }

        let rawName = (dict?["CFBundleDisplayName"] as? String)
            ?? (dict?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let bid = dict?["CFBundleIdentifier"] as? String
        let version = (dict?["CFBundleShortVersionString"] as? String)
            ?? (dict?["CFBundleVersion"] as? String)
        let isSystem = url.path.hasPrefix("/System/")

        return LegacyAppInfo(
            url: url,
            name: rawName,
            bundleID: bid,
            version: version,
            size: allocatedSize(url, reporter: reporter),
            isSystem: isSystem
        )
    }

    static func relatedFiles(for app: LegacyAppInfo,
                             appAlreadyInTrash: Bool,
                             token: LegacyCancellationToken? = nil,
                             progress: ((LegacyScanProgress) -> Void)? = nil) -> [LegacyCleanupItem] {
        let localToken = token ?? LegacyCancellationToken()
        let reporter = LegacyScanReporter(token: localToken, callback: progress)
        reporter.beginPhase("应用关联文件", index: 1, count: 1, path: app.url.path)

        var result: [LegacyCleanupItem] = []
        var seen = Set<String>()

        func add(_ url: URL,
                 _ recommendation: String,
                 _ reason: String,
                 _ canDelete: Bool,
                 _ checked: Bool) {
            if reporter.isCancelled() { return }
            reporter.visited(url.path)
            if !fm.fileExists(atPath: url.path) { return }

            let p = url.standardizedFileURL.path
            if seen.contains(p) { return }
            seen.insert(p)

            result.append(LegacyCleanupItem(
                url: url,
                size: allocatedSize(url, reporter: reporter),
                category: url.pathExtension.lowercased() == "app" ? "应用本体" : "应用关联文件",
                recommendation: recommendation,
                reason: reason,
                canDelete: canDelete,
                checked: checked && canDelete
            ))
            reporter.found(url.path)
        }

        if !appAlreadyInTrash {
            add(app.url,
                app.isSystem ? "仅查看" : "人工判断",
                app.isSystem ? "系统应用本体不可卸载。" : "应用本体。",
                !app.isSystem,
                !app.isSystem)
        }

        guard let bundleID = app.bundleID, !bundleID.isEmpty else {
            reporter.finish(path: "扫描完成")
            return result.sorted { $0.size > $1.size }
        }

        let exacts: [(String, String)] = [
            ("Library/Caches/\(bundleID)", "Bundle ID 精确匹配的缓存。"),
            ("Library/Containers/\(bundleID)", "Bundle ID 精确匹配的沙盒容器。"),
            ("Library/Application Scripts/\(bundleID)", "Bundle ID 精确匹配的 Application Scripts。"),
            ("Library/WebKit/\(bundleID)", "Bundle ID 精确匹配的 WebKit 数据。"),
            ("Library/HTTPStorages/\(bundleID)", "Bundle ID 精确匹配的 HTTPStorage。"),
            ("Library/Preferences/\(bundleID).plist", "Bundle ID 精确匹配的偏好设置。"),
            ("Library/Saved Application State/\(bundleID).savedState", "Bundle ID 精确匹配的窗口恢复状态。")
        ]

        for (relative, reason) in exacts {
            if reporter.isCancelled() { break }
            let url = home.appendingPathComponent(relative)
            add(url, "推荐清理", reason, true, true)
        }

        let names = [app.name, app.url.deletingPathExtension().lastPathComponent]
        let nameRoots = [
            home.appendingPathComponent("Library/Application Support", isDirectory: true),
            home.appendingPathComponent("Library/Caches", isDirectory: true),
            home.appendingPathComponent("Library/Logs", isDirectory: true)
        ]

        for root in nameRoots {
            for name in names {
                if reporter.isCancelled() { break }
                if name.isEmpty { continue }
                add(root.appendingPathComponent(name),
                    "人工判断",
                    "目录名与应用名称匹配，请确认后清理。",
                    true,
                    false)
            }
        }

        reporter.finish(path: reporter.isCancelled() ? "扫描已取消" : "扫描完成")
        return result.sorted {
            if $0.category == "应用本体" { return true }
            if $1.category == "应用本体" { return false }
            return $0.size > $1.size
        }
    }

    static func scanLeftovers(installedApps: [LegacyAppInfo],
                              token: LegacyCancellationToken,
                              progress: ((LegacyScanProgress) -> Void)?) -> [LegacyCleanupItem] {
        let reporter = LegacyScanReporter(token: token, callback: progress)

        var active = Set<String>()
        for app in installedApps {
            if let bid = app.bundleID {
                active.insert(bid.lowercased())
            }
        }

        let roots = [
            home.appendingPathComponent("Library/Caches", isDirectory: true),
            home.appendingPathComponent("Library/Preferences", isDirectory: true),
            home.appendingPathComponent("Library/Saved Application State", isDirectory: true),
            home.appendingPathComponent("Library/WebKit", isDirectory: true),
            home.appendingPathComponent("Library/HTTPStorages", isDirectory: true),
            home.appendingPathComponent("Library/LaunchAgents", isDirectory: true),
            home.appendingPathComponent("Library/Containers", isDirectory: true),
            home.appendingPathComponent("Library/Application Scripts", isDirectory: true)
        ]

        var result: [LegacyCleanupItem] = []
        var seen = Set<String>()

        for (offset, root) in roots.enumerated() {
            if reporter.isCancelled() { break }

            reporter.beginPhase("残留 · \(root.lastPathComponent)",
                                index: offset + 1,
                                count: roots.count,
                                path: root.path)

            if !fm.fileExists(atPath: root.path) { continue }
            let children = (try? fm.contentsOfDirectory(at: root,
                                                       includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles])) ?? []

            for child in children {
                if reporter.isCancelled() { break }
                reporter.visited(child.path)

                var base = child.lastPathComponent.lowercased()
                for suffix in [".plist", ".savedstate", ".binarycookies"] {
                    if base.hasSuffix(suffix) {
                        base = String(base.dropLast(suffix.count))
                    }
                }

                let parts = base.split(separator: ".")
                if parts.count < 3 { continue }

                let prefix = String(parts[0])
                if !["com", "org", "net", "io", "dev", "co", "me"].contains(prefix) { continue }
                if base.hasPrefix("com.apple.") { continue }
                if active.contains(base) { continue }

                let p = child.standardizedFileURL.path
                if seen.contains(p) { continue }
                seen.insert(p)

                result.append(LegacyCleanupItem(
                    url: child,
                    size: allocatedSize(child, reporter: reporter),
                    category: "疑似应用残留",
                    recommendation: "人工判断",
                    reason: "Bundle 风格标识在当前已安装应用中未找到对应项；请核对后清理。",
                    canDelete: true,
                    checked: false
                ))
                reporter.found(child.path)
            }
        }

        reporter.finish(path: reporter.isCancelled() ? "扫描已取消" : "扫描完成")
        return result.sorted { $0.size > $1.size }
    }

    static func diskFreeText() -> String {
        let attrs = (try? fm.attributesOfFileSystem(forPath: NSHomeDirectory())) ?? [:]
        let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return "\(LegacyFormat.bytes(free)) / \(LegacyFormat.bytes(total))"
    }
}
