import SwiftUI

struct OnboardingCoordinatorView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var ruleStore: RuleStore
    @State private var step: OnboardingStep = .welcome
    @State private var watchedFolderURL: URL? = nil
    @State private var enabledRules: [StarterRule] = StarterRule.defaults
    @State private var filesProcessed = 0

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeStepView { advance() }
            case .folderPicker:
                FolderPickerStepView(watchedFolderURL: $watchedFolderURL) { advance() }
            case .starterRules:
                StarterRulesStepView(rules: $enabledRules) { advance() }
            case .permissions:
                PermissionsStepView { advance() }
            case .processing:
                ProcessingStepView(
                    folderURL: watchedFolderURL!,
                    enabledRules: enabledRules.filter(\.isEnabled)
                ) { count in
                    filesProcessed = count
                    advance()
                }
            case .done:
                DoneStepView(
                    filesProcessed: filesProcessed,
                    minutesSaved: filesProcessed / 3
                ) {
                    saveStarterRules()
                    appVM.completeOnboarding()
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    func advance() {
        guard let nextStep = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation { step = nextStep }
    }

    private func saveStarterRules() {
        guard let watchedFolderURL else { return }

        for rule in enabledRules where rule.isEnabled {
            ruleStore.saveRule(rule.asFMRule(watchedFolderURL: watchedFolderURL))
        }
    }
}
