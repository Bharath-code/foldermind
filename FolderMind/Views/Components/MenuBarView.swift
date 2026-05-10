import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FolderMind")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(ruleStore.rules.filter(\.isEnabled).count) active rules")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("Open FolderMind") {
                openWindow(id: "main")
            }
            
            Button("Settings...") {
                // In macOS 13+, Settings can be opened via a specific URL or via openSettings
                // If using macOS 14+, we can use openSettings. For 13+, NSApp.sendAction.
                if #available(macOS 14.0, *) {
                    // Fallback to sending action if openSettings not available in this scope
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }

            Divider()

            Button("Undo Last Action") {
                Task { await undoManager.undoLatest() }
            }
            .disabled(!undoManager.canUndo)

            Divider()

            Button("Quit FolderMind") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
    }
}
