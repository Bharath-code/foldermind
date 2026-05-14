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
#if DEBUG
            DebugSettingsView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
#endif
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var sparkleManager: SparkleManager
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
            
            Divider()
            
            Section {
                HStack {
                    Text("Updates")
                        .font(.headline)
                    Spacer()
                    Button("Check for Updates...") {
                        sparkleManager.checkForUpdates()
                    }
                    .disabled(!sparkleManager.canCheckForUpdates)
                }
                Text("FolderMind checks for updates automatically once per day.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
    }
}

struct LicenseSettingsView: View {
    @State private var licenseKey: String = ""
    @State private var statusMessage: String? = nil
    @State private var isValid: Bool? = nil

    var body: some View {
        Form {
            Section {
                if LicenseManager.shared.isLicensed {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("FolderMind is licensed.")
                            .font(.headline)
                    }
                    .padding(.bottom, 4)
                    
                    Text("Thank you for your purchase! You'll receive free updates for all 1.x versions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    Button("Remove License") {
                        LicenseManager.shared.revoke()
                        statusMessage = nil
                        isValid = nil
                        licenseKey = ""
                    }
                } else {
                    Text("Enter your license key to unlock FolderMind.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    TextField("e.g. FMLM-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: licenseKey) { _, _ in
                            statusMessage = nil
                            isValid = nil
                        }
                    
                    if let message = statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(isValid == true ? .green : .red)
                            .padding(.top, 2)
                    }
                    
                    HStack {
                        Spacer()
                        Button("Validate") {
                            let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if key.isEmpty {
                                statusMessage = "Please enter a license key."
                                isValid = false
                            } else if LicenseManager.shared.validate(key: key) {
                                statusMessage = "License activated! Thank you."
                                isValid = true
                            } else {
                                statusMessage = "Invalid license key. Expected format: FMLM-XXXX-XXXX-XXXX"
                                isValid = false
                            }
                        }
                        .buttonStyle(FMPrimaryButtonStyle())
                        .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(30)
    }
}

#if DEBUG
struct DebugSettingsView: View {
    @EnvironmentObject var appVM: AppViewModel
    
    var body: some View {
        Form {
            Section("Trial Debugging") {
                Button("Simulate Trial Expiry") {
                    LicenseManager.shared.simulateExpiry()
                    appVM.objectWillChange.send()
                }
                
                Button("Reset Trial & License") {
                    LicenseManager.shared.resetTrial()
                    appVM.objectWillChange.send()
                }
                
                Text("Changes will reflect immediately in the UI.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
    }
}
#endif
