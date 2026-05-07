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
    @EnvironmentObject var ruleStore: RuleStore
    @EnvironmentObject var undoManager: FMUndoManager
    @State private var selection: MainWindowSection? = .rules
    @State private var editingRule: FMRule?
    @State private var isShowingRuleBuilder = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection ?? .rules {
            case .rules:
                RuleListView(
                    onEdit: { rule in
                        editingRule = rule
                        isShowingRuleBuilder = true
                    },
                    onToggle: { ruleStore.toggleRule($0) },
                    onDelete: { ruleStore.deleteRule($0) }
                )
                    .environmentObject(ruleStore)
            case .activity:
                ActivityFeedView()
                    .environmentObject(undoManager)
            }
        }
        .navigationTitle("FolderMind")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Rule", systemImage: "plus") {
                    editingRule = nil
                    isShowingRuleBuilder = true
                }
            }
        }
        .sheet(isPresented: $isShowingRuleBuilder) {
            RuleBuilderView(existingRule: editingRule)
                .environmentObject(ruleStore)
        }
    }
}

struct MainWindowView_Legacy: View {
    var body: some View {
        MainWindowView()
    }
}
