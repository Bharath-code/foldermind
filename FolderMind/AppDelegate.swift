import Cocoa
import SwiftUI
import CoreSpotlight

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Any early initialization
        print("[AppDelegate] App launched.")
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("[AppDelegate] Preparing for graceful shutdown...")
        
        // We can access shared services here if needed, 
        // but FileWatchCoordinator is managed by SwiftUI views/lifecycle.
        // However, we can send a global notification to trigger stops if necessary.
        NotificationCenter.default.post(name: .appWillTerminate, object: nil)
        
        return .terminateNow
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            print("[AppDelegate] Opening URL: \(url.absoluteString)")
        }
    }
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        print("[AppDelegate] Continuing User Activity: \(userActivity.activityType)")
        
        if userActivity.activityType == CSSearchableItemActionType {
            if let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                print("[AppDelegate] Spotlight Identifier: \(identifier)")
                NotificationCenter.default.post(
                    name: .didSelectSpotlightItem,
                    object: identifier
                )
            }
        }
        
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app running in the menu bar even when the main window is closed.
        return false
    }
}

extension Notification.Name {
    static let appWillTerminate = Notification.Name("appWillTerminate")
    static let didSelectSpotlightItem = Notification.Name("didSelectSpotlightItem")
}
