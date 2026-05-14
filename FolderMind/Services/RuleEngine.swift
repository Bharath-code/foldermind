import Foundation
import AppKit

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

    func executeActions(_ actions: [RuleAction], for fileURL: URL) async -> ActionExecutionResult {
        print("[RuleEngine] Executing \(actions.count) actions for \(fileURL.lastPathComponent)")
        var destinationFolder = fileURL.deletingLastPathComponent()
        var newName: String? = nil
        var scheduledDeleteDate: Date? = nil

        for action in actions {
            switch action {
            case .moveToFolder(let folder):
                destinationFolder = folder
            case .copyToFolder(let folder):
                destinationFolder = folder
            case .renameWith(let template):
                newName = RenameEngine.apply(template: template, to: fileURL, date: Date())
            case .deleteAfterDays(let days):
                scheduledDeleteDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
            default:
                break
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
            let result = await performMove(src, dest, actions: actions)
            return ActionExecutionResult(outcome: result, scheduledDeleteDate: scheduledDeleteDate)
        case .skip:
            return ActionExecutionResult(outcome: .skipped("Already in correct location"), scheduledDeleteDate: nil)
        case .error(let msg):
            return ActionExecutionResult(outcome: .failed(msg), scheduledDeleteDate: nil)
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

        guard fm.fileExists(atPath: source.path) else {
            return .skipped("Source file no longer exists (likely already processed).")
        }

        let isCopy = actions.contains(where: { if case .copyToFolder = $0 { true } else { false } })

        do {
            if isCopy {
                print("[RuleEngine] Copying \(source.path) to \(destination.path)")
                try fm.copyItem(at: source, to: destination)
            } else {
                print("[RuleEngine] Moving \(source.path) to \(destination.path)")
                try fm.moveItem(at: source, to: destination)
            }
        } catch {
            return .failed(ErrorMapper.userFriendlyError(from: error))
        }

        let resultURL = destination

        for action in actions {
            switch action {
            case .addFinderTag(let tag):
                do {
                    try (resultURL as NSURL).setResourceValue([tag], forKey: .tagNamesKey)
                    print("[RuleEngine] Added Finder tag '\(tag)' to \(resultURL.lastPathComponent)")
                } catch {
                    print("[RuleEngine] Failed to add Finder tag '\(tag)': \(error.localizedDescription)")
                }
            case .openWithApp(let appURL):
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([resultURL], withApplicationAt: appURL, configuration: config) { _, error in
                    if let error = error {
                        print("[RuleEngine] Failed to open \(resultURL.lastPathComponent) with \(appURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            case .runShellScript(let script):
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", script]
                process.currentDirectoryURL = resultURL.deletingLastPathComponent()
                process.environment = ["FILE_PATH": resultURL.path, "FILE_NAME": resultURL.lastPathComponent]
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if process.terminationStatus != 0 {
                        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        print("[RuleEngine] Shell script failed (exit \(process.terminationStatus)): \(stderr)")
                    } else if !stdout.isEmpty {
                        print("[RuleEngine] Shell script output: \(stdout)")
                    }
                } catch {
                    print("[RuleEngine] Failed to run shell script: \(error.localizedDescription)")
                }
            default:
                break
            }
        }

        return isCopy ? .copied(resultURL) : .moved(resultURL)
    }

}

struct DryRunMatch: Identifiable {
    let id = UUID()
    let originalPath: URL
    let resultName: String
    let resultFolder: String
}

struct ActionExecutionResult: Sendable {
    let outcome: ActionResult
    let scheduledDeleteDate: Date?
}

enum ActionResult: Sendable {
    case moved(URL)
    case copied(URL)
    case skipped(String)
    case failed(String)
}
