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

    init() {
        appState = hasCompletedOnboarding ? .onboarded : .needsOnboarding
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
        if let uuid = UUID(uuidString: identifier) {
            highlightedRuleID = uuid
            highlightedEntryID = uuid
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
