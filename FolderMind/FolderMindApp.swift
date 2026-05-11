import SwiftUI

@main
struct FolderMindApp: App {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var ruleStore: RuleStore
    @StateObject private var undoManager: FMUndoManager
    @StateObject private var watchCoordinator: FileWatchCoordinator
    @StateObject private var toastManager: ToastManager

    init() {
        let store = RuleStore()
        let undo = FMUndoManager()
        let toast = ToastManager()
        let coordinator = FileWatchCoordinator(ruleStore: store, undoManager: undo, toastManager: toast)

        _ruleStore = StateObject(wrappedValue: store)
        _undoManager = StateObject(wrappedValue: undo)
        _toastManager = StateObject(wrappedValue: toast)
        _watchCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if appVM.appState == .needsOnboarding {
                    TahoeWindowWrappers.onboardingView()
                        .environmentObject(appVM)
                        .environmentObject(ruleStore)
                        .environmentObject(undoManager)
                        .onboardingWindowStyle()
                } else {
                    if LicenseManager.shared.isTrialExpired {
                        TrialExpiredView()
                            .environmentObject(appVM)
                            .frame(minWidth: 800, minHeight: 500)
                    } else {
                        TahoeWindowWrappers.mainWindowView()
                            .environmentObject(appVM)
                            .environmentObject(ruleStore)
                            .environmentObject(undoManager)
                            .environmentObject(watchCoordinator)
                            .environmentObject(toastManager)
                            .frame(minWidth: 800, minHeight: 500)
                            .configureWindow { window in
                                // Ensure the main window is resizable and has controls
                                window.styleMask.insert([.resizable, .miniaturizable, .closable])
                                window.standardWindowButton(.closeButton)?.isHidden = false
                                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                                window.standardWindowButton(.zoomButton)?.isHidden = false
                            }
                            .onAppear {
                                watchCoordinator.start()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                                watchCoordinator.stop()
                            }
                            .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                                if PermissionChecker.hasFullDiskAccess {
                                    watchCoordinator.start()
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                                appVM.appDidBecomeActive()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                                appVM.appWillResignActive()
                            }
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(ruleStore)
                .environmentObject(undoManager)
        } label: {
            Image(systemName: "folder.fill.badge.gearshape")
        }
    }
}
