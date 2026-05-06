import Foundation
import SwiftData

@Model
final class ActivityEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var ruleName: String
    var sourceURL: URL
    var destinationURL: URL
    var actionType: ActionType
    var canUndo: Bool
    var isUndone: Bool = false

    init(id: UUID = UUID(), timestamp: Date = Date(), ruleName: String,
         sourceURL: URL, destinationURL: URL, actionType: ActionType, canUndo: Bool = true) {
        self.id = id
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
