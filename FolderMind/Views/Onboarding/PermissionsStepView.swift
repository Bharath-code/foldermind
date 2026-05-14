import SwiftUI

struct PermissionsStepView: View {
    @State private var hasPermission = false
    @State private var showManualOption = false
    var onAdvance: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Hero Icon
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: hasPermission ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 280))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FMDesign.Color.logicBlue.opacity(0.12), FMDesign.Color.logicBlue.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .offset(x: 80, y: 40)
                        .rotationEffect(.degrees(5))
                }
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: FMDesign.Spacing.xl) {
                VStack(alignment: .leading, spacing: FMDesign.Spacing.sm) {
                    Text("System\nAccess.")
                        .fmMega()
                        .lineSpacing(-20)
                    
                    Text("FolderMind needs Full Disk Access to apply logic.\nYour files never leave your Mac — ever.")
                        .font(FMDesign.Font.headline())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: FMDesign.Spacing.lg) {
                    PermissionStep(number: 1, text: "Click \"Open System Settings\" below")
                    PermissionStep(number: 2, text: "Find FolderMind in the Full Disk Access list")
                    PermissionStep(number: 3, text: "Toggle it ON — then come back here")
                }

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    if hasPermission {
                        Label("Access granted", systemImage: "checkmark.circle.fill")
                            .font(FMDesign.Font.headline())
                            .foregroundStyle(.green)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    FMButton(hasPermission ? "Continue →" : "Open System Settings") {
                        if hasPermission {
                            onAdvance()
                        } else {
                            PermissionChecker.openSystemSettings()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation { showManualOption = true }
                            }
                        }
                    }

                    if showManualOption && !hasPermission {
                        FMButton("I've granted access — skip check", style: .ghost) {
                            onAdvance()
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(FMDesign.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { checkPermission() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermission()
        }
    }

    func checkPermission() {
        let granted = PermissionChecker.hasFullDiskAccess
        withAnimation { hasPermission = granted }
        if granted { onAdvance() }
    }
}

struct PermissionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: FMDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(FMDesign.Color.logicBlue.opacity(0.12))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(FMDesign.Font.caption())
                    .foregroundStyle(FMDesign.Color.logicBlue)
            }
            Text(text)
                .font(FMDesign.Font.body())
                .foregroundStyle(.secondary)
        }
    }
}
