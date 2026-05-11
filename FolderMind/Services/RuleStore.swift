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
        // Group enabled rules at the top, then sort by priority within groups
        rules = decoded.sorted { 
            if $0.isEnabled != $1.isEnabled {
                return $0.isEnabled // true (on) comes before false (off)
            }
            return $0.priority > $1.priority
        }
    }

    func priorityString(for level: Int) -> String {
        if level >= 90 { return "HIGHEST" }
        if level >= 70 { return "HIGH" }
        if level >= 45 { return "NORMAL" }
        if level >= 25 { return "LOW" }
        return "LOWEST"
    }

    func save() {
        // Group enabled rules at the top before saving
        let sortedRules = rules.sorted { 
            if $0.isEnabled != $1.isEnabled {
                return $0.isEnabled
            }
            return $0.priority > $1.priority
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(sortedRules)
            try data.write(to: storageURL)
            print("[RuleStore] Successfully saved \(sortedRules.count) rules to \(storageURL.lastPathComponent)")
        } catch {
            print("[RuleStore] FAILED to save rules: \(error)")
        }
    }

    func moveRules(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        
        // Update priorities based on new order (0 to 100 scale)
        let count = rules.count
        for i in 0..<count {
            // The first item (index 0) gets 100, the last gets 0
            if count > 1 {
                rules[i].priority = 100 - Int((Double(i) / Double(count - 1)) * 100.0)
            } else {
                rules[i].priority = 100
            }
        }
        
        save()
    }

    func saveRule(_ rule: FMRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
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

    func duplicateRule(_ rule: FMRule) {
        var copy = rule
        copy.id = UUID()
        copy.name = "\(rule.name) (Copy)"
        
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules.insert(copy, at: idx + 1)
        } else {
            rules.append(copy)
        }
        save()
    }
    
    func importRules(_ newRules: [FMRule]) {
        for mutRule in newRules {
            var rule = mutRule
            // If ID already exists, regenerate it to avoid conflict
            if rules.contains(where: { $0.id == rule.id }) {
                rule.id = UUID()
            }
            rules.append(rule)
        }
        save()
    }
}
