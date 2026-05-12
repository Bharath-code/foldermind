import Foundation
import SwiftUI

@MainActor
class FMUndoManager: ObservableObject {
    @Published var entries: [ActivityEntry] = []
    @Published var canUndo: Bool = false

    private let storageURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("app.foldermind.mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storageURL = folder.appendingPathComponent("activity.json")
        loadEntries()
    }

    func logAction(_ entry: ActivityEntry) {
        withAnimation(.snappy) {
            entries.insert(entry, at: 0)
        }
        saveEntries()
    }

    func undoLatest() async {
        guard let entry = entries.first(where: { $0.canUndo && !$0.isUndone }) else { return }
        await performUndo(entry)
    }

    func undoAll() async {
        let undoable = entries.filter { $0.canUndo && !$0.isUndone }
        for entry in undoable {
            await performUndo(entry)
        }
    }

    func performUndo(_ entry: ActivityEntry) async {
        let fm = FileManager.default
        var updatedEntry = entry

        switch entry.actionType {
        case .moved:
            if fm.fileExists(atPath: entry.destinationURL.path) {
                do {
                    try fm.moveItem(at: entry.destinationURL, to: entry.sourceURL)
                    withAnimation(.snappy) {
                        updatedEntry.isUndone = true
                        updateEntry(updatedEntry)
                    }
                    SpotlightIndexer.removeIndexedFile(entryID: entry.id.uuidString)
                } catch {
                    // Handle error
                }
            }

        case .copied:
            if fm.fileExists(atPath: entry.destinationURL.path) {
                try? fm.removeItem(at: entry.destinationURL)
                withAnimation(.snappy) {
                    updatedEntry.isUndone = true
                    updateEntry(updatedEntry)
                }
                SpotlightIndexer.removeIndexedFile(entryID: entry.id.uuidString)
            }

        case .renamed, .deleted, .createdFolder:
            break
        }

        refreshUndoAvailability()
    }

    private func loadEntries() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) else {
            entries = []
            refreshUndoAvailability()
            return
        }

        entries = decoded.sorted { $0.timestamp > $1.timestamp }
        refreshUndoAvailability()
    }

    private func saveEntries() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try? encoder.encode(entries).write(to: storageURL)
        refreshUndoAvailability()
    }

    private func updateEntry(_ updatedEntry: ActivityEntry) {
        guard let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) else { return }
        entries[index] = updatedEntry
        saveEntries()
    }

    private func refreshUndoAvailability() {
        canUndo = entries.contains { $0.canUndo && !$0.isUndone }
    }

    func clearOlderThan(_ days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        entries.removeAll { $0.timestamp < cutoff }
        saveEntries()
    }
}
