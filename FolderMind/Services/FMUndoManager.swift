import Foundation
import SwiftData

@MainActor
class FMUndoManager: ObservableObject {
    @Published var entries: [ActivityEntry] = []
    @Published var canUndo: Bool = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadEntries()
    }

    func logAction(_ entry: ActivityEntry) {
        modelContext.insert(entry)
        entries.insert(entry, at: 0)
        canUndo = entries.contains { $0.canUndo && !$0.isUndone }
        try? modelContext.save()
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

        switch entry.actionType {
        case .moved:
            if fm.fileExists(atPath: entry.destinationURL.path) {
                do {
                    try fm.moveItem(at: entry.destinationURL, to: entry.sourceURL)
                    entry.isUndone = true
                    try? modelContext.save()
                } catch {
                    // Handle error
                }
            }

        case .copied:
            if fm.fileExists(atPath: entry.destinationURL.path) {
                try? fm.removeItem(at: entry.destinationURL)
                entry.isUndone = true
                try? modelContext.save()
            }

        case .renamed, .deleted, .createdFolder:
            break
        }

        loadEntries()
    }

    private func loadEntries() {
        let descriptor = FetchDescriptor<ActivityEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
        canUndo = entries.contains { $0.canUndo && !$0.isUndone }
    }

    func clearOlderThan(_ days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<ActivityEntry>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        if let old = try? modelContext.fetch(descriptor) {
            for entry in old {
                modelContext.delete(entry)
            }
            try? modelContext.save()
        }
    }
}
