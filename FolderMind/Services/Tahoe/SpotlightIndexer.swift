import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

struct SpotlightIndexer {
    static func indexOrganizedFile(
        sourceURL: URL,
        destinationURL: URL,
        ruleName: String,
        entryID: String
    ) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = destinationURL.lastPathComponent
        attributeSet.contentDescription = "Organized by FolderMind using rule: \(ruleName)"
        attributeSet.keywords = [
            "FolderMind",
            ruleName,
            "organized",
            destinationURL.deletingLastPathComponent().lastPathComponent
        ]
        attributeSet.path = destinationURL.path

        if let icon = NSWorkspace.shared.icon(forFile: destinationURL.path) {
            attributeSet.thumbnailData = icon.tiffRepresentation
        }

        let item = CSSearchableItem(
            uniqueIdentifier: entryID,
            domainIdentifier: "app.foldermind.organized",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                os_log("Spotlight indexing error: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }

    static func removeIndexedFile(entryID: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [entryID])
    }

    static func indexRule(_ rule: FMRule) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
        attributeSet.title = "FolderMind: \(rule.name)"
        attributeSet.contentDescription = "Rule: \(rule.conditions.map { $0.displayName }.joined(separator: ", "))"
        attributeSet.keywords = ["FolderMind", "rule", rule.name]

        let item = CSSearchableItem(
            uniqueIdentifier: rule.id.uuidString,
            domainIdentifier: "app.foldermind.rules",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item])
    }
}
