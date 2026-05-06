import Foundation

enum PermissionChecker {
    static var hasFullDiskAccess: Bool {
        let testURLs = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library"),
            URL(fileURLWithPath: "/Library"),
        ]
        return testURLs.allSatisfy {
            FileManager.default.isReadableFile(atPath: $0.path)
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
