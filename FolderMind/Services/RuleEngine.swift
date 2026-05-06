import Foundation

actor RuleEngine {
    static let shared = RuleEngine()

    func evaluate(rule: FMRule, for fileURL: URL) -> Bool {
        let results = rule.conditions.map { condition in
            evaluateCondition(condition, for: fileURL)
        }
        return rule.conditionLogic == .all
            ? results.allSatisfy { $0 }
            : results.contains(true)
    }

    func dryRun(rule: FMRule, limit: Int = 10) async -> [DryRunMatch] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: rule.watchedFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }

        return contents
            .filter { evaluate(rule: rule, for: $0) }
            .prefix(limit)
            .map { url in
                let resultName = applyRenameActions(rule.actions, to: url)
                let resultFolder = applyMoveActions(rule.actions, to: url)
                return DryRunMatch(
                    originalPath: url,
                    resultName: resultName,
                    resultFolder: resultFolder
                )
            }
    }

    func executeActions(_ actions: [RuleAction], for fileURL: URL) async -> ActionResult {
        var finalURL = fileURL
        var destinationFolder = fileURL.deletingLastPathComponent()

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
                let newName = RenameEngine.apply(template: template, to: fileURL, date: Date())
                finalURL = fileURL.deletingLastPathComponent().appendingPathComponent(newName)
            }
        }

        let resolution = ConflictResolver.resolve(
            source: finalURL,
            destinationFolder: destinationFolder
        )

        switch resolution {
        case .move(let src, let dest):
            return await performMove(src, dest, actions: actions)
        case .skip:
            return .skipped("Already in correct location")
        case .error(let msg):
            return .failed(msg)
        }
    }

    private func evaluateCondition(_ condition: RuleCondition, for url: URL) -> Bool {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)

        switch condition {
        case .extensionIs(let exts):
            return exts.map { $0.lowercased() }.contains(ext)
        case .nameContains(let s):
            return name.localizedCaseInsensitiveContains(s)
        case .nameStartsWith(let s):
            return name.lowercased().hasPrefix(s.lowercased())
        case .nameEndsWith(let s):
            return name.lowercased().hasSuffix(s.lowercased())
        case .nameMatchesRegex(let pattern):
            return (try? NSRegularExpression(pattern: pattern)
                .firstMatch(in: name, range: NSRange(name.startIndex..., in: name))) != nil
        case .fileSizeGreaterThan(let bytes):
            let size = (attrs?[.size] as? Int) ?? 0
            return size > bytes
        case .fileSizeLessThan(let bytes):
            let size = (attrs?[.size] as? Int) ?? 0
            return size < bytes
        case .dateCreatedWithinDays(let days):
            let created = attrs?[.creationDate] as? Date ?? Date.distantPast
            return Date().timeIntervalSince(created) < Double(days) * 86400
        case .dateModifiedWithinDays(let days):
            let modified = attrs?[.modificationDate] as? Date ?? Date.distantPast
            return Date().timeIntervalSince(modified) < Double(days) * 86400
        case .isInSubfolder(let inSub):
            return inSub
        }
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
                try fm.copyItem(at: source, to: destination)
                return .copied(destination)
            } else {
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
