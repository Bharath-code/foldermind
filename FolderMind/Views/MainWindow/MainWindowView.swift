import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(ruleStore)
        } detail: {
            RuleListView()
                .environmentObject(ruleStore)
        }
        .navigationTitle("FolderMind")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Rule", systemImage: "plus") {
                    // Add rule action
                }
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var ruleStore: RuleStore

    var body: some View {
        List {
            Label("Rules", systemImage: "list.bullet")
            Label("Activity", systemImage: "clock.arrow.circlepath")
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }
}

struct RuleListView: View {
    @EnvironmentObject var ruleStore: RuleStore

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
                    RuleRowView(rule: rule)
                }
            }
        }
    }
}

struct RuleRowView: View {
    let rule: FMRule

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
            Toggle("", isOn: .constant(rule.isEnabled))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 4)
    }
}
