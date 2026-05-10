import Foundation

actor RuleEngine {
    static let shared = RuleEngine()

    func evaluate(rule: FMRule, for fileURL: URL) -> Bool {
        let results = rule.conditions.map { condition in
            evaluateCondition(condition, for: fileURL, watchedFolder: rule.watchedFolderURL)
        }
        let finalMatch = rule.conditionLogic == .all
            ? results.allSatisfy { $0 }
            : results.contains(true)
        
        print("[RuleEngine] Evaluation: \(rule.name) on \(fileURL.lastPathComponent) -> \(finalMatch) (Logic: \(rule.conditionLogic), Individual results: \(results))")
        return finalMatch
    }

    func dryRun(rule: FMRule, limit: Int = 10) async -> [DryRunMatch] {
        var matches: [DryRunMatch] = []
        let enumerator = FileManager.default.enumerator(
            at: rule.watchedFolderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if matches.count >= limit { break }
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }
            
            if evaluate(rule: rule, for: fileURL) {
                let resultName = applyRenameActions(rule.actions, to: fileURL)
                let resultFolder = applyMoveActions(rule.actions, to: fileURL)
                matches.append(DryRunMatch(
                    originalPath: fileURL,
                    resultName: resultName,
                    resultFolder: resultFolder
                ))
            }
        }
        
        return matches
    }

    func executeActions(_ actions: [RuleAction], for fileURL: URL) async -> ActionResult {
        print("[RuleEngine] Executing \(actions.count) actions for \(fileURL.lastPathComponent)")
        var destinationFolder = fileURL.deletingLastPathComponent()
        var newName: String? = nil

        for action in actions {
            if case .moveToFolder(let folder) = action {
                destinationFolder = folder
            }
            if case .copyToFolder(let folder) = action {
                destinationFolder = folder
            }
        }

        for action in actions {
            if case .renameWith(let template) = action {
                newName = RenameEngine.apply(template: template, to: fileURL, date: Date())
            }
        }

        let source = fileURL
        let desiredName = newName ?? source.lastPathComponent

        let resolution = ConflictResolver.resolve(
            source: source,
            destinationFolder: destinationFolder,
            desiredName: desiredName
        )
        
        print("[RuleEngine] Action resolution for \(source.lastPathComponent): \(resolution)")

        switch resolution {
        case .move(let src, let dest):
            return await performMove(src, dest, actions: actions)
        case .skip:
            return .skipped("Already in correct location")
        case .error(let msg):
            return .failed(msg)
        }
    }

    private func evaluateCondition(_ condition: RuleCondition, for url: URL, watchedFolder: URL) -> Bool {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)

        let result: Bool
        switch condition {
        case .extensionIs(let exts):
            result = exts.map { $0.lowercased() }.contains(ext)
        case .nameContains(let s):
            result = name.localizedCaseInsensitiveContains(s)
        case .nameStartsWith(let s):
            result = name.lowercased().hasPrefix(s.lowercased())
        case .nameEndsWith(let s):
            result = name.lowercased().hasSuffix(s.lowercased())
        case .nameMatchesRegex(let pattern):
            result = (try? NSRegularExpression(pattern: pattern)
                .firstMatch(in: name, range: NSRange(name.startIndex..., in: name))) != nil
        case .fileSizeGreaterThan(let bytes):
            let size = (attrs?[.size] as? Int) ?? 0
            result = size > bytes
        case .fileSizeLessThan(let bytes):
            let size = (attrs?[.size] as? Int) ?? 0
            result = size < bytes
        case .dateCreatedWithinDays(let days):
            let created = attrs?[.creationDate] as? Date ?? Date.distantPast
            result = Date().timeIntervalSince(created) < Double(days) * 86400
        case .dateModifiedWithinDays(let days):
            let modified = attrs?[.modificationDate] as? Date ?? Date.distantPast
            result = Date().timeIntervalSince(modified) < Double(days) * 86400
        case .isInSubfolder(let shouldBeInSubfolder):
            let fileParent = url.deletingLastPathComponent().standardizedFileURL.path
            let watchedRoot = watchedFolder.standardizedFileURL.path
            let isActuallyInSubfolder = fileParent != watchedRoot
            result = isActuallyInSubfolder == shouldBeInSubfolder
        }
        
        print("[RuleEngine] Condition check: \(condition) against \(name) (ext: \(ext)) -> \(result)")
        return result
    }

    private func applyRenameActions(_ actions: [RuleAction], to url: URL) -> String {
        for action in actions {
            if case .renameWith(let template) = action {
                return RenameEngine.apply(template: template, to: url, date: Date())
            }
        }
        return url.lastPathComponent
    }

    private func applyMoveActions(_ actions: [RuleAction], to url: URL) -> String {
        for action in actions {
            if case .moveToFolder(let dest) = action {
                return dest.lastPathComponent
            }
        }
        return url.deletingLastPathComponent().lastPathComponent
    }

    private func performMove(_ source: URL, _ destination: URL, actions: [RuleAction]) async -> ActionResult {
        let fm = FileManager.default
        do {
            if actions.contains(where: { if case .copyToFolder = $0 { true } else { false } }) {
                print("[RuleEngine] Copying \(source.path) to \(destination.path)")
                try fm.copyItem(at: source, to: destination)
                return .copied(destination)
            } else {
                print("[RuleEngine] Moving \(source.path) to \(destination.path)")
                try fm.moveItem(at: source, to: destination)
                return .moved(destination)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

struct DryRunMatch: Identifiable {
    let id = UUID()
    let originalPath: URL
    let resultName: String
    let resultFolder: String
}

enum ActionResult: Sendable {
    case moved(URL)
    case copied(URL)
    case skipped(String)
    case failed(String)
}
