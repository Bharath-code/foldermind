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
        ZStack {
            // Background logic: Dark void with light leaks
            Color.black.ignoresSafeArea()
            
            // Prism Light Leaks
            Circle()
                .fill(FMDesign.Color.logicBlue.opacity(0.12))
                .frame(width: 800, height: 800)
                .blur(radius: 120)
                .offset(x: -300, y: -250)
            
            Circle()
                .fill(FMDesign.Color.logicMagenta.opacity(0.1))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: 400, y: 300)
            
            OnboardingCoordinatorView()
                .frame(width: 800, height: 600)
                .padding(40) // Generous safe area for rounded corners
        }
        .liquidGlass()
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .frame(width: 800, height: 600)
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
            .liquidGlass(radius: 0) // Edge-to-edge glass
            .ignoresSafeArea()
    }
}

struct MainWindowView_Legacy: View {
    var body: some View {
        MainWindowView()
    }
}
