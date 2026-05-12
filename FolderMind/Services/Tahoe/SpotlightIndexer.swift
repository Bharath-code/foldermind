import Foundation
import AppKit
import CoreSpotlight
import UniformTypeIdentifiers
import os

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

        let icon = NSWorkspace.shared.icon(forFile: destinationURL.path)
        attributeSet.thumbnailData = icon.tiffRepresentation
        attributeSet.path = destinationURL.path
        attributeSet.relatedUniqueIdentifier = entryID
        attributeSet.contentURL = URL(string: "foldermind://activity/\(entryID)")

        let item = CSSearchableItem(
            uniqueIdentifier: entryID,
            domainIdentifier: "app.foldermind.organized",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                Logger.spotlightIndexer.error("Spotlight indexing error: \(error.localizedDescription)")
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
        attributeSet.contentURL = URL(string: "foldermind://rule/\(rule.id.uuidString)")

        let item = CSSearchableItem(
            uniqueIdentifier: rule.id.uuidString,
            domainIdentifier: "app.foldermind.rules",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                Logger.spotlightIndexer.error("Rule indexing FAILED: \(error.localizedDescription)")
            } else {
                Logger.spotlightIndexer.info("Successfully indexed rule: \(rule.name)")
            }
        }
    }

    static func removeIndexedRule(ruleID: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [ruleID]) { error in
            if let error = error {
                Logger.spotlightIndexer.error("Rule deletion FAILED: \(error.localizedDescription)")
            }
        }
    }
}

extension Logger {
    static let spotlightIndexer = Logger(subsystem: "app.foldermind.mac", category: "SpotlightIndexer")
}
