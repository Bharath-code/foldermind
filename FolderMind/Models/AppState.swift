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
}
