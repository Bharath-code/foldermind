import Foundation

enum AppState {
    case needsOnboarding
    case onboarded
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var appState: AppState = .needsOnboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    init() {
        appState = hasCompletedOnboarding ? .onboarded : .needsOnboarding
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        appState = .onboarded
    }
}
