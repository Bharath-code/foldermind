import SwiftUI

struct StarterRule: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let description: String
    var isEnabled: Bool
    let color: Color
}

extension StarterRule {
    func asFMRule(watchedFolderURL: URL) -> FMRule {
        FMRule(
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
