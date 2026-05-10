import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            LicenseSettingsView()
                .tabItem {
                    Label("License", systemImage: "key")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                if SMAppService.mainApp.status == .enabled { return }
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("[Settings] Failed to update launch at login: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Text("FolderMind will automatically start watching your folders when you log in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
    }
}

struct LicenseSettingsView: View {
    @State private var licenseKey: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        Form {
            Section {
                Text("Enter your license key to unlock FolderMind.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                TextField("e.g. XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: licenseKey) { _, _ in
                        errorMessage = nil // Clear error when typing
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                }
                
                HStack {
                    Spacer()
                    Button("Validate") {
                        if licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            errorMessage = "Please enter a valid license key."
                        } else {
                            // TODO: Implement actual license validation
                            errorMessage = "Invalid license key. Please try again."
                        }
                    }
                    .buttonStyle(FMPrimaryButtonStyle())
                }
                .padding(.top, 8)
            }
        }
        .padding(30)
    }
}
