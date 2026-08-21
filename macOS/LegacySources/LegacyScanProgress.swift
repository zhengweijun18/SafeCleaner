import Foundation

struct LegacyScanProgress {
    let phaseName: String
    let currentPath: String
    let processedCount: Int
    let foundCount: Int
    let phaseIndex: Int
    let phaseCount: Int

    var fraction: Double {
        if phaseCount <= 0 { return 0 }
        let completed = max(0, phaseIndex - 1)
        return min(max(Double(completed) / Double(phaseCount), 0), 1)
    }

    var percentText: String {
        return String(format: "%.0f%%", fraction * 100.0)
    }
}

final class LegacyCancellationToken {
    private let condition = NSCondition()
    private var cancelled = false
    private var paused = false

    func cancel() {
        condition.lock()
        cancelled = true
        paused = false
        condition.broadcast()
        condition.unlock()
    }

    func reset() {
        condition.lock()
        cancelled = false
        paused = false
        condition.broadcast()
        condition.unlock()
    }

    func togglePause() -> Bool {
        condition.lock()
        if !cancelled {
            paused = !paused
            if !paused {
                condition.broadcast()
            }
        }
        let value = paused
        condition.unlock()
        return value
    }

    func isPaused() -> Bool {
        condition.lock()
        let value = paused
        condition.unlock()
        return value
    }

    func isCancelled() -> Bool {
        condition.lock()
        let value = cancelled
        condition.unlock()
        return value
    }

    func waitIfPausedAndCheckCancelled() -> Bool {
        condition.lock()
        while paused && !cancelled {
            condition.wait()
        }
        let value = cancelled
        condition.unlock()
        return value
    }
}

final class LegacyScanReporter {
    private let callback: ((LegacyScanProgress) -> Void)?
    private let token: LegacyCancellationToken
    private(set) var processedCount: Int = 0
    private(set) var foundCount: Int = 0
    private var phaseName: String = ""
    private var phaseIndex: Int = 1
    private var phaseCount: Int = 1
    private var lastEmit = Date.distantPast

    init(token: LegacyCancellationToken,
         callback: ((LegacyScanProgress) -> Void)?) {
        self.token = token
        self.callback = callback
    }

    func beginPhase(_ name: String, index: Int, count: Int, path: String) {
        if token.waitIfPausedAndCheckCancelled() { return }

        phaseName = name
        phaseIndex = max(index, 1)
        phaseCount = max(count, 1)
        emit(path, force: true)
    }

    func visited(_ path: String) {
        if token.waitIfPausedAndCheckCancelled() { return }

        processedCount += 1
        emit(path, force: false)
    }

    func found(_ path: String) {
        if token.waitIfPausedAndCheckCancelled() { return }

        foundCount += 1

        // Do not force a UI update for every discovered item. Large scans
        // discover files in bursts and that made the path row visibly flicker.
        emit(path, force: false)
    }

    func finish(path: String) {
        phaseIndex = phaseCount + 1
        emit(path, force: true)
    }

    func isCancelled() -> Bool {
        // Existing scan loops call this frequently, so it doubles as the
        // cooperative pause checkpoint.
        return token.waitIfPausedAndCheckCancelled()
    }

    private func emit(_ path: String, force: Bool) {
        guard let callback = callback else { return }

        let now = Date()
        if !force && now.timeIntervalSince(lastEmit) < 0.20 {
            return
        }
        lastEmit = now

        callback(
            LegacyScanProgress(
                phaseName: phaseName,
                currentPath: path,
                processedCount: processedCount,
                foundCount: foundCount,
                phaseIndex: phaseIndex,
                phaseCount: phaseCount
            )
        )
    }
}
