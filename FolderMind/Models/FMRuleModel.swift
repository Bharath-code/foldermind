import Foundation
import SwiftData

@Model
final class FMRuleModel {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var isEnabled: Bool = true
    var watchedFolderPath: String = ""
    var conditionsData: Data = Data()
    var conditionLogicRaw: String = "all"
    var actionsData: Data = Data()
    var priority: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var watchedFolderURL: URL {
        get { URL(fileURLWithPath: watchedFolderPath) }
        set { watchedFolderPath = newValue.path }
    }

    var conditionLogic: ConditionLogic {
        get { ConditionLogic(rawValue: conditionLogicRaw) ?? .all }
        set { conditionLogicRaw = newValue.rawValue }
    }

    init() {}

    convenience init(from rule: FMRule) {
        self.init()
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
