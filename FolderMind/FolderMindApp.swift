import SwiftUI

@main
struct FolderMindApp: App {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var ruleStore = RuleStore()
    @StateObject private var undoManager: FMUndoManager

    init() {
        _undoManager = StateObject(wrappedValue: FMUndoManager())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appVM.appState == .needsOnboarding {
                    TahoeWindowWrappers.onboardingView()
                        .environmentObject(appVM)
                } else {
                    TahoeWindowWrappers.mainWindowView()
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
