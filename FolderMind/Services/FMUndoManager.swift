import Foundation
import SwiftUI

@MainActor
class FMUndoManager: ObservableObject {
    @Published var entries: [ActivityEntry] = []
    @Published var canUndo: Bool = false
    @Published var lastUndoError: String?

    private let storageURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("app.foldermind.mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storageURL = folder.appendingPathComponent("activity.json")
        loadEntries()
        Task { await cleanupExpiredFiles() }
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
                    if !fm.fileExists(atPath: entry.destinationURL.path) {
                        withAnimation(.snappy) {
                            updatedEntry.isUndone = true
                            updateEntry(updatedEntry)
                        }
                        SpotlightIndexer.removeIndexedFile(entryID: entry.id.uuidString)
                    }
                } catch {
                    print("[FMUndoManager] Undo failed for \(entry.sourceURL.lastPathComponent): \(error.localizedDescription)")
                    lastUndoError = "Couldn't undo moving \(entry.sourceURL.lastPathComponent): \(ErrorMapper.userFriendlyError(from: error))"
                }
            } else {
                lastUndoError = "Can't undo — \(entry.sourceURL.lastPathComponent) is no longer in its organized location."
            }

        case .copied:
            if fm.fileExists(atPath: entry.destinationURL.path) {
                do {
                    try fm.removeItem(at: entry.destinationURL)
                    withAnimation(.snappy) {
                        updatedEntry.isUndone = true
                        updateEntry(updatedEntry)
                    }
                    SpotlightIndexer.removeIndexedFile(entryID: entry.id.uuidString)
                } catch {
                    print("[FMUndoManager] Undo copy failed for \(entry.sourceURL.lastPathComponent): \(error.localizedDescription)")
                    lastUndoError = "Couldn't undo copying \(entry.sourceURL.lastPathComponent): \(ErrorMapper.userFriendlyError(from: error))"
                }
            } else {
                lastUndoError = "Can't undo — the copy of \(entry.sourceURL.lastPathComponent) no longer exists."
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
        do {
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[FMUndoManager] Failed to save activity log: \(error.localizedDescription)")
        }
    }

    private func updateEntry(_ updatedEntry: ActivityEntry) {
        guard let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) else { return }
        entries[index] = updatedEntry
        saveEntries()
    }

    private func refreshUndoAvailability() {
        canUndo = entries.contains { $0.canUndo && !$0.isUndone }
    }

    func clearAll() {
        withAnimation {
            entries.removeAll()
        }
        saveEntries()
    }

    func clearOlderThan(_ days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        entries.removeAll { $0.timestamp < cutoff }
        saveEntries()
    }

    func cleanupExpiredFiles() async {
        let now = Date()
        let fm = FileManager.default
        var changed = false

        for i in 0..<entries.count {
            let entry = entries[i]
            guard let deleteAt = entry.scheduledDeleteDate,
                  deleteAt <= now,
                  !entry.isUndone,
                  !entry.isDeleted else { continue }

            let fileURL = entry.destinationURL

            guard fm.fileExists(atPath: fileURL.path) else {
                withAnimation(.snappy) {
                    entries[i].isDeleted = true
                }
                changed = true
                continue
            }

            let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
            if let modDate = attrs?[.modificationDate] as? Date,
               modDate > deleteAt {
                print("[FMUndoManager] Skipping deletion of \(fileURL.lastPathComponent) — modified after scheduled delete date")
                entries[i].scheduledDeleteDate = nil
                changed = true
                continue
            }

            do {
                try fm.removeItem(at: fileURL)
                print("[FMUndoManager] Deleted expired file: \(fileURL.lastPathComponent)")
                withAnimation(.snappy) {
                    entries[i].isDeleted = true
                }
                SpotlightIndexer.removeIndexedFile(entryID: entry.id.uuidString)
                changed = true
            } catch {
                print("[FMUndoManager] Failed to delete expired file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if changed {
            saveEntries()
        }
    }
}
