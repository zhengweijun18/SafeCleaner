import Foundation
import AppKit

final class LegacyCleanupItem: NSObject {
    let url: URL
    let size: Int64
    let category: String
    let recommendation: String
    let reason: String
    let canDelete: Bool
    var checked: Bool

    init(url: URL,
         size: Int64,
         category: String,
         recommendation: String,
         reason: String,
         canDelete: Bool,
         checked: Bool) {
        self.url = url.standardizedFileURL
        self.size = size
        self.category = category
        self.recommendation = recommendation
        self.reason = reason
        self.canDelete = canDelete
        self.checked = checked
    }

    var name: String {
        let n = url.lastPathComponent
        return n.isEmpty ? url.path : n
    }

    var sizeText: String {
        return LegacyFormat.bytes(size)
    }
}

final class LegacyAppInfo: NSObject {
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let size: Int64
    let isSystem: Bool

    init(url: URL,
         name: String,
         bundleID: String?,
         version: String?,
         size: Int64,
         isSystem: Bool) {
        self.url = url.standardizedFileURL
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.size = size
        self.isSystem = isSystem
    }

    var sizeText: String {
        return LegacyFormat.bytes(size)
    }

    var versionText: String {
        if let v = version, !v.isEmpty { return v }
        return "—"
    }
}

enum LegacyFormat {
    static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f.string(fromByteCount: value)
    }
}
