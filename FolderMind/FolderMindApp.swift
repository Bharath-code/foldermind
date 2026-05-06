import SwiftUI
import SwiftData

@main
struct FolderMindApp: App {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var ruleStore: RuleStore
    @StateObject private var undoManager: FMUndoManager

    init() {
        let container = try! ModelContainer(
            for: ActivityEntry.self, FMRuleModel.self,
            configurations: ModelConfiguration(cloudKitDatabase: .none)
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

        MenuBarExtra {
            MenuBarView()
                .environmentObject(ruleStore)
                .environmentObject(undoManager)
        } label: {
            Image(systemName: "folder.fill.badge.gearshape")
        }
    }
}
