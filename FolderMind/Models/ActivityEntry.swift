import Foundation

struct ActivityEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var ruleName: String = ""
    var sourcePath: String = ""
    var destinationPath: String = ""
    var actionTypeRaw: String = ""
    var canUndo: Bool = true
    var isUndone: Bool = false

    var sourceURL: URL {
        get { URL(fileURLWithPath: sourcePath) }
        set { sourcePath = newValue.path }
    }

    var destinationURL: URL {
        get { URL(fileURLWithPath: destinationPath) }
        set { destinationPath = newValue.path }
    }

    var actionType: ActionType {
        get { ActionType(rawValue: actionTypeRaw) ?? .moved }
        set { actionTypeRaw = newValue.rawValue }
    }

    init() {}

    init(timestamp: Date = Date(), ruleName: String,
         sourceURL: URL, destinationURL: URL, actionType: ActionType, canUndo: Bool = true) {
        self.id = UUID()
        self.timestamp = timestamp
        self.ruleName = ruleName
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.actionType = actionType
        self.canUndo = canUndo
    }
}

enum ActionType: String, Codable {
    case moved, copied, renamed, deleted, createdFolder

    var displayName: String {
        switch self {
        case .moved: return "Moved"
        case .copied: return "Copied"
        case .renamed: return "Renamed"
        case .deleted: return "Deleted"
        case .createdFolder: return "Created folder"
        }
    }

    var reverseAction: ActionType? {
        switch self {
        case .moved: return .moved
        case .copied: return .deleted
        case .renamed: return nil
        case .deleted: return nil
        case .createdFolder: return nil
        }
    }
}
