import Foundation
import Combine

/// Owns one `FileWatcher` per unique watched-folder URL.
/// Reacts to `RuleStore.rules` changes to start/stop watchers automatically.
/// Routes incoming file events through `RuleEngine` → `FMUndoManager`.
@MainActor
final class FileWatchCoordinator: ObservableObject {

    // MARK: – Dependencies

    private let ruleStore: RuleStore
    private let undoManager: FMUndoManager

    // MARK: – State

    /// Active watchers keyed by the canonical watched-folder path.
    private var watchers: [String: FileWatcher] = [:]

    /// Combine subscription on `ruleStore.$rules`.
    private var rulesCancellable: AnyCancellable?

    /// Prevent re-entrant rebuilds while one is in flight.
    private var isRebuilding = false

    @Published private(set) var isWatching = false
    @Published private(set) var activeWatcherCount = 0

    // MARK: – Init

    init(ruleStore: RuleStore, undoManager: FMUndoManager) {
        self.ruleStore = ruleStore
        self.undoManager = undoManager
    }

    // MARK: – Lifecycle

    /// Call once after the app finishes launching / transitions to `.onboarded`.
    func start() {
        guard rulesCancellable == nil else { return }

        // Observe any rule mutation (save, delete, toggle).
        rulesCancellable = ruleStore.$rules
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildWatchers()
            }

        // Initial build.
        rebuildWatchers()
    }

    /// Call on app termination / when the user removes all watched folders.
    func stop() {
        rulesCancellable?.cancel()
        rulesCancellable = nil
        stopAllWatchers()
    }

    // MARK: – Watcher Graph

    /// Diff current watchers against the set of folders implied by enabled rules.
    /// Start new watchers, tear down orphans — never touches watchers whose folder
    /// is still relevant (FSEventStream is long-lived by design).
    private func rebuildWatchers() {
        guard !isRebuilding else { return }
        isRebuilding = true
        defer { isRebuilding = false }

        let enabledRules = ruleStore.rules.filter(\.isEnabled)

        // Unique folder paths that need a watcher.
        let desiredPaths = Set(enabledRules.map { $0.watchedFolderURL.standardizedFileURL.path })

        // 1. Remove watchers for folders no longer referenced.
        let orphanPaths = Set(watchers.keys).subtracting(desiredPaths)
        for path in orphanPaths {
            watchers[path]?.stop()
            watchers[path] = nil
        }

        // 2. Add watchers for new folders.
        for path in desiredPaths where watchers[path] == nil {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            let watcher = FileWatcher(watchedURL: url) { [weak self] events in
                await self?.handleEvents(events, folderURL: url)
            }
            do {
                try watcher.start()
                watchers[path] = watcher
            } catch {
                // TODO: surface in UI (#15.6 error states)
                print("[FileWatchCoordinator] Failed to start watcher for \(path): \(error)")
            }
        }

        activeWatcherCount = watchers.count
        isWatching = !watchers.isEmpty
    }

    private func stopAllWatchers() {
        for watcher in watchers.values {
            watcher.stop()
        }
        watchers.removeAll()
        activeWatcherCount = 0
        isWatching = false
    }

    // MARK: – Event Handling

    /// Called off-main by `FileWatcher.onChange`. Hops to main for state writes.
    private func handleEvents(_ events: [FileEvent], folderURL: URL) async {
        let enabledRules = await MainActor.run { ruleStore.rules.filter(\.isEnabled) }

        // Only rules whose watched folder matches this event source.
        let relevantRules = enabledRules
            .filter { $0.watchedFolderURL.standardizedFileURL == folderURL.standardizedFileURL }
            .sorted { $0.priority > $1.priority }

        guard !relevantRules.isEmpty else { return }

        let engine = RuleEngine.shared

        for event in events {
            // Only process new / modified files (not deletions or moves-away).
            guard event.type == .created || event.type == .modified else { continue }

            let fileURL = URL(fileURLWithPath: event.path)

            // Skip directories.
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: event.path, isDirectory: &isDir),
                  !isDir.boolValue else { continue }

            // First matching rule wins (priority-sorted).
            for rule in relevantRules {
                let matched = await engine.evaluate(rule: rule, for: fileURL)
                guard matched else { continue }

                let result = await engine.executeActions(rule.actions, for: fileURL)

                // Log to activity feed.
                await MainActor.run {
                    logResult(result, rule: rule, sourceURL: fileURL)
                }

                break // one rule per file event
            }
        }
    }

    /// Map an `ActionResult` into an `ActivityEntry` and push it to the undo stack.
    private func logResult(_ result: ActionResult, rule: FMRule, sourceURL: URL) {
        switch result {
        case .moved(let dest):
            let entry = ActivityEntry(
                ruleName: rule.name,
                sourceURL: sourceURL,
                destinationURL: dest,
                actionType: .moved
            )
            undoManager.logAction(entry)

        case .copied(let dest):
            let entry = ActivityEntry(
                ruleName: rule.name,
                sourceURL: sourceURL,
                destinationURL: dest,
                actionType: .copied
            )
            undoManager.logAction(entry)

        case .skipped:
            break // nothing to log

        case .failed(let msg):
            // TODO: surface in toast (#15.4)
            print("[FileWatchCoordinator] Action failed for \(sourceURL.lastPathComponent): \(msg)")
        }
    }
}
