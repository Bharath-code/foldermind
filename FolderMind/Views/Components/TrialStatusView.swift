import SwiftUI

struct TrialStatusPill: View {
    let daysRemaining: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 10, weight: .bold))
            Text("\(daysRemaining) days left in trial")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .foregroundColor(.accentColor)
    }
}

struct TrialExpiredView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var licenseKey: String = ""
    @State private var showError: Bool = false
    @State private var isValidating: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
                
                Text("Trial Expired")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Your 7-day trial of FolderMind has ended.\nPlease enter your license key to continue automating your files.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Input
            VStack(alignment: .leading, spacing: 8) {
                TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(showError ? Color.red : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if showError {
                    Text("Invalid license key format. Please check and try again.")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: 400)
            
            // Actions
            VStack(spacing: 12) {
                Button(action: validateKey) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Text("Activate FolderMind")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: 400)
                }
                .buttonStyle(FMPrimaryButtonStyle())
                .disabled(licenseKey.isEmpty || isValidating)
                
                Link(destination: URL(string: "https://foldermind.app/buy")!) {
                    Text("Buy a License Key")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(64)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func validateKey() {
        isValidating = true
        showError = false
        
        // Artificial delay for premium feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if LicenseManager.shared.validate(key: licenseKey) {
                // Success - the parent view will detect the license change via state
                withAnimation {
                    // Trigger a re-render in the app
                    appVM.objectWillChange.send()
                }
            } else {
                showError = true
            }
            isValidating = false
        }
    }
}
