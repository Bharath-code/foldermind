import SwiftUI

struct PermissionsStepView: View {
    @State private var hasPermission = false
    @State private var showManualOption = false
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: hasPermission ? "lock.shield.fill" : "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(hasPermission ? .green : .blue)
                .symbolRenderingMode(.hierarchical)
                .animation(.spring(duration: 0.4), value: hasPermission)

            VStack(spacing: 8) {
                Text("One permission needed")
                    .font(.system(size: 22, weight: .semibold))
                Text("FolderMind needs Full Disk Access to watch folders.\nYour files never leave your Mac — ever.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 10) {
                PermissionStep(number: 1, text: "Click \"Open System Settings\" below")
                PermissionStep(number: 2, text: "Find FolderMind in the Full Disk Access list")
                PermissionStep(number: 3, text: "Toggle it ON — then come back here")
            }
            .padding(.horizontal, 48)

            Spacer()

            VStack(spacing: 12) {
                if hasPermission {
                    Label("Full Disk Access granted", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }

                Button(hasPermission ? "Continue →" : "Open System Settings") {
                    if hasPermission {
                        onAdvance()
                    } else {
                        PermissionChecker.openSystemSettings()
                        // Show manual bypass after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation { showManualOption = true }
                        }
                    }
                }
                .buttonStyle(FMPrimaryButtonStyle())

                // Manual bypass — shown after user has opened Settings
                // Handles edge cases where auto-detection fails.
                if showManualOption && !hasPermission {
                    Button("I've granted access — skip check") {
                        onAdvance()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showManualOption)
            .padding(.bottom, 40)
        }
        .onAppear { checkPermission() }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
