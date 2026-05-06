import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager

    var body: some View {
        VStack(spacing: 8) {
            Text("FolderMind")
                .font(.system(size: 13, weight: .semibold))

            Divider()

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
