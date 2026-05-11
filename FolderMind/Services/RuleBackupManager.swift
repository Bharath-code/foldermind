import Foundation
import AppKit
import UniformTypeIdentifiers

struct RuleBackupManager {
    static func export(rules: [FMRule]) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "FolderMind_Rules_Backup.json"
        savePanel.title = "Export Rules Backup"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(rules)
                    try data.write(to: url)
                    print("[RuleBackupManager] Exported \(rules.count) rules to \(url.path)")
                } catch {
                    print("[RuleBackupManager] Export FAILED: \(error)")
                }
            }
        }
    }
    
    static func importRules(completion: @escaping ([FMRule]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Import Rules Backup"
        
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let rules = try JSONDecoder().decode([FMRule].self, from: data)
                    print("[RuleBackupManager] Imported \(rules.count) rules from \(url.path)")
                    completion(rules)
                } catch {
                    print("[RuleBackupManager] Import FAILED: \(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }
}
