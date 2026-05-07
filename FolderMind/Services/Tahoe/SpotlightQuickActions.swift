import AppKit

struct SpotlightQuickActions {
    static func registerOrganizeFolderActivity() {
        let activity = NSUserActivity(activityType: "app.foldermind.organizeFolder")
        activity.title = "Organize Folder with FolderMind"
        activity.isEligibleForSearch = true
        activity.persistentIdentifier = "organize-folder"
        activity.becomeCurrent()
    }

    static func registerToggleRuleActivity(rule: FMRule) {
        let activity = NSUserActivity(activityType: "app.foldermind.toggleRule")
        activity.title = "\(rule.isEnabled ? "Disable" : "Enable"): \(rule.name)"
        activity.isEligibleForSearch = true
        activity.userInfo = ["ruleID": rule.id.uuidString]
        activity.becomeCurrent()
    }

    static func handleUserActivity(_ activity: NSUserActivity) -> Bool {
        switch activity.activityType {
        case "app.foldermind.organizeFolder":
            return true
        case "app.foldermind.toggleRule":
            if let ruleID = activity.userInfo?["ruleID"] as? String {
                // Toggle rule logic
                return true
            }
            return false
        default:
            return false
        }
    }
}
