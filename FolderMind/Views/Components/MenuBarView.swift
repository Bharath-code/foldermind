import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager
    @EnvironmentObject var watchCoordinator: FileWatchCoordinator
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FolderMind")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if ruleStore.rules.filter(\.isEnabled).count > 0 {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Actions
            VStack(alignment: .leading, spacing: 4) {
                Button("Open FolderMind") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .keyboardShortcut("o")

                Button("Scan All Folders") {
                    Task { await watchCoordinator.scanAllFolders() }
                }
            }
            .padding(8)

            Divider()

            // Active Rules List
            VStack(alignment: .leading, spacing: 6) {
                Text("ACTIVE RULES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                let activeRules = ruleStore.rules.filter(\.isEnabled).prefix(5)
                if activeRules.isEmpty {
                    Text("No rules enabled")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                } else {
                    ForEach(activeRules) { rule in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 10))
                            Text(rule.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.vertical, 8)

            Divider()

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                if #available(macOS 14.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
            .padding(8)

            Button("Undo Last Action") {
                Task { await undoManager.undoLatest() }
            }
            .disabled(!undoManager.canUndo)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Divider()

            Button("Quit FolderMind") {
                NSApplication.shared.terminate(nil)
            }
            .padding(8)
        }
        .frame(width: 220)
    }
}
