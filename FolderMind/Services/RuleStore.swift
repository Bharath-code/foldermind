import Foundation
import SwiftData

@MainActor
class RuleStore: ObservableObject {
    @Published var rules: [FMRule] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRules()
    }

    func loadRules() {
        let descriptor = FetchDescriptor<FMRuleModel>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        rules = models.compactMap { $0.toFMRule() }
    }

    func saveRule(_ rule: FMRule) {
        if let existing = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[existing] = rule
        } else {
            rules.append(rule)
        }

        let model = FMRuleModel(from: rule)
        modelContext.insert(model)
        try? modelContext.save()
    }

    func deleteRule(_ rule: FMRule) {
        rules.removeAll { $0.id == rule.id }
        let descriptor = FetchDescriptor<FMRuleModel>(
            where: #Predicate<FMRuleModel> { $0.id == rule.id }
        )
        if let model = (try? modelContext.fetch(descriptor))?.first {
            modelContext.delete(model)
            try? modelContext.save()
        }
    }

    func toggleRule(_ rule: FMRule) {
        var updated = rule
        updated.isEnabled.toggle()
        saveRule(updated)
    }
}
