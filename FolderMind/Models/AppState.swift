import Foundation
import SwiftUI

enum AppState {
    case needsOnboarding
    case onboarded
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var appState: AppState = .needsOnboarding
    @Published private(set) var isActive = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    // Spotlight Navigation State
    @Published var selectedSection: MainWindowSection? = .rules
    @Published var highlightedRuleID: UUID? = nil
    @Published var highlightedEntryID: UUID? = nil
    @Published var ruleToEditID: UUID? = nil
    
    var ruleStore: RuleStore?
    var undoManager: FMUndoManager?

    init() {
        appState = hasCompletedOnboarding ? .onboarded : .needsOnboarding
        
        NotificationCenter.default.addObserver(forName: .didSelectSpotlightItem, object: nil, queue: .main) { [weak self] note in
            if let identifier = note.object as? String {
                Task { @MainActor [weak self] in
                    self?.handleSpotlightID(identifier)
                }
            }
        }
    }
    
    func setup(ruleStore: RuleStore, undoManager: FMUndoManager) {
        self.ruleStore = ruleStore
        self.undoManager = undoManager
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        appState = .onboarded
    }

    func appDidBecomeActive() {
        isActive = true
    }

    func appWillResignActive() {
        isActive = false
    }
    
    func handleSpotlightID(_ identifier: String) {
        guard let uuid = UUID(uuidString: identifier) else { return }
        print("[AppViewModel] Handling Spotlight ID: \(uuid)")
        
        NSApp.activate(ignoringOtherApps: true)
        
        if let ruleStore = ruleStore, ruleStore.rules.contains(where: { $0.id == uuid }) {
            print("[AppViewModel] Matched Rule: \(uuid)")
            self.selectedSection = .rules
            self.highlightedRuleID = uuid
            self.ruleToEditID = uuid
        } else if let undoManager = undoManager, let entry = undoManager.entries.first(where: { $0.id == uuid }) {
            print("[AppViewModel] Matched Activity Entry: \(uuid) -> \(entry.destinationURL.path)")
            self.selectedSection = .activity
            self.highlightedEntryID = uuid
            // Reveal in Finder
            NSWorkspace.shared.activateFileViewerSelecting([entry.destinationURL])
        } else {
            print("[AppViewModel] No match found. Rules: \(ruleStore?.rules.count ?? 0), Entries: \(undoManager?.entries.count ?? 0)")
            // Fallback: search in rules anyway
            self.selectedSection = .rules
            self.highlightedRuleID = uuid
        }
    }
}

enum MainWindowSection: String, CaseIterable, Identifiable, Hashable {
    case rules
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rules: return "Rules"
        case .activity: return "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .rules: return "list.bullet"
        case .activity: return "clock.arrow.circlepath"
        }
    }
}
