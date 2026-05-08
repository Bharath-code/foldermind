import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager
    @State private var selection: MainWindowSection? = .rules
    @State private var editingRule: FMRule?
    @State private var isShowingRuleBuilder = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection ?? .rules {
            case .rules:
                RuleListView(
                    onEdit: { rule in
                        editingRule = rule
                        isShowingRuleBuilder = true
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
                    editingRule = nil
                    isShowingRuleBuilder = true
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleBuilderView(existingRule: rule)
                .environmentObject(ruleStore)
                .id(rule.id) // Force fresh state for each rule
        }
        .sheet(isPresented: $isShowingRuleBuilder, onDismiss: { editingRule = nil }) {
            if editingRule == nil {
                RuleBuilderView(existingRule: nil)
                    .environmentObject(ruleStore)
                    .id("new-rule")
            }
        }
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
    @Binding var selection: MainWindowSection?

    var body: some View {
        List(selection: $selection) {
            ForEach(MainWindowSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
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
                Text(rule.name)
                    .font(.system(size: 13, weight: .medium))
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
