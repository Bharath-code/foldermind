import Foundation

struct FMRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = true
    var watchedFolderURL: URL
    var conditions: [RuleCondition]
    var conditionLogic: ConditionLogic = .all
    var actions: [RuleAction]
    var priority: Int = 0
}

enum ConditionLogic: String, Codable, Equatable { case all, any }

enum RuleCondition: Identifiable, Codable, Equatable {
    /// Stable, deterministic identity derived from the case discriminant + associated values.
    /// Using a computed property backed by a hash means equal conditions produce equal IDs
    /// across renders — fixing the SwiftUI `ForEach` diffing bug caused by `UUID()` each call.
    var id: UUID {
        var hasher = Hasher()
        switch self {
        case .extensionIs(let exts):           hasher.combine(0); hasher.combine(exts)
        case .nameContains(let s):             hasher.combine(1); hasher.combine(s)
        case .nameStartsWith(let s):           hasher.combine(2); hasher.combine(s)
        case .nameEndsWith(let s):             hasher.combine(3); hasher.combine(s)
        case .nameMatchesRegex(let r):         hasher.combine(4); hasher.combine(r)
        case .fileSizeGreaterThan(let b):      hasher.combine(5); hasher.combine(b)
        case .fileSizeLessThan(let b):         hasher.combine(6); hasher.combine(b)
        case .dateCreatedWithinDays(let d):    hasher.combine(7); hasher.combine(d)
        case .dateModifiedWithinDays(let d):   hasher.combine(8); hasher.combine(d)
        case .isInSubfolder(let v):            hasher.combine(9); hasher.combine(v)
        }
        let value = UInt64(bitPattern: Int64(hasher.finalize()))
        return UUID(uuid: (
            UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
            UInt8((value >> 32) & 0xFF), UInt8((value >> 40) & 0xFF),
            UInt8((value >> 48) & 0xFF), UInt8((value >> 56) & 0xFF),
            0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00
        ))
    }

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

enum RuleAction: Identifiable, Codable, Equatable {
    /// Stable identity derived from the case discriminant + associated values.
    /// Prevents SwiftUI `ForEach` from tearing down / re-inserting every row on each redraw.
    var id: UUID {
        var hasher = Hasher()
        switch self {
        case .moveToFolder(let url):       hasher.combine(0); hasher.combine(url.absoluteString)
        case .copyToFolder(let url):       hasher.combine(1); hasher.combine(url.absoluteString)
        case .renameWith(let t):           hasher.combine(2); hasher.combine(t)
        case .addFinderTag(let tag):       hasher.combine(3); hasher.combine(tag)
        case .runShellScript(let s):       hasher.combine(4); hasher.combine(s)
        case .deleteAfterDays(let d):      hasher.combine(5); hasher.combine(d)
        case .openWithApp(let url):        hasher.combine(6); hasher.combine(url.absoluteString)
        }
        let value = UInt64(bitPattern: Int64(hasher.finalize()))
        return UUID(uuid: (
            UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
            UInt8((value >> 32) & 0xFF), UInt8((value >> 40) & 0xFF),
            UInt8((value >> 48) & 0xFF), UInt8((value >> 56) & 0xFF),
            0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00
        ))
    }

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
