import Foundation

struct FMRule: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = true
    var watchedFolderURL: URL
    var conditions: [RuleCondition]
    var conditionLogic: ConditionLogic = .all
    var actions: [RuleAction]
    var priority: Int = 0
}

enum ConditionLogic: String, Codable { case all, any }

enum RuleCondition: Identifiable, Codable {
    var id: UUID { UUID() }

    case extensionIs([String])
    case nameContains(String)
    case nameStartsWith(String)
    case nameEndsWith(String)
    case nameMatchesRegex(String)
    case fileSizeGreaterThan(Int)
    case fileSizeLessThan(Int)
    case dateCreatedWithinDays(Int)
    case dateModifiedWithinDays(Int)
    case isInSubfolder(Bool)

    var displayName: String {
        switch self {
        case .extensionIs(let exts):         return "Extension is \(exts.joined(separator: ", "))"
        case .nameContains(let s):           return "Name contains \"\(s)\""
        case .nameStartsWith(let s):         return "Name starts with \"\(s)\""
        case .nameEndsWith(let s):           return "Name ends with \"\(s)\""
        case .nameMatchesRegex(let r):       return "Name matches /\(r)/"
        case .fileSizeGreaterThan(let b):    return "Larger than \(bytesDisplay(b))"
        case .fileSizeLessThan(let b):       return "Smaller than \(bytesDisplay(b))"
        case .dateCreatedWithinDays(let d):  return "Created within \(d) days"
        case .dateModifiedWithinDays(let d): return "Modified within \(d) days"
        case .isInSubfolder(let v):          return v ? "Is inside a subfolder" : "Is in the root folder"
        }
    }

    private func bytesDisplay(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

enum RuleAction: Identifiable, Codable {
    var id: UUID { UUID() }

    case moveToFolder(URL)
    case copyToFolder(URL)
    case renameWith(template: String)
    case addFinderTag(String)
    case runShellScript(String)
    case deleteAfterDays(Int)
    case openWithApp(URL)

    var displayName: String {
        switch self {
        case .moveToFolder(let url):         return "Move to \(url.lastPathComponent)"
        case .copyToFolder(let url):         return "Copy to \(url.lastPathComponent)"
        case .renameWith(let t):             return "Rename: \(t)"
        case .addFinderTag(let tag):         return "Add tag \"\(tag)\""
        case .runShellScript(let s):         return "Run script: \(s.prefix(20))…"
        case .deleteAfterDays(let d):        return "Delete after \(d) days"
        case .openWithApp(let url):          return "Open with \(url.lastPathComponent)"
        }
    }
}
