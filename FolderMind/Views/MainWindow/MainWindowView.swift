import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager
    @EnvironmentObject var watchCoordinator: FileWatchCoordinator
    @EnvironmentObject var toastManager: ToastManager
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
                    SidebarView(selection: $appVM.selectedSection)
                        .environmentObject(watchCoordinator)
                        .environmentObject(toastManager)
                } detail: {
                    Group {
                        switch appVM.selectedSection ?? .rules {
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
                    .id(appVM.selectedSection)
                }
                .navigationTitle("FolderMind")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Button(action: { RuleBackupManager.export(rules: ruleStore.rules) }) {
                                Label("Export Backup...", systemImage: "square.and.arrow.up")
                            }
                            Button(action: { 
                                RuleBackupManager.importRules { newRules in
                                    if let rules = newRules {
                                        ruleStore.importRules(rules)
                                    }
                                }
                            }) {
                                Label("Import Backup...", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Label("Backup", systemImage: "arrow.up.doc")
                        }
                        
                        if watchCoordinator.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        Button(action: {
                            ruleBuilderIntent = .create
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Add Rule")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.regular)
                    }
                }
                // sheet(item:) — the item IS the data, so no nil-capture race.
                .sheet(item: $ruleBuilderIntent) { intent in
                    RuleBuilderView(existingRule: intent.rule)
                        .id(intent.id) // Force fresh state initialization
                        .environmentObject(ruleStore)
                }
                .onChange(of: appVM.ruleToEditID) { oldValue, newValue in
                    if let id = newValue, let rule = ruleStore.rules.first(where: { $0.id == id }) {
                        ruleBuilderIntent = .edit(rule)
                        Task { @MainActor in
                            appVM.ruleToEditID = nil
                        }
                    }
                }
            }
            
            // Global Drop Zone Overlay
            if isDropTargeted {
                Color.black.opacity(0.4)
                    .background(.ultraThinMaterial)
                    .overlay(
                        VStack(spacing: FMDesign.Spacing.md) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white)
                                .shadow(radius: 10)
                            Text("Drop to Organize")
                                .fmTitle()
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
        // Check FDA status when the app becomes active, e.g., when returning from System Settings.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
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

struct SidebarView: View {
    @EnvironmentObject var watchCoordinator: FileWatchCoordinator
    @Binding var selection: MainWindowSection?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                ForEach(MainWindowSection.allCases) { section in
                    Label {
                        Text(section.title)
                            .font(.system(size: 14, weight: .medium))
                    } icon: {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 2)
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
    @EnvironmentObject var appVM: AppViewModel
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
                ScrollViewReader { proxy in
                    List {
                        ForEach(ruleStore.rules) { rule in
                            RuleRowView(
                                rule: rule,
                                onEdit: { onEdit(rule) },
                                onToggle: { onToggle(rule) },
                                onDuplicate: { ruleStore.duplicateRule(rule) },
                                onDelete: { onDelete(rule) }
                            )
                            .id(rule.id)
                            .listRowBackground(
                                appVM.highlightedRuleID == rule.id 
                                ? Color.accentColor.opacity(0.15) 
                                : nil
                            )
                        }
                        .onMove(perform: ruleStore.moveRules)
                    }
                    .task(id: appVM.highlightedRuleID) {
                        guard let id = appVM.highlightedRuleID else { return }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                        try? await Task.sleep(for: .seconds(2.5))
                        await MainActor.run { appVM.highlightedRuleID = nil }
                    }
                }
            }
        }
    }
}

struct ActivityFeedView: View {
    @EnvironmentObject var appVM: AppViewModel
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
                ScrollViewReader { proxy in
                    List {
                        ForEach(undoManager.entries) { entry in
                            ActivityRowView(entry: entry)
                                .id(entry.id)
                                .listRowBackground(
                                    appVM.highlightedEntryID == entry.id 
                                    ? Color.accentColor.opacity(0.15) 
                                    : nil
                                )
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .task(id: appVM.highlightedEntryID) {
                        guard let id = appVM.highlightedEntryID else { return }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                        try? await Task.sleep(for: .seconds(2.5))
                        await MainActor.run { appVM.highlightedEntryID = nil }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if undoManager.canUndo {
                    Button("Undo All") {
                        Task { await undoManager.undoAll() }
                    }
                    .help("Undo all operations in this list")
                }
                
                Button(action: {
                    undoManager.clearAll()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .help("Clear activity history")
            }
        }
    }
}

struct ActivityRowView: View {
    @EnvironmentObject var undoManager: FMUndoManager
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
                Text(ruleNameSnippet)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 60, alignment: .trailing)

            if entry.canUndo && !entry.isUndone {
                Button(action: {
                    Task { await undoManager.performUndo(entry) }
                }) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Undo this action")
            } else if entry.isUndone {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .help("Undone")
            }
        }
        .opacity(entry.isUndone ? 0.4 : 1.0)
        .grayscale(entry.isUndone ? 1.0 : 0.0)
        .padding(.vertical, 4)
        .onDrag {
            // Drag out of app
            NSItemProvider(object: entry.destinationURL as NSURL)
        }
    }

    private var ruleNameSnippet: String {
        entry.ruleName.count > 12 ? String(entry.ruleName.prefix(10)) + ".." : entry.ruleName
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
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            // Drag Handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(rule.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                    
                    Text(priorityString(for: rule.priority))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(for: rule.priority).opacity(0.15))
                        .foregroundStyle(priorityColor(for: rule.priority))
                        .cornerRadius(4)
                }
                Text(rule.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit) // Tap on text to edit

            Spacer()
            
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.7)

                Button(action: onDuplicate) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Duplicate Rule")
                .accessibilityLabel("Duplicate Rule")

                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete Rule")
                .accessibilityLabel("Delete Rule")
                .alert("Delete Rule?", isPresented: $showingDeleteAlert) {
                    Button("Delete", role: .destructive, action: onDelete)
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete '\(rule.name)'? This action cannot be undone.")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Duplicate", systemImage: "doc.on.doc", action: onDuplicate)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: { showingDeleteAlert = true })
        }
    }

    private func priorityString(for level: Int) -> String {
        if level >= 90 { return "HIGHEST" }
        if level >= 70 { return "HIGH" }
        if level >= 45 { return "NORMAL" }
        if level >= 25 { return "LOW" }
        return "LOWEST"
    }

    private func priorityColor(for level: Int) -> Color {
        if level >= 90 { return .purple }
        if level >= 70 { return .red }
        if level >= 45 { return .blue }
        if level >= 25 { return .orange }
        return .secondary
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
