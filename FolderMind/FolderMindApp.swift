import SwiftUI

@main
struct FolderMindApp: App {
    @StateObject private var appVM = AppViewModel()
    // Single source-of-truth for both the view tree and the coordinator.
    // Previously there were two RuleStore instances: the default @StateObject
    // initialiser and a second one created inside init() — they were separate
    // objects, so rules saved in the UI never triggered file-watching. Fixed.
    @StateObject private var ruleStore: RuleStore
    @StateObject private var undoManager: FMUndoManager
    @StateObject private var watchCoordinator: FileWatchCoordinator

    init() {
        let store = RuleStore()
        let undo = FMUndoManager()
        let coordinator = FileWatchCoordinator(ruleStore: store, undoManager: undo)

        _ruleStore = StateObject(wrappedValue: store)
        _undoManager = StateObject(wrappedValue: undo)
        _watchCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appVM.appState == .needsOnboarding {
                    TahoeWindowWrappers.onboardingView()
                        .environmentObject(appVM)
                        .environmentObject(ruleStore)
                        .environmentObject(undoManager)
                } else {
                    TahoeWindowWrappers.mainWindowView()
                        .environmentObject(appVM)
                        .environmentObject(ruleStore)
                        .environmentObject(undoManager)
                        .environmentObject(watchCoordinator)
                        .onAppear { watchCoordinator.start() }
                        .onDisappear { watchCoordinator.stop() }
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
