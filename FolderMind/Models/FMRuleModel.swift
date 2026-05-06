import Foundation
import SwiftData

@Model
final class FMRuleModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var isEnabled: Bool
    var watchedFolderURL: URL
    var conditionsData: Data
    var conditionLogic: ConditionLogic
    var actionsData: Data
    var priority: Int
    var createdAt: Date
    var updatedAt: Date

    init(from rule: FMRule) {
        self.id = rule.id
        self.name = rule.name
        self.isEnabled = rule.isEnabled
        self.watchedFolderURL = rule.watchedFolderURL
        self.conditionLogic = rule.conditionLogic
        self.priority = rule.priority
        self.createdAt = Date()
        self.updatedAt = Date()

        let encoder = JSONEncoder()
        self.conditionsData = (try? encoder.encode(rule.conditions)) ?? Data()
        self.actionsData = (try? encoder.encode(rule.actions)) ?? Data()
    }

    func toFMRule() -> FMRule? {
        let decoder = JSONDecoder()
        guard let conditions = try? decoder.decode([RuleCondition].self, from: conditionsData),
              let actions = try? decoder.decode([RuleAction].self, from: actionsData) else {
            return nil
        }

        return FMRule(
            id: id,
            name: name,
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: conditions,
            conditionLogic: conditionLogic,
            actions: actions,
            priority: priority
        )
    }
}
