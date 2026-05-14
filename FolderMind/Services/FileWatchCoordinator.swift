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
    private let toastManager: ToastManager

    // MARK: – State

    /// Active watchers keyed by the canonical watched-folder path.
    private var watchers: [String: FileWatcher] = [:]

    /// Combine subscription on `ruleStore.$rules`.
    private var rulesCancellable: AnyCancellable?

    /// Prevent re-entrant rebuilds while one is in flight.
    private var isRebuilding = false

    @Published private(set) var isWatching = false
    @Published private(set) var activeWatcherCount = 0
    @Published private(set) var isProcessing = false
    private var processingCount = 0

    // MARK: – Init

    init(ruleStore: RuleStore, undoManager: FMUndoManager, toastManager: ToastManager) {
        self.ruleStore = ruleStore
        self.undoManager = undoManager
        self.toastManager = toastManager
    }

    // MARK: – Lifecycle

    /// Call once after the app finishes launching / transitions to `.onboarded`.
    func start() {
        guard rulesCancellable == nil else {
            return
        }

        // Log FDA status immediately — FSEventStream silently delivers zero events without it.
        PermissionChecker.logFDAStatus()
        print("[FileWatchCoordinator] Starting...")

        // The subscription delivers the current value immediately, debounced by 200ms.
        // This naturally triggers the first rebuild without needing a manual call.
        rulesCancellable = ruleStore.$rules
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildWatchers()
            }
    }

    /// Call on app termination / when the user removes all watched folders.
    func stop() {
        rulesCancellable?.cancel()
        rulesCancellable = nil
        stopAllWatchers()
        print("[FileWatchCoordinator] Stopped.")
    }

    /// Manually triggers a scan of all folders associated with enabled rules.
    /// This is a crucial fallback when FSEvents fails to deliver background notifications.
    func scanAllFolders() async {
        print("[FileWatchCoordinator] Manual scan of all folders started...")
        let allEnabledRules = ruleStore.rules.filter(\.isEnabled)
        let engine = RuleEngine.shared
        
        // 1. Get consolidated roots (same logic as rebuildWatchers)
        let allPaths = Set(allEnabledRules.map {
            $0.watchedFolderURL.resolvingSymlinksInPath().standardizedFileURL.path
        })
        var roots: [String] = []
        for path in allPaths.sorted(by: { $0.count < $1.count }) {
            if !roots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                roots.append(path)
            }
        }
        
        // 2. Scan each consolidated root
        for rootPath in roots {
            print("[FileWatchCoordinator] Recursively scanning root: \(rootPath)")
            let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
            
            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if Task.isCancelled { return }
                
                let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true { continue }
                
                // Find ALL enabled rules that apply to this file's location.
                let filePath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
                let relevantRules = allEnabledRules.filter { rule in
                    let rulePath = rule.watchedFolderURL.resolvingSymlinksInPath().standardizedFileURL.path
                    return filePath == rulePath || filePath.hasPrefix(rulePath + "/")
                }
                
                if !relevantRules.isEmpty {
                    await processFile(fileURL, rules: relevantRules.sorted { $0.priority > $1.priority }, engine: engine)
                }
            }
        }
        
        print("[FileWatchCoordinator] Manual scan completed.")
    }

    /// Processes files that are manually drag-and-dropped onto the app window.
    /// This bypasses the rule's `watchedFolderURL` and acts as a global drop zone,
    /// evaluating against all enabled rules sorted by priority.
    func processDroppedFiles(_ urls: [URL]) async {
        print("[FileWatchCoordinator] Processing \(urls.count) manually dropped files...")
        let allEnabledRules = ruleStore.rules.filter(\.isEnabled)
        let engine = RuleEngine.shared
        
        guard !allEnabledRules.isEmpty else {
            print("[FileWatchCoordinator] No enabled rules to process dropped files.")
            return
        }
        
        let sortedRules = allEnabledRules.sorted { $0.priority > $1.priority }
        
        for url in urls {
            // Check if it's a directory
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                print("[FileWatchCoordinator] Skipping directory drop: \(url.lastPathComponent)")
                continue
            }
            
            await processFile(url, rules: sortedRules, engine: engine)
        }
        print("[FileWatchCoordinator] Finished processing dropped files.")
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
        print("[FileWatchCoordinator] Rebuilding with \(enabledRules.count) enabled rules.")

        // 1. Get all unique, standardized paths from enabled rules.
        let allPaths = Set(enabledRules.map {
            $0.watchedFolderURL.resolvingSymlinksInPath().standardizedFileURL.path
        })

        // 2. Consolidate: If we watch /A, we don't need a separate watcher for /A/B.
        // This is much more robust for nested folder structures.
        var roots: [String] = []
        for path in allPaths.sorted(by: { $0.count < $1.count }) {
            if !roots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                roots.append(path)
            }
        }
        let desiredPaths = Set(roots)
        print("[FileWatchCoordinator] Consolidated watch roots: \(desiredPaths)")

        if !PermissionChecker.hasFullDiskAccess {
            print("[FileWatchCoordinator] ⚠️ FDA DENIED — FSEventStream will not fire reliably. Grant FDA in System Settings.")
        }

        // 3. Remove watchers for folders no longer needed.
        let orphanPaths = Set(watchers.keys).subtracting(desiredPaths)
        for path in orphanPaths {
            print("[FileWatchCoordinator] Stopping watcher for \(path)")
            watchers[path]?.stop()
            watchers[path] = nil
        }

        // 4. Add watchers for new roots.
        for path in desiredPaths where watchers[path] == nil {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            let watcher = FileWatcher(watchedURL: url) { [weak self] events in
                await self?.handleEvents(events, watchRoot: url)
            }
            do {
                try watcher.start()
                watchers[path] = watcher
                print("[FileWatchCoordinator] Started watcher for root: \(path)")
            } catch {
                print("[FileWatchCoordinator] Failed to start watcher for root \(path): \(error)")
            }
        }

        let newCount = watchers.count
        let newIsWatching = !watchers.isEmpty
        
        if activeWatcherCount != newCount || isWatching != newIsWatching {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.activeWatcherCount = newCount
                self.isWatching = newIsWatching
            }
        }
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

    /// Called by `FileWatcher.onChange`. Routes events through the rule engine.
    private func handleEvents(_ events: [FileEvent], watchRoot: URL) async {
        let enabledRules = ruleStore.rules.filter(\.isEnabled)
        
        // We now filter rules based on whether the event's folder is 
        // the rule's folder (or inside it, if we want recursive logic).
        // For now, we stick to "Rule applies to its specific folder".
        
        let engine = RuleEngine.shared

        for event in events {
            // Find rules that are actually interested in this specific file's parent folder.
            let eventFolder = URL(fileURLWithPath: event.path).deletingLastPathComponent().standardizedFileURL.path
            
            let relevantRules = enabledRules.filter { rule in
                let rulePath = rule.watchedFolderURL.resolvingSymlinksInPath().standardizedFileURL.path
                // Match if the event is in the rule's folder OR a subfolder.
                return eventFolder == rulePath || eventFolder.hasPrefix(rulePath + "/")
            }

            if relevantRules.isEmpty {
                // If it's a directory event, we scan the directory itself.
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: event.path, isDirectory: &isDir) && isDir.boolValue {
                    let dirURL = URL(fileURLWithPath: event.path, isDirectory: true)
                    let dirPath = dirURL.resolvingSymlinksInPath().standardizedFileURL.path
                    
                    // Rules that watch THIS exact directory.
                    let dirRules = enabledRules.filter { 
                        $0.watchedFolderURL.resolvingSymlinksInPath().standardizedFileURL.path == dirPath 
                    }
                    if !dirRules.isEmpty {
                        print("[FileWatchCoordinator] Directory event in watched folder: \(dirPath)")
                        await processRecentFiles(in: dirURL, rules: dirRules.sorted { $0.priority > $1.priority }, engine: engine)
                    }
                }
                continue
            }
            
            // Check if file still exists at the event path.
            // FSEvents often delivers 'moved' or 'deleted' notifications after the file is gone.
            // Silently ignoring these prevents confusing "Failed to process" toasts.
            guard FileManager.default.fileExists(atPath: event.path) else {
                continue
            }
            
            print("[FileWatchCoordinator] Event at \(event.path) -> \(relevantRules.count) relevant rules")
            await processFile(URL(fileURLWithPath: event.path), rules: relevantRules.sorted { $0.priority > $1.priority }, engine: engine)
        }
    }

    /// Scans `dirURL` for files added within the last 10 s and runs matching rules.
    private func processRecentFiles(in dirURL: URL, rules: [FMRule], engine: RuleEngine) async {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [.addedToDirectoryDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-10)
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .isDirectoryKey])
            guard values?.isDirectory == false else { continue }
            guard let added = values?.addedToDirectoryDate, added > cutoff else { continue }
            print("[FileWatchCoordinator] Recently added: \(url.lastPathComponent)")
            await processFile(url, rules: rules, engine: engine)
        }
    }

    /// Evaluates `rules` against `fileURL` in priority order — first match wins.
    private func processFile(_ fileURL: URL, rules: [FMRule], engine: RuleEngine) async {
        await MainActor.run {
            processingCount += 1
            if isProcessing != (processingCount > 0) { isProcessing = processingCount > 0 }
        }
        
        defer {
            Task { @MainActor in
                self.processingCount -= 1
                if self.isProcessing != (self.processingCount > 0) { self.isProcessing = self.processingCount > 0 }
            }
        }
        
        for rule in rules {
            print("[FileWatchCoordinator] Evaluating '\(rule.name)' against \(fileURL.lastPathComponent)")
            let matched = await engine.evaluate(rule: rule, for: fileURL)
            guard matched else { continue }

            let result = await engine.executeActions(rule.actions, for: fileURL)
            print("[FileWatchCoordinator] '\(rule.name)' → \(result)")

            await MainActor.run { logResult(result, rule: rule, sourceURL: fileURL) }
            
            // First matching rule wins. This is critical to prevent infinite loops 
            // when multiple rules match the same file and try to move it to different folders.
            break
        }
    }

    /// Map an `ActionResult` into an `ActivityEntry` and push it to the undo stack.
    private func logResult(_ result: ActionResult, rule: FMRule, sourceURL: URL) {
        switch result {
        case .moved(let dest):
            let entry = ActivityEntry(
                ruleName: rule.name, sourceURL: sourceURL, destinationURL: dest, actionType: .moved
            )
            undoManager.logAction(entry)
            SpotlightIndexer.indexOrganizedFile(
                sourceURL: sourceURL,
                destinationURL: dest,
                ruleName: rule.name,
                entryID: entry.id.uuidString
            )
            toastManager.showFileAction("Moved", filename: sourceURL.lastPathComponent, destination: dest.deletingLastPathComponent().lastPathComponent)
            
        case .copied(let dest):
            let entry = ActivityEntry(
                ruleName: rule.name, sourceURL: sourceURL, destinationURL: dest, actionType: .copied
            )
            undoManager.logAction(entry)
            SpotlightIndexer.indexOrganizedFile(
                sourceURL: sourceURL,
                destinationURL: dest,
                ruleName: rule.name,
                entryID: entry.id.uuidString
            )
            toastManager.showFileAction("Copied", filename: sourceURL.lastPathComponent, destination: dest.deletingLastPathComponent().lastPathComponent)
            
        case .skipped(let msg):
            print("[FileWatchCoordinator] Action skipped for \(sourceURL.lastPathComponent): \(msg)")
        case .failed(let msg):
            print("[FileWatchCoordinator] Action failed for \(sourceURL.lastPathComponent): \(msg)")
            toastManager.show("Failed: \(msg)", type: .error)
        }
    }
}

