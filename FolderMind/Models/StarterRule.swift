import SwiftUI

struct StarterRule: Identifiable {
    /// Deterministic ID derived from the rule name so the same starter rule
    /// always maps to the same UUID — prevents duplicates in RuleStore.
    var id: UUID { Self.deterministicUUID(for: name) }

    let icon: String
    let name: String
    let description: String
    var isEnabled: Bool
    let color: Color

    /// FNV-1a hash → UUID. Unlike Swift's Hasher, FNV-1a is fully deterministic
    /// across process launches (Hasher uses a random seed per run, which breaks persistence).
    static func deterministicUUID(for name: String) -> UUID {
        // FNV-1a 64-bit — deterministic, no external dependencies.
        let fnvOffset: UInt64 = 14_695_981_039_346_656_037
        let fnvPrime:  UInt64 = 1_099_511_628_211
        var hash = fnvOffset
        for byte in ("foldermind.starterrule." + name).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* fnvPrime
        }
        // Pack the 8-byte hash into a UUID (version/variant bits set for RFC 4122 v4).
        let b0 = UInt8((hash >> 56) & 0xFF); let b1 = UInt8((hash >> 48) & 0xFF)
        let b2 = UInt8((hash >> 40) & 0xFF); let b3 = UInt8((hash >> 32) & 0xFF)
        let b4 = UInt8((hash >> 24) & 0xFF); let b5 = UInt8((hash >> 16) & 0xFF)
        let b6 = UInt8((hash >>  8) & 0xFF); let b7 = UInt8( hash        & 0xFF)
        return UUID(uuid: (b0, b1, b2, b3, b4, b5,
                           (b6 & 0x0F) | 0x40,  // version 4
                           b7,
                           (b0 & 0x3F) | 0x80,  // variant 10xx
                           b1, b2, b3, b4, b5, b6, b7))
    }
}


extension StarterRule {
    func asFMRule(watchedFolderURL: URL) -> FMRule {
        FMRule(
            id: self.id, // Stable deterministic UUID — RuleStore.saveRule() will update, not append.
            name: name,
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: conditions,
            conditionLogic: .any,
            actions: [.moveToFolder(watchedFolderURL.appendingPathComponent(destinationFolder, isDirectory: true))],
            priority: priority
        )
    }

    var destinationFolder: String {
        switch name {
        case "Screenshots": return "Screenshots"
        case "Invoices & receipts": return "Finance"
        case "Archives": return "Archives"
        case "Photos & images": return "Photos"
        case "Videos": return "Videos"
        case "Documents": return "Documents"
        case "Disk images": return "Installers"
        case "Audio": return "Music"
        default: return name
        }
    }

    private var priority: Int {
        switch name {
        case "Screenshots": return 80
        case "Invoices & receipts": return 70
        case "Archives": return 60
        case "Documents": return 50
        default: return 10
        }
    }

    private var conditions: [RuleCondition] {
        switch name {
        case "Screenshots":
            return [.extensionIs(["png"]), .nameContains("screen shot"), .nameContains("screenshot")]
        case "Invoices & receipts":
            return [.extensionIs(["pdf"]), .nameContains("invoice"), .nameContains("receipt")]
        case "Archives":
            return [.extensionIs(["zip", "tar", "gz", "tgz", "rar", "7z"])]
        case "Photos & images":
            return [.extensionIs(["jpg", "jpeg", "heic", "webp", "gif", "tiff"])]
        case "Videos":
            return [.extensionIs(["mp4", "mov", "mkv", "avi", "webm"])]
        case "Documents":
            return [.extensionIs(["txt", "md", "rtf", "doc", "docx", "pages", "xls", "xlsx", "numbers", "key", "ppt", "pptx", "csv", "pdf"])]
        case "Disk images":
            return [.extensionIs(["dmg", "pkg"])]
        case "Audio":
            return [.extensionIs(["mp3", "m4a", "flac", "wav", "aac"])]
        default:
            return []
        }
    }
}

extension StarterRule {
    static let defaults: [StarterRule] = [
        StarterRule(icon: "camera.viewfinder",    name: "Screenshots",
                    description: "Move .png files with 'Screen Shot' in the name → Screenshots/",
                    isEnabled: true,  color: .blue),
        StarterRule(icon: "doc.text",             name: "Invoices & receipts",
                    description: "Move PDFs with 'invoice' or 'receipt' in the name → Finance/",
                    isEnabled: true,  color: .green),
        StarterRule(icon: "archivebox",            name: "Archives",
                    description: "Move .zip, .tar, .gz files → Archives/",
                    isEnabled: true,  color: .orange),
        StarterRule(icon: "photo.on.rectangle",   name: "Photos & images",
                    description: "Move .jpg .jpeg .heic files → Photos/",
                    isEnabled: false, color: .pink),
        StarterRule(icon: "play.rectangle",        name: "Videos",
                    description: "Move .mp4 .mov .mkv files → Videos/",
                    isEnabled: false, color: .purple),
        StarterRule(icon: "doc.richtext",          name: "Documents",
                    description: "Move .txt .md .docx .pages .xlsx .key files → Documents/",
                    isEnabled: true,  color: .teal),
        StarterRule(icon: "hammer",                name: "Disk images",
                    description: "Move .dmg .pkg installer files → Installers/",
                    isEnabled: false, color: .gray),
        StarterRule(icon: "music.note",            name: "Audio",
                    description: "Move .mp3 .m4a .flac files → Music/",
                    isEnabled: false, color: .red),
    ]
}
