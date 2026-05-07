import Foundation
import SwiftUI

@MainActor
class RuleStore: ObservableObject {
    @Published var rules: [FMRule] = []

    private let storageURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("app.foldermind.mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storageURL = folder.appendingPathComponent("rules.json")
        loadRules()
    }

    func loadRules() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([FMRule].self, from: data) else {
            rules = []
            return
        }
        rules = decoded
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try? encoder.encode(rules).write(to: storageURL)
    }

    func saveRule(_ rule: FMRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
        } else if let idx = rules.firstIndex(where: {
            $0.name == rule.name && $0.watchedFolderURL == rule.watchedFolderURL
        }) {
            rules[idx] = rule
        } else {
            rules.append(rule)
        }
        save()
    }

    func deleteRule(_ rule: FMRule) {
        rules.removeAll { $0.id == rule.id }
        save()
    }

    func toggleRule(_ rule: FMRule) {
        var updated = rule
        updated.isEnabled.toggle()
        saveRule(updated)
    }
}
