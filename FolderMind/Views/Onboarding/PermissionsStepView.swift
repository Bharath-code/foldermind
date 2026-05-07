import SwiftUI

struct PermissionsStepView: View {
    @State private var hasPermission = false
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("One permission needed")
                    .font(.system(size: 22, weight: .semibold))
                Text("FolderMind needs to see your folders.\nYour files never leave your Mac — ever.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 10) {
                PermissionStep(number: 1, text: "Click \"Open System Settings\" below")
                PermissionStep(number: 2, text: "Find FolderMind in the list and toggle it on")
                PermissionStep(number: 3, text: "Come back here — it detects automatically")
            }
            .padding(.horizontal, 48)

            Spacer()

            VStack(spacing: 12) {
                if hasPermission {
                    Label("Permission granted", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                }

                Button(hasPermission ? "Continue" : "Open System Settings") {
                    if hasPermission {
                        onAdvance()
                    } else {
                        PermissionChecker.openSystemSettings()
                    }
                }
                .buttonStyle(FMPrimaryButtonStyle())
            }
            .padding(.bottom, 40)
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            checkPermission()
        }
    }

    func checkPermission() {
        let testPath = NSHomeDirectory() + "/Library"
        hasPermission = FileManager.default.isReadableFile(atPath: testPath)
        if hasPermission { onAdvance() }
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
