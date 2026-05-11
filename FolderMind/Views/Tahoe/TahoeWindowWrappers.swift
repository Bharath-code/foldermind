import SwiftUI

struct TahoeWindowWrappers {
    /// Selects the appropriate onboarding view based on macOS version
    @ViewBuilder
    static func onboardingView() -> some View {
        if #available(macOS 26, *) {
            OnboardingWindowView_Tahoe()
        } else {
            OnboardingWindowView_Legacy()
        }
    }

    /// Selects the appropriate main window view based on macOS version
    @ViewBuilder
    static func mainWindowView() -> some View {
        if #available(macOS 26, *) {
            MainWindowView_Tahoe()
        } else {
            MainWindowView_Legacy()
        }
    }
}

// MARK: - Onboarding Views

@available(macOS 26, *)
struct OnboardingWindowView_Tahoe: View {
    var body: some View {
        OnboardingCoordinatorView()
            .padding(24)
    }
}

struct OnboardingWindowView_Legacy: View {
    var body: some View {
        OnboardingCoordinatorView()
    }
}

// MARK: - Main Window Views

@available(macOS 26, *)
struct MainWindowView_Tahoe: View {
    var body: some View {
        MainWindowView()
    }
}

struct MainWindowView_Legacy: View {
    var body: some View {
        MainWindowView()
    }
}
