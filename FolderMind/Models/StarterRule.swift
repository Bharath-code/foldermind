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
