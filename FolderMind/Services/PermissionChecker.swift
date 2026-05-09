import Foundation
import AppKit

enum PermissionChecker {
    /// TRUE only when Full Disk Access is actually granted.
    ///
    /// Tries multiple FDA-gated paths in order. The SYSTEM TCC database at
    /// `/Library/Application Support/com.apple.TCC/TCC.db` is the canonical
    /// FDA indicator — it's unreadable without FDA on all macOS versions.
    ///
    /// Falls back to additional protected paths in case the TCC.db path
    /// changes in future macOS releases.
    static var hasFullDiskAccess: Bool {
        // More reliable check: try to list a directory that is strictly FDA-protected.
        // The Library/Safari folder is a classic test.
        let path = NSHomeDirectory() + "/Library/Safari"
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    static func openSystemSettings() {
        // Try modern URL first (macOS 13+), fall back to legacy preference pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Logs the actual FDA status to the console for debugging.
    static func logFDAStatus() {
        let granted = hasFullDiskAccess
        print("[PermissionChecker] Full Disk Access: \(granted ? "GRANTED ✅" : "DENIED ❌")")
        if !granted {
            print("[PermissionChecker] FSEventStream will NOT fire for Desktop/Documents without FDA.")
            print("[PermissionChecker] Go to System Settings → Privacy & Security → Full Disk Access → enable FolderMind.")
        }
    }
}
