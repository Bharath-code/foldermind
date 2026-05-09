import SwiftUI

@main
struct FolderMindApp: App {
    @StateObject private var appVM = AppViewModel()
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
                        // Start the file watcher as a persistent background service.
                        // FSEventStream runs at the kernel level and is designed to work
                        // even when the app is not in the foreground — this is intentional.
                        .onAppear {
                            watchCoordinator.start()
                        }
                        // Stop only when the app actually terminates, not on focus loss.
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                            watchCoordinator.stop()
                        }
                        // Restart the watcher when FDA is granted mid-session
                        // (user grants it while the app is open).
                        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                            if PermissionChecker.hasFullDiskAccess {
                                watchCoordinator.start() // no-op if already running
                            }
                        }
                        // Keep tracking active state for any future UI needs (menu bar status, etc.)
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                            appVM.appDidBecomeActive()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                            appVM.appWillResignActive()
                        }
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
