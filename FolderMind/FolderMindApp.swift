import SwiftUI
import CoreSpotlight

@main
struct FolderMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            mainView
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    print("[FolderMindApp] Received user activity: \(userActivity.activityType)")
                    NSApp.activate(ignoringOtherApps: true)
                    
                    if let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                       let uuid = UUID(uuidString: identifier) {
                        
                        if ruleStore.rules.contains(where: { $0.id == uuid }) {
                            appVM.selectedSection = .rules
                            appVM.highlightedRuleID = uuid
                            appVM.ruleToEditID = uuid
                        } else if undoManager.entries.contains(where: { $0.id == uuid }) {
                            appVM.selectedSection = .activity
                            appVM.highlightedEntryID = uuid
                        }
                    }
                }
                .onOpenURL { url in
                    print("[FolderMindApp] Received URL: \(url.absoluteString)")
                    NSApp.activate(ignoringOtherApps: true)
                    
                    let host = url.host
                    let idString = url.lastPathComponent
                    
                    if let uuid = UUID(uuidString: idString) {
                        if host == "rule" {
                            appVM.selectedSection = .rules
                            appVM.highlightedRuleID = uuid
                        } else if host == "activity" {
                            appVM.selectedSection = .activity
                            appVM.highlightedEntryID = uuid
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(ruleStore)
                .environmentObject(undoManager)
                .environmentObject(watchCoordinator)
        } label: {
            Image(systemName: "folder.fill.badge.gearshape")
        }
    }

    @ViewBuilder
    private var mainView: some View {
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
                            window.styleMask.insert([.resizable, .miniaturizable, .closable])
                            window.standardWindowButton(.closeButton)?.isHidden = false
                            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                            window.standardWindowButton(.zoomButton)?.isHidden = false
                        }
                        .onAppear {
                            watchCoordinator.start()
                            appVM.setup(ruleStore: ruleStore, undoManager: undoManager)
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
}
