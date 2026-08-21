import Foundation
import Darwin

final class LegacyTrashWatcher {
    private let queue = DispatchQueue(label: "local.safemac.cleanerlite.legacy.trashwatcher")
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var knownApps = Set<String>()
    var onNewApp: ((URL) -> Void)?

    deinit {
        stop()
    }

    func start() {
        stop()

        let trash = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".Trash", isDirectory: true)

        guard FileManager.default.fileExists(atPath: trash.path) else { return }

        knownApps = currentApps(trash)
        descriptor = open(trash.path, O_EVTONLY)
        if descriptor < 0 { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.queue.asyncAfter(deadline: .now() + 0.5) {
                let now = strongSelf.currentApps(trash)
                let added = now.subtracting(strongSelf.knownApps)
                strongSelf.knownApps = now

                for path in added {
                    let url = URL(fileURLWithPath: path)
                    DispatchQueue.main.async {
                        strongSelf.onNewApp?(url)
                    }
                }
            }
        }

        src.setCancelHandler { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.descriptor >= 0 {
                close(strongSelf.descriptor)
                strongSelf.descriptor = -1
            }
        }

        source = src
        src.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        knownApps.removeAll()
        if descriptor >= 0 {
            close(descriptor)
            descriptor = -1
        }
    }

    private func currentApps(_ trash: URL) -> Set<String> {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return Set(children
            .filter { $0.pathExtension.lowercased() == "app" }
            .map { $0.standardizedFileURL.path })
    }
}
