# FolderMind — Technical Gap Fill

> Missing implementation details for core systems
> Version 1.0 · Supplements foldermind-complete-spec.md

---

## 1. FileWatcher — FSEvents Engine

### Architecture

```
FileWatcher (actor)
  ├── FSEventStream → raw filesystem events
  ├── EventDebouncer → coalesce bursts (e.g. git clone = 1000 events)
  ├── EventClassifier → create, modify, move, delete
  └── RuleMatcher → evaluate rules against classified events
```

### Implementation

```swift
// FileWatcher.swift

import Foundation

actor FileWatcher {
    private var streamRef: FSEventStreamRef?
    private let watchedURL: URL
    private let debouncer = EventDebouncer(window: 0.5)
    private var onChange: ([FileEvent]) async -> Void

    init(watchedURL: URL, onChange: @escaping ([FileEvent]) async -> Void) {
        self.watchedURL = watchedURL
        self.onChange = onChange
    }

    func start() throws {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let callback: FSEventStreamCallback = {
            _, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            let flags = eventFlags.withMemoryRebound(to: FSEventStreamEventFlags.self, capacity: numEvents) {
                Array(UnsafeBufferPointer(start: $0, count: numEvents))
            }

            Task {
                await self.handleEvents(paths: paths, flags: flags)
            }
        }

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagUseCFTypes)

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [watchedURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,  // latency in seconds
            flags
        )

        guard let stream = streamRef else {
            throw FileWatcherError.streamCreationFailed
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }

    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) async {
        let events = zip(paths, flags).compactMap { path, flag -> FileEvent? in
            FileEvent(path: path, flags: flag)
        }

        // Debounce: wait for burst to settle before processing
        let stableEvents = await debouncer.add(events)
        guard !stableEvents.isEmpty else { return }

        await onChange(stableEvents)
    }
}

// MARK: - Event Classification

struct FileEvent: Sendable {
    let path: String
    let type: EventType
    let timestamp: Date

    init?(path: String, flags: FSEventStreamEventFlags) {
        self.path = path
        self.timestamp = Date()

        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            self.type = .created
        } else if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            self.type = .deleted
        } else if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
            self.type = .modified
        } else if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            self.type = .moved
        } else {
            return nil  // ignore metadata-only events
        }
    }

    enum EventType: Sendable {
        case created, modified, moved, deleted
    }
}

// MARK: - Debouncer

actor EventDebouncer {
    private let window: TimeInterval
    private var buffer: [FileEvent] = []
    private var timerTask: Task<Void, Never>?

    init(window: TimeInterval) {
        self.window = window
    }

    func add(_ events: [FileEvent]) async -> [FileEvent] {
        buffer.append(contentsOf: events)
        timerTask?.cancel()
        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard !Task.isCancelled else { return }
        }
        try? await timerTask?.value
        let result = buffer
        buffer.removeAll()
        return result
    }
}

enum FileWatcherError: Error {
    case streamCreationFailed
}
```

### Key decisions

- **FSEvents over FolderWatcher**: Native, low-level, handles recursive watching
- **0.5s debounce window**: Catches bulk operations (copy/paste, git clone) without feeling laggy
- **Actor-based**: Thread-safe by default, no race conditions on rule evaluation
- **Ignore metadata-only events**: `.DS_Store`, xattr changes, Spotlight indexing noise

---

## 2. Conflict Resolution

### Scenarios

| Scenario | Strategy | User visible |
|---|---|---|
| File with same name exists in destination | Append `{counter}` | "invoice.pdf" → "invoice_001.pdf" |
| Destination folder doesn't exist | Create it automatically | Toast: "Created Finance/" |
| Two rules match same file | Priority order (higher wins) | Activity log shows which rule fired |
| File already in correct subfolder | Skip (no-op) | Nothing happens |
| Permission denied on destination | Skip + error toast | "Couldn't move X — permission denied" |
| Disk full during move | Abort + rollback partial | Toast + activity log entry |

### Implementation

```swift
// ConflictResolver.swift

import Foundation

struct ConflictResolver {
    enum Resolution {
        case move(URL, URL)           // original → destination
        case skip                     // no action needed
        case error(String)            // reason
    }

    static func resolve(
        source: URL,
        destinationFolder: URL,
        keepExtension: Bool = true
    ) -> Resolution {
        let fm = FileManager.default

        // Ensure destination folder exists
        if !fm.fileExists(atPath: destinationFolder.path) {
            do {
                try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            } catch {
                return .error("Couldn't create folder: \(error.localizedDescription)")
            }
        }

        var destination = destinationFolder.appendingPathComponent(source.lastPathComponent)

        // If file exists, find next available name
        if fm.fileExists(atPath: destination.path) {
            let name = source.deletingPathExtension().lastPathComponent
            let ext = keepExtension ? source.pathExtension : ""
            var counter = 1

            repeat {
                let newName = ext.isEmpty
                    ? "\(name)_\(String(format: "%03d", counter))"
                    : "\(name)_\(String(format: "%03d", counter)).\(ext)"
                destination = destinationFolder.appendingPathComponent(newName)
                counter += 1
            } while fm.fileExists(atPath: destination.path)
        }

        return .move(source, destination)
    }
}
```

### Rename integration with RuleEngine

```swift
// Inside RuleEngine.swift — apply actions with conflict resolution

func executeActions(_ actions: [RuleAction], for fileURL: URL) async -> ActionResult {
    var finalURL = fileURL
    var destinationFolder = fileURL.deletingLastPathComponent()

    // 1. Determine destination folder from actions
    for action in actions {
        if case .moveToFolder(let folder) = action {
            destinationFolder = folder
        }
        if case .copyToFolder(let folder) = action {
            destinationFolder = folder
        }
    }

    // 2. Apply rename if present
    for action in actions {
        if case .renameWith(let template) = action {
            let newName = RenameEngine.apply(template: template, to: fileURL, date: Date())
            finalURL = fileURL.deletingLastPathComponent().appendingPathComponent(newName)
        }
    }

    // 3. Resolve conflicts and execute
    let resolution = ConflictResolver.resolve(
        source: finalURL,
        destinationFolder: destinationFolder
    )

    switch resolution {
    case .move(let src, let dest):
        return await performMove(src, dest, actions: actions)
    case .skip:
        return .skipped("Already in correct location")
    case .error(let msg):
        return .failed(msg)
    }
}

private func performMove(_ source: URL, _ destination: URL, actions: [RuleAction]) async -> ActionResult {
    let fm = FileManager.default
    do {
        if actions.contains(where: { if case .copyToFolder = $0 { true } else { false } }) {
            try fm.copyItem(at: source, to: destination)
            return .copied(destination)
        } else {
            try fm.moveItem(at: source, to: destination)
            return .moved(destination)
        }
    } catch {
        return .failed(error.localizedDescription)
    }
}

enum ActionResult: Sendable {
    case moved(URL)
    case copied(URL)
    case skipped(String)
    case failed(String)
}
```

---

## 3. Undo System & Activity Log

### Architecture

```
ActivityLog (SwiftData)
  ├── ActivityEntry (one per file operation)
  │   ├── timestamp
  │   ├── ruleName
  │   ├── sourceURL
  │   ├── destinationURL
  │   ├── actionType (.moved, .copied, .renamed, .deleted)
  │   └── canUndo: Bool
  │
  └── UndoManager (NSUndoManager wrapper)
      ├── registerUndo(entry: ActivityEntry)
      ├── undoLatest() → reverses last N operations
      └── undoAll() → batch reverse
```

### SwiftData Model

```swift
// ActivityLog.swift

import Foundation
import SwiftData

@Model
final class ActivityEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var ruleName: String
    var sourceURL: URL
    var destinationURL: URL
    var actionType: ActionType
    var canUndo: Bool
    var isUndone: Bool = false

    init(id: UUID = UUID(), timestamp: Date = Date(), ruleName: String,
         sourceURL: URL, destinationURL: URL, actionType: ActionType, canUndo: Bool = true) {
        self.id = id
        self.timestamp = timestamp
        self.ruleName = ruleName
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.actionType = actionType
        self.canUndo = canUndo
    }
}

enum ActionType: String, Codable {
    case moved, copied, renamed, deleted, createdFolder

    var displayName: String {
        switch self {
        case .moved: return "Moved"
        case .copied: return "Copied"
        case .renamed: return "Renamed"
        case .deleted: return "Deleted"
        case .createdFolder: return "Created folder"
        }
    }

    var reverseAction: ActionType? {
        switch self {
        case .moved: return .moved  // move back
        case .copied: return .deleted  // delete the copy
        case .renamed: return nil  // need original name stored separately
        case .deleted: return nil  // can't undo delete without backup
        case .createdFolder: return nil  // only undo if empty
        }
    }
}
```

### Undo Manager

```swift
// FMUndoManager.swift

import Foundation
import SwiftData

@MainActor
class FMUndoManager: ObservableObject {
    @Published var entries: [ActivityEntry] = []
    @Published var canUndo: Bool = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadEntries()
    }

    func logAction(_ entry: ActivityEntry) {
        modelContext.insert(entry)
        entries.insert(entry, at: 0)
        canUndo = entries.contains { $0.canUndo && !$0.isUndone }
        try? modelContext.save()
    }

    func undoLatest() async {
        guard let entry = entries.first(where: { $0.canUndo && !$0.isUndone }) else { return }
        await performUndo(entry)
    }

    func undoAll() async {
        let undoable = entries.filter { $0.canUndo && !$0.isUndone }
        for entry in undoable {
            await performUndo(entry)
        }
    }

    private func performUndo(_ entry: ActivityEntry) async {
        let fm = FileManager.default

        switch entry.actionType {
        case .moved:
            // Move file back from destination to source
            if fm.fileExists(atPath: entry.destinationURL.path) {
                do {
                    try fm.moveItem(at: entry.destinationURL, to: entry.sourceURL)
                    entry.isUndone = true
                    try? modelContext.save()
                } catch {
                    // Handle error — file may have been modified
                }
            }

        case .copied:
            // Delete the copied file
            if fm.fileExists(atPath: entry.destinationURL.path) {
                try? fm.removeItem(at: entry.destinationURL)
                entry.isUndone = true
                try? modelContext.save()
            }

        case .renamed:
            // Requires storing original name — handled separately
            break

        case .deleted, .createdFolder:
            // Not undoable automatically
            break
        }

        loadEntries()
    }

    private func loadEntries() {
        let descriptor = FetchDescriptor<ActivityEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
        canUndo = entries.contains { $0.canUndo && !$0.isUndone }
    }

    func clearOlderThan(_ days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<ActivityEntry>(
            where: #Predicate<ActivityEntry> { $0.timestamp < cutoff }
        )
        if let old = try? modelContext.fetch(descriptor) {
            for entry in old {
                modelContext.delete(entry)
            }
            try? modelContext.save()
        }
    }
}
```

### Activity Feed UI

```swift
// ActivityFeedView.swift

import SwiftUI
import SwiftData

struct ActivityFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEntry.timestamp, order: .reverse) var entries: [ActivityEntry]
    @StateObject private var undoManager: FMUndoManager

    init(undoManager: FMUndoManager) {
        _undoManager = StateObject(wrappedValue: undoManager)
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No activity yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("File operations will appear here as FolderMind organises your folders.")
                )
            } else {
                ForEach(entries) { entry in
                    ActivityRowView(entry: entry)
                        .swipeActions(edge: .trailing) {
                            if entry.canUndo && !entry.isUndone {
                                Button("Undo", systemImage: "arrow.uturn.backward") {
                                    Task { await undoManager.performUndo(entry) }
                                }
                                .tint(.orange)
                            }
                        }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            if undoManager.canUndo {
                Button("Undo last", systemImage: "arrow.uturn.backward") {
                    Task { await undoManager.undoLatest() }
                }
            }
        }
    }
}

struct ActivityRowView: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForAction(entry.actionType))
                .foregroundStyle(colorForAction(entry.actionType))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.actionType.displayName): \(entry.sourceURL.lastPathComponent)")
                    .font(.system(size: 13))
                Text("→ \(entry.destinationURL.lastPathComponent)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.timestamp, style: .time)
                    .font(.system(size: 11))
                Text(entry.ruleName)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(entry.isUndone ? 0.5 : 1.0)
        .overlay {
            if entry.isUndone {
                Text("Undone")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    func iconForAction(_ action: ActionType) -> String {
        switch action {
        case .moved: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .renamed: return "pencil"
        case .deleted: return "trash"
        case .createdFolder: return "folder.badge.plus"
        }
    }

    func colorForAction(_ action: ActionType) -> Color {
        switch action {
        case .moved: return .blue
        case .copied: return .purple
        case .renamed: return .orange
        case .deleted: return .red
        case .createdFolder: return .green
        }
    }
}
```

---

## 4. Rule Persistence & Storage Strategy

### Decision matrix

| Storage | Use for | Why |
|---|---|---|
| `UserDefaults` | App settings, onboarding state, license key | Simple, fast, no schema |
| `SwiftData` | Rules, ActivityLog | Queryable, relationships, sorting |
| `JSON file` | Starter rule templates, backups | Portable, human-readable |

### Rule persistence

```swift
// RuleStore.swift

import Foundation
import SwiftData

@MainActor
class RuleStore: ObservableObject {
    @Published var rules: [FMRule] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRules()
    }

    func loadRules() {
        let descriptor = FetchDescriptor<FMRuleModel>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        rules = models.compactMap { $0.toFMRule() }
    }

    func saveRule(_ rule: FMRule) {
        if let existing = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[existing] = rule
        } else {
            rules.append(rule)
        }

        let model = FMRuleModel(from: rule)
        modelContext.insert(model)
        try? modelContext.save()
    }

    func deleteRule(_ rule: FMRule) {
        rules.removeAll { $0.id == rule.id }
        let descriptor = FetchDescriptor<FMRuleModel>(
            where: #Predicate<FMRuleModel> { $0.id == rule.id }
        )
        if let model = (try? modelContext.fetch(descriptor))?.first {
            modelContext.delete(model)
            try? modelContext.save()
        }
    }

    func toggleRule(_ rule: FMRule) {
        var updated = rule
        updated.isEnabled.toggle()
        saveRule(updated)
    }
}

// SwiftData model for rules

@Model
final class FMRuleModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var isEnabled: Bool
    var watchedFolderURL: URL
    var conditionsData: Data  // Codable [RuleCondition]
    var conditionLogic: ConditionLogic
    var actionsData: Data     // Codable [RuleAction]
    var priority: Int
    var createdAt: Date
    var updatedAt: Date

    init(from rule: FMRule) {
        self.id = rule.id
        self.name = rule.name
        self.isEnabled = rule.isEnabled
        self.watchedFolderURL = rule.watchedFolderURL
        self.conditionLogic = rule.conditionLogic
        self.priority = rule.priority
        self.createdAt = Date()
        self.updatedAt = Date()

        let encoder = JSONEncoder()
        self.conditionsData = (try? encoder.encode(rule.conditions)) ?? Data()
        self.actionsData = (try? encoder.encode(rule.actions)) ?? Data()
    }

    func toFMRule() -> FMRule? {
        let decoder = JSONDecoder()
        guard let conditions = try? decoder.decode([RuleCondition].self, from: conditionsData),
              let actions = try? decoder.decode([RuleAction].self, from: actionsData) else {
            return nil
        }

        return FMRule(
            id: id,
            name: name,
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: conditions,
            conditionLogic: conditionLogic,
            actions: actions,
            priority: priority
        )
    }
}
```

### Why encode conditions/actions as Data?

- `RuleCondition` and `RuleAction` are enums with associated values — SwiftData doesn't support these natively
- JSON encoding is reliable and versionable
- Can add migration logic when new condition/action types are added
- Trade-off: can't query "all rules that move to folder X" — but you don't need to

### Backup/Export

```swift
// RuleBackup.swift

struct RuleBackup: Codable {
    let version: String
    let exportedAt: Date
    let rules: [FMRule]
}

enum RuleBackupManager {
    static func export(rules: [FMRule]) -> URL? {
        let backup = RuleBackup(
            version: "1.0",
            exportedAt: Date(),
            rules: rules
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(backup) else { return nil }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "FolderMind-rules-\(Date().ISO8601).json"
        panel.title = "Export Rules"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try? data.write(to: url)
        return url
    }

    static func importRules(from url: URL) -> [FMRule]? {
        guard let data = try? Data(contentsOf: url),
              let backup = try? JSONDecoder().decode(RuleBackup.self, from: data) else {
            return nil
        }
        return backup.rules
    }
}
```

---

## 5. Sandbox vs Full Disk Access — Distribution Strategy

### Two paths

| Path | Pros | Cons |
|---|---|---|
| **Outside Mac App Store** (direct sales) | Full Disk Access via prompt, no sandbox, no review | Users trust .dmg less, no App Store discoverability |
| **Mac App Store** | Trust, discoverability, auto-updates | Sandboxed, needs user to manually grant folder access per-folder |

### Recommendation: Start outside MAS, add MAS later

**Phase 1 — Direct ($14.99 via Gumroad/Paddle):**
- Not sandboxed
- Request Full Disk Access at onboarding (as spec'd)
- Can watch any folder the user picks
- Faster iteration, no review delays

**Phase 2 — MAS (optional, later):**
- Sandboxed
- Use `NSOpenPanel` with `accessingSecurityScopedResource()` for each watched folder
- User must re-grant access after app restart (bookmark persistence helps)
- Limited to folders user explicitly selects

### Full Disk Access implementation (Phase 1)

```swift
// PermissionChecker.swift

import Foundation

enum PermissionChecker {
    static var hasFullDiskAccess: Bool {
        // Try reading a known protected path
        let testURLs = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library"),
            URL(fileURLWithPath: "/Library"),
            URL(fileURLWithPath: "~/Library/Application Support/com.apple.TCC"),
        ]
        return testURLs.allSatisfy {
            FileManager.default.isReadableFile(atPath: $0.path)
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
```

### Security-scoped bookmarks (Phase 2 — MAS)

```swift
// BookmarkManager.swift

import Foundation

enum BookmarkManager {
    static func createBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    static func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    static func stopAccessingSecurityScopedResource(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
```

### Entitlements for Phase 1 (non-sandboxed)

```xml
<!-- FolderMind.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Info.plist keys needed

```xml
<!-- Info.plist -->
<key>NSFullDiskAccessUsageDescription</key>
<string>FolderMind needs Full Disk Access to watch and organise your folders. Your files never leave your Mac.</string>
```

---

## 6. Additional Gaps Filled

### 6.1. App Lifecycle

```swift
// FolderMindApp.swift

import SwiftUI
import SwiftData

@main
struct FolderMindApp: App {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var ruleStore: RuleStore
    @StateObject private var undoManager: FMUndoManager
    @State private var fileWatcher: FileWatcher?

    init() {
        let container = try! ModelContainer(
            for: ActivityEntry.self, FMRuleModel.self,
            configurations: ModelConfiguration(
                cloudKitDatabase: .none  // local only
            )
        )
        let context = container.mainContext
        _ruleStore = StateObject(wrappedValue: RuleStore(modelContext: context))
        _undoManager = StateObject(wrappedValue: FMUndoManager(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appVM.appState == .needsOnboarding {
                    OnboardingCoordinatorView()
                        .environmentObject(appVM)
                } else {
                    MainWindowView()
                        .environmentObject(appVM)
                        .environmentObject(ruleStore)
                        .environmentObject(undoManager)
                }
            }
            .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Activity Log") {
                    openActivityWindow()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(ruleStore)
                .environmentObject(undoManager)
        } label: {
            Image(systemName: "folder.fill.badge.gearshape")
        }
    }

    func openActivityWindow() {
        // Open separate window for activity feed
    }
}
```

### 6.2. Menu Bar Integration

```swift
// MenuBarView.swift

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager

    var body: some View {
        VStack(spacing: 8) {
            Text("FolderMind")
                .font(.system(size: 13, weight: .semibold))

            Divider()

            // Active rules summary
            ForEach(ruleStore.rules.filter(\.isEnabled)) { rule in
                Label(rule.name, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
            }

            Divider()

            Button("Undo last action") {
                Task { await undoManager.undoLatest() }
            }
            .disabled(!undoManager.canUndo)

            Button("Open Activity Log") {
                // Open main window
            }

            Divider()

            Button("Quit FolderMind") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
    }
}
```

### 6.3. License System (One-time $14.99)

```swift
// LicenseManager.swift

import Foundation

struct LicenseManager {
    static let shared = LicenseManager()

    private let userDefaults = UserDefaults.standard
    private let licenseKeyKey = "foldermind_license_key"
    private let licensedAtKey = "foldermind_licensed_at"

    var isLicensed: Bool {
        userDefaults.string(forKey: licenseKeyKey) != nil
    }

    func validate(key: String) -> Bool {
        // Simple check — for production, use Paddle/Gumroad SDK
        // or validate against your own server
        guard key.count == 24 else { return false }
        guard key.contains("-") else { return false }

        // Store on success
        userDefaults.set(key, forKey: licenseKeyKey)
        userDefaults.set(Date(), forKey: licensedAtKey)
        return true
    }

    func revoke() {
        userDefaults.removeObject(forKey: licenseKeyKey)
        userDefaults.removeObject(forKey: licensedAtKey)
    }
}
```

---

## Summary of decisions

| Area | Decision | Rationale |
|---|---|---|
| File watching | FSEvents + debouncing | Native, handles bursts, low CPU |
| Conflict resolution | Counter-based rename | Predictable, no data loss |
| Undo system | SwiftData + reverse operations | Queryable, persistent across launches |
| Rule storage | SwiftData (JSON-encoded enums) | SwiftData doesn't support enums with associated values |
| Activity log | SwiftData | Needs sorting, filtering, pagination |
| Distribution | Start non-sandboxed, MAS later | Faster iteration, Full Disk Access is simpler |
| License | UserDefaults + Paddle/Gumroad | One-time purchase, no account needed |
| Rename tokens | Template engine with `{date}`, `{name}`, etc. | Flexible, user-friendly |
| Dry-run | Debounced 400ms, max 10 results | Fast enough to feel live, not wasteful |
