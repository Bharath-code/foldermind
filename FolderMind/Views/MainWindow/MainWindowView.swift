import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager
    @EnvironmentObject var watchCoordinator: FileWatchCoordinator
    @EnvironmentObject var toastManager: ToastManager
    @State private var selection: MainWindowSection? = .rules
    @State private var ruleBuilderIntent: RuleBuilderIntent? = nil
    @State private var hasFDA: Bool = PermissionChecker.hasFullDiskAccess
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // FDA warning banner — shown when Full Disk Access is not granted.
                if !hasFDA {
                    FDAWarningBanner()
                }

                NavigationSplitView {
                    SidebarView(selection: $selection)
                        .environmentObject(watchCoordinator)
                        .environmentObject(toastManager)
                } detail: {
                    switch selection ?? .rules {
                    case .rules:
                        RuleListView(
                            onEdit: { rule in
                                // sheet(item:) guarantees the item is set BEFORE the
                                // sheet body is evaluated — no timing race with editingRule.
                                ruleBuilderIntent = .edit(rule)
                            },
                            onToggle: { ruleStore.toggleRule($0) },
                            onDelete: { ruleStore.deleteRule($0) }
                        )
                            .environmentObject(ruleStore)
                    case .activity:
                        ActivityFeedView()
                            .environmentObject(undoManager)
                    }
                }
                .navigationTitle("FolderMind")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Add Rule", systemImage: "plus") {
                            ruleBuilderIntent = .create
                        }
                    }
                }
                // sheet(item:) — the item IS the data, so no nil-capture race.
                .sheet(item: $ruleBuilderIntent) { intent in
                    RuleBuilderView(existingRule: intent.rule)
                        .id(intent.id) // Force fresh state initialization
                        .environmentObject(ruleStore)
                }
            }
            
            // Global Drop Zone Overlay
            if isDropTargeted {
                Color.black.opacity(0.4)
                    .background(.ultraThinMaterial)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white)
                                .shadow(radius: 10)
                            Text("Drop to Organize")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(radius: 10)
                        }
                    )
                    .ignoresSafeArea()
            }
            
            ToastContainerView(manager: toastManager)
        }
        .animation(.snappy, value: isDropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            let group = DispatchGroup()
            var droppedURLs: [URL] = []
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: NSURL.self) { item, _ in
                    if let url = item as? URL {
                        droppedURLs.append(url)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !droppedURLs.isEmpty {
                    Task {
                        await watchCoordinator.processDroppedFiles(droppedURLs)
                    }
                }
            }
            return true
        }
        // Poll FDA status every 2 seconds — banner disappears the moment FDA is granted.
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            hasFDA = PermissionChecker.hasFullDiskAccess
        }
    }
}

struct FDAWarningBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))

            Text("Full Disk Access is required for file watching to work.")
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Button("Grant Access") {
                PermissionChecker.openSystemSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }
}


enum MainWindowSection: String, CaseIterable, Identifiable, Hashable {
    case rules
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rules: return "Rules"
        case .activity: return "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .rules: return "list.bullet"
        case .activity: return "clock.arrow.circlepath"
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var watchCoordinator: FileWatchCoordinator
    @Binding var selection: MainWindowSection?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                ForEach(MainWindowSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if !LicenseManager.shared.isLicensed {
                    TrialStatusPill(daysRemaining: LicenseManager.shared.daysRemaining)
                        .padding(.vertical, 8)
                }
                Divider()
                Button {
                    Task {
                        await watchCoordinator.scanAllFolders()
                    }
                } label: {
                    Label("Scan All Folders", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .buttonStyle(.plain)
                .padding(12)
                .contentShape(Rectangle())
            }
        }
        .frame(minWidth: 180)
    }
}

struct RuleListView: View {
    @EnvironmentObject var ruleStore: RuleStore
    var onEdit: (FMRule) -> Void
    var onToggle: (FMRule) -> Void
    var onDelete: (FMRule) -> Void

    var body: some View {
        Group {
            if ruleStore.rules.isEmpty {
                ContentUnavailableView(
                    "No rules yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Create your first rule to start organising files automatically.")
                )
            } else {
                List(ruleStore.rules) { rule in
                    RuleRowView(
                        rule: rule,
                        onEdit: { onEdit(rule) },
                        onToggle: { onToggle(rule) },
                        onDelete: { onDelete(rule) }
                    )
                }
            }
        }
    }
}

struct ActivityFeedView: View {
    @EnvironmentObject var undoManager: FMUndoManager

    var body: some View {
        Group {
            if undoManager.entries.isEmpty {
                ContentUnavailableView(
                    "No activity yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("File operations will appear here as FolderMind organises your folders.")
                )
            } else {
                List {
                    ForEach(undoManager.entries) { entry in
                        ActivityRowView(entry: entry)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if undoManager.canUndo {
                    Button("Undo Last", systemImage: "arrow.uturn.backward") {
                        Task { await undoManager.undoLatest() }
                    }
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
                    .lineLimit(1)
                    .truncationMode(.middle)
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
        .padding(.vertical, 4)
        .onDrag {
            // Drag out of app
            NSItemProvider(object: entry.destinationURL as NSURL)
        }
    }

    private func iconForAction(_ action: ActionType) -> String {
        switch action {
        case .moved: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .renamed: return "pencil"
        case .deleted: return "trash"
        case .createdFolder: return "folder.badge.plus"
        }
    }

    private func colorForAction(_ action: ActionType) -> Color {
        switch action {
        case .moved: return .blue
        case .copied: return .purple
        case .renamed: return .orange
        case .deleted: return .red
        case .createdFolder: return .green
        }
    }
}

struct RuleRowView: View {
    let rule: FMRule
    var onEdit: () -> Void
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(rule.name)
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(priorityString(for: rule.priority))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .cornerRadius(4)
                }
                Text("\(rule.conditions.count) conditions · \(rule.actions.count) actions")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private func priorityString(for level: Int) -> String {
        switch level {
        case 5: return "HIGHEST"
        case 4: return "HIGH"
        case 3: return "NORMAL"
        case 2: return "LOW"
        case 1: return "LOWEST"
        default: return "P\(level)"
        }
    }
}

/// Drives the sheet(item:) presentation in MainWindowView.
enum RuleBuilderIntent: Identifiable {
    case create
    case edit(FMRule)

    var id: String {
        switch self {
        case .create: return "new-rule"
        case .edit(let rule): return rule.id.uuidString
        }
    }

    var rule: FMRule? {
        if case .edit(let rule) = self { return rule }
        return nil
    }
}
