# FolderMind — Complete Design & Build Spec

> Version 1.0 · Solo build · macOS 13+ · One-time $14.99

---

## Table of Contents

1. [Onboarding Flow — SwiftUI Spec](#1-onboarding-flow--swiftui-spec)
2. [Rule Builder — Interaction Model](#2-rule-builder--interaction-model)
3. [Landing Page — Full Copy & Structure](#3-landing-page--full-copy--structure)

---

# 1. Onboarding Flow — SwiftUI Spec

## Overview

Onboarding has one job: get the user to their first "holy sh*t" moment before they close the window. Target: **under 90 seconds from launch to first file sorted.**

No email capture. No account creation. No tutorial video. **Pure action.**

---

## State Machine

```
AppState
  ├── .needsOnboarding       → show OnboardingView
  ├── .onboarded             → show MainWindowView
  └── .licensed(key: String) → stored in UserDefaults
```

```swift
// AppState.swift
enum AppState {
    case needsOnboarding
    case onboarded
}

class AppViewModel: ObservableObject {
    @Published var appState: AppState = .needsOnboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    init() {
        appState = hasCompletedOnboarding ? .onboarded : .needsOnboarding
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        appState = .onboarded
    }
}
```

---

## Onboarding Steps

```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome        = 0   // 3s — logo + tagline
    case folderPicker   = 1   // 15s — drag folder or browse
    case starterRules   = 2   // 20s — toggle rule cards
    case permissions    = 3   // 10s — Full Disk Access prompt
    case processing     = 4   // 5s — animated live run
    case done           = 5   // 5s — summary + "Start using FolderMind"
}
```

---

## Step 0 — Welcome Screen

**Goal:** Communicate the product in under 3 seconds. Then auto-advance.

```swift
// WelcomeStepView.swift
struct WelcomeStepView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var taglineOpacity: Double = 0
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon — use actual asset
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .scaleEffect(logoScale)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: logoScale)

            VStack(spacing: 8) {
                Text("FolderMind")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

                Text("Your Mac. Finally organised.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
                    .opacity(taglineOpacity)
                    .animation(.easeIn(duration: 0.4).delay(0.3), value: taglineOpacity)
            }

            Spacer()

            Button("Get started") {
                onAdvance()
            }
            .buttonStyle(FMPrimaryButtonStyle())
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            logoScale = 1.0
            taglineOpacity = 1.0
        }
    }
}
```

**Design notes:**
- Window size: `600 × 480`, `titlebarAppearsTransparent: true`, `titleVisibility: .hidden`
- Background: `NSVisualEffectView` with `.underWindowBackground` blending
- No close/minimise during onboarding — hide traffic lights via `standardWindowButton`

---

## Step 1 — Folder Picker

**Goal:** Let user pick their messy folder with zero friction. Drag-and-drop or browse.

```swift
// FolderPickerStepView.swift
struct FolderPickerStepView: View {
    @Binding var watchedFolderURL: URL?
    @State private var isDraggingOver = false
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 6) {
                Text("Pick your messy folder")
                    .font(.system(size: 22, weight: .semibold))
                Text("FolderMind will watch it and keep it clean — automatically.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            // Drop zone
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDraggingOver ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .frame(height: 160)
                .overlay {
                    VStack(spacing: 12) {
                        if let url = watchedFolderURL {
                            // Confirmed state
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.green)
                            Text(url.lastPathComponent)
                                .font(.system(size: 15, weight: .medium))
                            Text(url.path)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            // Idle state
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Drop a folder here")
                                .font(.system(size: 15, weight: .medium))
                            Text("or")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                            Button("Browse…") { openFolderPicker() }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    handleDrop(providers: providers)
                }
                .animation(.easeInOut(duration: 0.15), value: isDraggingOver)
                .padding(.horizontal, 40)

            Spacer()

            Button("Continue") {
                onAdvance()
            }
            .buttonStyle(FMPrimaryButtonStyle())
            .disabled(watchedFolderURL == nil)
            .padding(.bottom, 40)
        }
    }

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose folder"
        if panel.runModal() == .OK {
            watchedFolderURL = panel.url
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                DispatchQueue.main.async { watchedFolderURL = url }
            }
        }
        return true
    }
}
```

---

## Step 2 — Starter Rules

**Goal:** User toggles rules like app permissions in iOS setup. Fast, visual, no config.

```swift
// StarterRulesStepView.swift

struct StarterRule: Identifiable {
    let id = UUID()
    let icon: String          // SF Symbol
    let name: String
    let description: String   // "When" plain English
    var isEnabled: Bool
    let color: Color
}

extension StarterRule {
    static let defaults: [StarterRule] = [
        StarterRule(icon: "camera.viewfinder",    name: "Screenshots",
                    description: "Move .png files with 'Screen Shot' in the name → Screenshots/",
                    isEnabled: true,  color: .blue),
        StarterRule(icon: "doc.text",             name: "Invoices & receipts",
                    description: "Move PDFs with 'invoice' or 'receipt' in the name → Finance/",
                    isEnabled: true,  color: .green),
        StarterRule(icon: "archivebox",            name: "Archives",
                    description: "Move .zip, .tar, .gz files → Archives/",
                    isEnabled: true,  color: .orange),
        StarterRule(icon: "photo.on.rectangle",   name: "Photos & images",
                    description: "Move .jpg .jpeg .heic files → Photos/",
                    isEnabled: false, color: .pink),
        StarterRule(icon: "play.rectangle",        name: "Videos",
                    description: "Move .mp4 .mov .mkv files → Videos/",
                    isEnabled: false, color: .purple),
        StarterRule(icon: "doc.richtext",          name: "Documents",
                    description: "Move .docx .pages .xlsx .key files → Documents/",
                    isEnabled: false, color: .teal),
        StarterRule(icon: "hammer",                name: "Disk images",
                    description: "Move .dmg .pkg installer files → Installers/",
                    isEnabled: false, color: .gray),
        StarterRule(icon: "music.note",            name: "Audio",
                    description: "Move .mp3 .m4a .flac files → Music/",
                    isEnabled: false, color: .red),
    ]
}

struct StarterRulesStepView: View {
    @State private var rules = StarterRule.defaults
    var onAdvance: () -> Void

    private var enabledCount: Int { rules.filter(\.isEnabled).count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Set up your rules")
                    .font(.system(size: 22, weight: .semibold))
                Text("These activate instantly. You can customise them anytime.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($rules) { $rule in
                        StarterRuleRow(rule: $rule)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Divider()

            HStack {
                Text("\(enabledCount) rule\(enabledCount == 1 ? "" : "s") active")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue") { onAdvance() }
                    .buttonStyle(FMPrimaryButtonStyle())
                    .disabled(enabledCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

struct StarterRuleRow: View {
    @Binding var rule: StarterRule

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(rule.color.opacity(rule.isEnabled ? 0.15 : 0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: rule.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(rule.isEnabled ? rule.color : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.system(size: 13, weight: .medium))
                Text(rule.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $rule.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rule.isEnabled
                      ? rule.color.opacity(0.04)
                      : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(rule.isEnabled
                                      ? rule.color.opacity(0.2)
                                      : Color.secondary.opacity(0.15),
                                      lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: 0.15), value: rule.isEnabled)
        .contentShape(Rectangle())
        .onTapGesture { rule.isEnabled.toggle() }
    }
}
```

---

## Step 3 — Permissions

**Goal:** Request Full Disk Access. Make it feel safe, not scary.

```swift
// PermissionsStepView.swift
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

            // Visual step guide
            VStack(alignment: .leading, spacing: 10) {
                PermissionStep(number: 1,
                               text: "Click \"Open System Settings\" below")
                PermissionStep(number: 2,
                               text: "Find FolderMind in the list and toggle it on")
                PermissionStep(number: 3,
                               text: "Come back here — it detects automatically")
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
                        openPrivacySettings()
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
        // Attempt to read a protected path to verify access
        let testPath = NSHomeDirectory() + "/Library"
        hasPermission = FileManager.default.isReadableFile(atPath: testPath)
        if hasPermission { onAdvance() }
    }

    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.accentColor)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
```

---

## Step 4 — Live Processing Animation

**Goal:** The "holy sh*t" moment. Watch existing files being sorted in real time.

```swift
// ProcessingStepView.swift
struct ProcessingStepView: View {
    let folderURL: URL
    let enabledRules: [StarterRule]
    var onAdvance: () -> Void

    @State private var processedFiles: [ProcessedFile] = []
    @State private var isScanning = false
    @State private var totalProcessed = 0

    struct ProcessedFile: Identifiable {
        let id = UUID()
        let originalName: String
        let destinationFolder: String
        let rule: String
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Sorting your files…")
                    .font(.system(size: 22, weight: .semibold))
                Text("Sit back. This takes a few seconds.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            // Live file feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(processedFiles) { file in
                            ProcessingFileRow(file: file)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .id(file.id)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .onChange(of: processedFiles.count) { _ in
                    if let last = processedFiles.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Spacer()

            if totalProcessed > 0 {
                VStack(spacing: 12) {
                    Text("Sorted \(totalProcessed) file\(totalProcessed == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .medium))
                    Button("See the results") { onAdvance() }
                        .buttonStyle(FMPrimaryButtonStyle())
                }
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { startProcessing() }
    }

    func startProcessing() {
        // Scan folder, match against enabled rules, animate results
        DispatchQueue.global(qos: .userInitiated).async {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: folderURL, includingPropertiesForKeys: nil) else { return }

            for (i, fileURL) in files.enumerated() {
                if let match = matchRule(for: fileURL) {
                    let processed = ProcessedFile(
                        originalName: fileURL.lastPathComponent,
                        destinationFolder: match.destination,
                        rule: match.ruleName
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            processedFiles.append(processed)
                            totalProcessed += 1
                        }
                    }
                }
            }
        }
    }

    func matchRule(for url: URL) -> (destination: String, ruleName: String)? {
        // Implementation: match file against enabled starter rules
        // Returns destination folder name and rule name if matched
        return nil // placeholder
    }
}

struct ProcessingFileRow: View {
    let file: ProcessingStepView.ProcessedFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)

            Text(file.originalName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(file.destinationFolder)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.05))
        )
    }
}
```

---

## Step 5 — Done Screen

**Goal:** Emotional payoff. Quantified. No upsell. No email. Just satisfaction.

```swift
// DoneStepView.swift
struct DoneStepView: View {
    let filesProcessed: Int
    let minutesSaved: Int
    var onComplete: () -> Void

    @State private var numberScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Big number — the hook
            VStack(spacing: 4) {
                Text("\(filesProcessed)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .scaleEffect(numberScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: numberScale)
                Text("files just found a home")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            // Time saved pill
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                Text("~\(minutesSaved) minutes of sorting you'll never do manually")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.08))
            )

            // Reassurance
            Text("All reversible. Every action is logged in the activity feed.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button("Start using FolderMind") {
                onComplete()
            }
            .buttonStyle(FMPrimaryButtonStyle())
            .padding(.bottom, 40)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { contentOpacity = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.1)) {
                numberScale = 1.0
            }
        }
    }
}
```

---

## Shared Components

```swift
// FMPrimaryButtonStyle.swift
struct FMPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled
                          ? Color.accentColor
                          : Color.secondary.opacity(0.3))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

```swift
// OnboardingWindowController.swift
class OnboardingWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()

        // Hide traffic lights during onboarding
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Vibrancy background
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        window.contentView = visualEffect

        self.init(window: window)
    }
}
```

---

## Onboarding Coordinator

```swift
// OnboardingCoordinatorView.swift
struct OnboardingCoordinatorView: View {
    @EnvironmentObject var appVM: AppViewModel
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
                StarterRulesStepView(
                    rules: Binding(
                        get: { enabledRules },
                        set: { enabledRules = $0 }
                    )
                ) { advance() }
            case .permissions:
                PermissionsStepView { advance() }
            case .processing:
                ProcessingStepView(
                    folderURL: watchedFolderURL!,
                    enabledRules: enabledRules.filter(\.isEnabled)
                ) { advance() }
            case .done:
                DoneStepView(
                    filesProcessed: filesProcessed,
                    minutesSaved: filesProcessed / 3   // rough 20s/file estimate
                ) {
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
}
```

---

# 2. Rule Builder — Interaction Model

## Philosophy

The rule builder must feel like assembling Lego — not configuring enterprise software. Every condition and action is a **chip**. Chips are tappable. Nothing requires typing unless the user wants to.

**The 5 constraints that make it great:**
1. No modals — everything expands inline
2. Live preview updates as the rule is being built
3. Dry-run shows real filenames from the watched folder
4. Regex is hidden behind an "Advanced" toggle — never the default
5. One rule = one screen. No wizard steps.

---

## Data Model

```swift
// RuleModel.swift

struct FMRule: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = true
    var watchedFolderURL: URL
    var conditions: [RuleCondition]
    var conditionLogic: ConditionLogic = .all   // AND / OR
    var actions: [RuleAction]
    var priority: Int = 0
}

// MARK: - Conditions

enum ConditionLogic: String, Codable { case all, any }

enum RuleCondition: Identifiable, Codable {
    var id: UUID { UUID() }

    case extensionIs([String])             // .pdf, .png, .jpg
    case nameContains(String)              // "invoice"
    case nameStartsWith(String)
    case nameEndsWith(String)
    case nameMatchesRegex(String)          // advanced
    case fileSizeGreaterThan(Int)          // bytes
    case fileSizeLessThan(Int)
    case dateCreatedWithinDays(Int)
    case dateModifiedWithinDays(Int)
    case isInSubfolder(Bool)

    var displayName: String {
        switch self {
        case .extensionIs(let exts):         return "Extension is \(exts.joined(separator: ", "))"
        case .nameContains(let s):           return "Name contains "\(s)""
        case .nameStartsWith(let s):         return "Name starts with "\(s)""
        case .nameEndsWith(let s):           return "Name ends with "\(s)""
        case .nameMatchesRegex(let r):       return "Name matches /\(r)/"
        case .fileSizeGreaterThan(let b):    return "Larger than \(bytesDisplay(b))"
        case .fileSizeLessThan(let b):       return "Smaller than \(bytesDisplay(b))"
        case .dateCreatedWithinDays(let d):  return "Created within \(d) days"
        case .dateModifiedWithinDays(let d): return "Modified within \(d) days"
        case .isInSubfolder(let v):          return v ? "Is inside a subfolder" : "Is in the root folder"
        }
    }
}

// MARK: - Actions

enum RuleAction: Identifiable, Codable {
    var id: UUID { UUID() }

    case moveToFolder(URL)
    case copyToFolder(URL)
    case renameWith(template: String)        // {date}_{name}, {year}-{month}_{name}
    case addFinderTag(String)
    case runShellScript(String)
    case deleteAfterDays(Int)
    case openWithApp(URL)

    var displayName: String {
        switch self {
        case .moveToFolder(let url):         return "Move to \(url.lastPathComponent)"
        case .copyToFolder(let url):         return "Copy to \(url.lastPathComponent)"
        case .renameWith(let t):             return "Rename: \(t)"
        case .addFinderTag(let tag):         return "Add tag "\(tag)""
        case .runShellScript(let s):         return "Run script: \(s.prefix(20))…"
        case .deleteAfterDays(let d):        return "Delete after \(d) days"
        case .openWithApp(let url):          return "Open with \(url.lastPathComponent)"
        }
    }
}
```

---

## Rename Template Tokens

```
{name}         → original filename without extension
{ext}          → file extension without dot
{date}         → YYYY-MM-DD
{year}         → YYYY
{month}        → MM
{day}          → DD
{time}         → HH-MM-SS
{counter}      → sequential number (001, 002…)
{parent}       → name of parent folder
```

**Examples:**

| Template | Input | Output |
|---|---|---|
| `{date}_{name}` | `invoice.pdf` | `2025-04-12_invoice.pdf` |
| `{year}-{month}_{name}` | `receipt stripe.pdf` | `2025-04_receipt stripe.pdf` |
| `photo_{counter}` | `IMG_4821.jpg` | `photo_001.jpg` |
| `{parent}_{name}` | `doc.pdf` in `Client/` | `Client_doc.pdf` |

---

## RuleBuilderView — SwiftUI

```swift
// RuleBuilderView.swift
struct RuleBuilderView: View {
    @Binding var rule: FMRule
    @State private var dryRunResults: [DryRunMatch] = []
    @State private var isRunningDryRun = false
    @State private var showAdvancedConditions = false

    struct DryRunMatch: Identifiable {
        let id = UUID()
        let originalPath: URL
        let resultName: String
        let resultFolder: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // SECTION: Rule name
                RuleBuilderSection(title: "Rule name") {
                    TextField("e.g. Sort invoices", text: $rule.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }

                // SECTION: Conditions
                RuleBuilderSection(title: "When a file arrives and…") {
                    VStack(spacing: 8) {
                        ForEach($rule.conditions) { $condition in
                            ConditionChipRow(condition: $condition) {
                                rule.conditions.removeAll { $0.id == condition.id }
                            }
                        }

                        // Add condition button
                        AddConditionButton { newCondition in
                            withAnimation(.spring(response: 0.3)) {
                                rule.conditions.append(newCondition)
                            }
                        }

                        // AND / OR toggle (only shows when >1 condition)
                        if rule.conditions.count > 1 {
                            Picker("Logic", selection: $rule.conditionLogic) {
                                Text("All conditions match").tag(ConditionLogic.all)
                                Text("Any condition matches").tag(ConditionLogic.any)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }

                // SECTION: Actions
                RuleBuilderSection(title: "Then…") {
                    VStack(spacing: 8) {
                        ForEach($rule.actions) { $action in
                            ActionChipRow(action: $action) {
                                rule.actions.removeAll { $0.id == action.id }
                            }
                        }

                        AddActionButton { newAction in
                            withAnimation(.spring(response: 0.3)) {
                                rule.actions.append(newAction)
                            }
                        }
                    }
                }

                // SECTION: Dry-run preview
                if !rule.conditions.isEmpty && !rule.actions.isEmpty {
                    DryRunPreviewSection(
                        results: dryRunResults,
                        isLoading: isRunningDryRun
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(24)
        }
        .onChange(of: rule.conditions) { _ in scheduleDryRun() }
        .onChange(of: rule.actions) { _ in scheduleDryRun() }
    }

    // Debounced dry run — 400ms after last change
    @State private var dryRunTask: Task<Void, Never>? = nil

    func scheduleDryRun() {
        dryRunTask?.cancel()
        dryRunTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await runDryRun()
        }
    }

    @MainActor
    func runDryRun() async {
        isRunningDryRun = true
        // Scan watched folder, match against current rule, return up to 10 matches
        // This is the preview that shows "real" filenames
        dryRunResults = await RuleEngine.shared.dryRun(rule: rule, limit: 10)
        isRunningDryRun = false
    }
}
```

---

## Condition Chip Row

```swift
// ConditionChipRow.swift
struct ConditionChipRow: View {
    @Binding var condition: RuleCondition
    var onDelete: () -> Void

    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            // Condition type chip
            Menu {
                conditionTypeMenuItems
            } label: {
                FMChip(text: conditionTypeLabel, isActive: true)
            }
            .menuStyle(.borderlessButton)

            // Condition value chip(s)
            conditionValueChips

            Spacer()

            // Delete
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    var conditionTypeLabel: String {
        switch condition {
        case .extensionIs:         return "Extension is"
        case .nameContains:        return "Name contains"
        case .nameStartsWith:      return "Name starts with"
        case .nameEndsWith:        return "Name ends with"
        case .nameMatchesRegex:    return "Name matches"
        case .fileSizeGreaterThan: return "Larger than"
        case .fileSizeLessThan:    return "Smaller than"
        case .dateCreatedWithinDays: return "Created within"
        case .dateModifiedWithinDays: return "Modified within"
        case .isInSubfolder:       return "Location"
        }
    }

    @ViewBuilder
    var conditionValueChips: some View {
        switch condition {
        case .extensionIs(let exts):
            ExtensionPickerChips(extensions: Binding(
                get: { exts },
                set: { condition = .extensionIs($0) }
            ))
        case .nameContains(let s):
            InlineTextChip(value: Binding(
                get: { s },
                set: { condition = .nameContains($0) }
            ), placeholder: "keyword")
        default:
            FMChip(text: "configure", isActive: false)
        }
    }

    @ViewBuilder
    var conditionTypeMenuItems: some View {
        Button("Extension is")    { condition = .extensionIs([]) }
        Button("Name contains")   { condition = .nameContains("") }
        Button("Name starts with"){ condition = .nameStartsWith("") }
        Button("Name ends with")  { condition = .nameEndsWith("") }
        Divider()
        Button("Larger than")     { condition = .fileSizeGreaterThan(1_000_000) }
        Button("Smaller than")    { condition = .fileSizeLessThan(100_000_000) }
        Divider()
        Button("Created within")  { condition = .dateCreatedWithinDays(7) }
        Button("Modified within") { condition = .dateModifiedWithinDays(7) }
        Divider()
        Button("Name matches regex") { condition = .nameMatchesRegex("") }
    }
}
```

---

## Extension Picker Chips

```swift
// ExtensionPickerChips.swift
// Shows .pdf .png .jpg as individual tappable chips
// Tap to deselect. Tap "+" to add custom extension.

struct ExtensionPickerChips: View {
    @Binding var extensions: [String]
    @State private var isAddingCustom = false
    @State private var customInput = ""

    let common = ["pdf", "png", "jpg", "jpeg", "zip", "docx", "xlsx", "mp4", "mov", "mp3"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(extensions, id: \.self) { ext in
                FMChip(text: ".\(ext)", isActive: true)
                    .onTapGesture {
                        withAnimation { extensions.removeAll { $0 == ext } }
                    }
            }

            // Extension picker popover
            Menu {
                ForEach(common.filter { !extensions.contains($0) }, id: \.self) { ext in
                    Button(".\(ext)") {
                        withAnimation { extensions.append(ext) }
                    }
                }
                Divider()
                Button("Custom…") { isAddingCustom = true }
            } label: {
                FMChip(text: "+ add", isActive: false)
            }
            .menuStyle(.borderlessButton)
        }
    }
}
```

---

## Rename Template Builder

```swift
// RenameTemplateBuilder.swift
struct RenameTemplateBuilder: View {
    @Binding var template: String
    let exampleFileName: String = "invoice-stripe-march.pdf"

    var previewResult: String {
        RenameEngine.preview(template: template, for: exampleFileName, date: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Template input with token insert buttons
            HStack(spacing: 6) {
                TextField("{date}_{name}", text: $template)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .frame(maxWidth: .infinity)

                // Token quick-insert buttons
                ForEach(["{name}", "{date}", "{year}", "{counter}"], id: \.self) { token in
                    Button(token) { template += token }
                        .font(.system(size: 11, design: .monospaced))
                        .buttonStyle(.borderless)
                        .foregroundStyle(.accentColor)
                }
            }

            // Live preview
            HStack(spacing: 6) {
                Text("Preview:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(previewResult)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.green.opacity(0.1))
                    )
            }
        }
    }
}
```

---

## Dry Run Preview Section

```swift
// DryRunPreviewSection.swift
struct DryRunPreviewSection: View {
    let results: [RuleBuilderView.DryRunMatch]
    let isLoading: Bool

    private let maxShown = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dry-run preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }

                Spacer()

                if !results.isEmpty {
                    Text("\(results.count) file\(results.count == 1 ? "" : "s") would match")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if results.isEmpty && !isLoading {
                Text("No existing files in your folder match this rule yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(results.prefix(maxShown)) { match in
                        HStack(spacing: 8) {
                            Text(match.originalPath.lastPathComponent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(match.resultName.isEmpty
                                 ? match.resultFolder
                                 : "\(match.resultFolder)/\(match.resultName)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.06))
                        )
                    }

                    if results.count > maxShown {
                        Text("+ \(results.count - maxShown) more")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.15), lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.spring(response: 0.3), value: results.count)
    }
}
```

---

## Rule Engine — Core Logic

```swift
// RuleEngine.swift
actor RuleEngine {
    static let shared = RuleEngine()

    func evaluate(rule: FMRule, for fileURL: URL) -> Bool {
        let results = rule.conditions.map { condition in
            evaluateCondition(condition, for: fileURL)
        }
        return rule.conditionLogic == .all
            ? results.allSatisfy { $0 }
            : results.contains(true)
    }

    func dryRun(rule: FMRule, limit: Int = 10) async -> [RuleBuilderView.DryRunMatch] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: rule.watchedFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }

        return contents
            .filter { evaluate(rule: rule, for: $0) }
            .prefix(limit)
            .map { url in
                let resultName = applyRenameActions(rule.actions, to: url)
                let resultFolder = applyMoveActions(rule.actions, to: url)
                return RuleBuilderView.DryRunMatch(
                    originalPath: url,
                    resultName: resultName,
                    resultFolder: resultFolder
                )
            }
    }

    private func evaluateCondition(_ condition: RuleCondition, for url: URL) -> Bool {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)

        switch condition {
        case .extensionIs(let exts):
            return exts.map { $0.lowercased() }.contains(ext)
        case .nameContains(let s):
            return name.localizedCaseInsensitiveContains(s)
        case .nameStartsWith(let s):
            return name.lowercased().hasPrefix(s.lowercased())
        case .nameEndsWith(let s):
            return name.lowercased().hasSuffix(s.lowercased())
        case .nameMatchesRegex(let pattern):
            return (try? NSRegularExpression(pattern: pattern)
                .firstMatch(in: name, range: NSRange(name.startIndex..., in: name))) != nil
        case .fileSizeGreaterThan(let bytes):
            let size = (attrs?[.size] as? Int) ?? 0
            return size > bytes
        case .fileSizeLessThan(let bytes):
            let size = (attrs?[.size] as? Int) ?? 0
            return size < bytes
        case .dateCreatedWithinDays(let days):
            let created = attrs?[.creationDate] as? Date ?? Date.distantPast
            return Date().timeIntervalSince(created) < Double(days) * 86400
        case .dateModifiedWithinDays(let days):
            let modified = attrs?[.modificationDate] as? Date ?? Date.distantPast
            return Date().timeIntervalSince(modified) < Double(days) * 86400
        case .isInSubfolder(let inSub):
            // Compare parent count — simple heuristic
            return inSub // placeholder
        }
    }

    private func applyRenameActions(_ actions: [RuleAction], to url: URL) -> String {
        for action in actions {
            if case .renameWith(let template) = action {
                return RenameEngine.apply(template: template, to: url, date: Date())
            }
        }
        return url.lastPathComponent
    }

    private func applyMoveActions(_ actions: [RuleAction], to url: URL) -> String {
        for action in actions {
            if case .moveToFolder(let dest) = action {
                return dest.lastPathComponent
            }
        }
        return url.deletingLastPathComponent().lastPathComponent
    }
}
```

---

# 3. Landing Page — Full Copy & Structure

## Meta

```
Title:       FolderMind — Auto-organise your Mac. One rule, one time.
Description: Stop sorting files manually. FolderMind watches your folders and 
             keeps them clean with rules you set once. No subscription. $14.99.
OG Image:    Before/after split: chaos Downloads vs clean organised folders
URL:         foldermind.app
```

---

## Section 1 — Hero

```
HEADLINE
Your Downloads folder.
Finally not embarrassing.

SUBHEAD
FolderMind watches your Mac folders and automatically moves, renames, and 
organises files — using rules you set once and forget.

CTA (primary)    →  Download free trial  (7-day, no card)
CTA (secondary)  →  Buy for $14.99  (one-time, yours forever)

SOCIAL PROOF
★★★★★  "Sorted 400 files in the first 60 seconds."  — @designer_xyz
```

**Design note:** Hero should have a 2-panel split screenshot:
- Left: messy Downloads folder (400 files, no order)
- Right: same folder after FolderMind (4 clean subfolders, all labelled)

---

## Section 2 — Problem (Before State)

```
LABEL
Sound familiar?

HEADLINE
You've been meaning to clean that folder for months.

3-column pain grid:

[icon: screenshot]     [icon: invoice]         [icon: download]
Screenshots            PDFs everywhere          .dmg files
everywhere             Invoices, receipts,      piling up
You know you should    statements all dumped     You've never
put them somewhere.    in one place.             opened half of them.
You never do.

TRANSITION LINE
You keep meaning to fix it. FolderMind just fixes it.
```

---

## Section 3 — How It Works (3 steps)

```
LABEL
How it works

HEADLINE
Set rules once. Never sort files again.

STEP 1  ──────────────────────────────────────────
[Screenshot: folder picker]

Pick your messy folder

Drop your Downloads folder onto FolderMind. 
Or pick any folder you want to keep clean. 
Add as many as you want.

STEP 2  ──────────────────────────────────────────
[Screenshot: rule builder with dry-run preview]

Build your rules in plain English

"If the file extension is .png and the name 
contains 'Screen Shot' → move to Screenshots/"

Or just activate one of 12 starter rules in one tap.
No config. No wizard. Real file preview before you commit.

STEP 3  ──────────────────────────────────────────
[Screenshot: menubar popover + activity log]

Watch it work. Undo anything.

Every file FolderMind touches is logged. 
One-click undo, up to 30 days back.
It runs in your menubar, silent and invisible — 
until you need it.
```

---

## Section 4 — The "Wow Moment" Feature Block

```
HEADLINE
The features that make people tweet about it.

FEATURE GRID (2x3)

[icon: eye]
Live dry-run preview
Build a rule and instantly see which of your 
existing files it would affect — by name — 
before activating it.

[icon: clock.arrow.circlepath]
One-click undo
Every action is reversible. Every time. 
FolderMind keeps a full log with an undo 
button next to each action.

[icon: text.cursor]
Rename templates
{year}-{month}_{name} becomes a real filename 
as you type. Live preview. No guessing.

[icon: waveform.badge.magnifyingglass]
Runs silently
No Dock icon. Lives in your menubar. 
Uses FSEvents (zero polling, zero battery drain).

[icon: square.and.arrow.up]
Shareable rule packs
Export your rules as .fmrules files. 
Import rules shared by the community. 
Your "Screenshots" setup is someone else's starting point.

[icon: checkmark.shield]
Fully local
Your files never touch a server. 
No account. No internet required after purchase. 
Works on planes.
```

---

## Section 5 — Social Proof

```
HEADLINE
People who used to have a messy Downloads folder

TESTIMONIAL GRID (3 column)

"Activated the invoice rule. 
It immediately sorted 78 PDFs 
I hadn't touched in 8 months."
— @freelance_dev_  ·  Full-stack developer

"The dry-run preview is 
genuinely the best feature. 
I can test a rule without 
touching a single real file."
— @macos_nerd  ·  Designer

"My Downloads folder has 
had 0 files in it for 
three weeks. This has never 
happened in my life."
— @productivitynerd  ·  Product manager

SUBTEXT
[Join 2,400+ Mac users with clean folders]   ← update this number regularly
```

---

## Section 6 — Pricing

```
HEADLINE
One price. No subscriptions. No tricks.

PRICE DISPLAY

[ $14.99 ]
Buy once, own forever

What you get:
✓  Unlimited watched folders
✓  Unlimited rules
✓  12 starter rule templates
✓  Activity log + undo (30 days)
✓  Rename templates
✓  Rule export/import
✓  Free updates for 12 months
✓  macOS 13 Ventura and later

[ Download for $14.99 ]     ← primary CTA button
[ Try free for 7 days ]     ← secondary, below

TRUST ROW
🔒 Secure payment via Paddle  ·  30-day refund guarantee  ·  No account needed
```

---

## Section 7 — FAQ

```
HEADLINE
Honest answers

Q: Does FolderMind send my files anywhere?
A: No. FolderMind never connects to the internet (after purchase). 
   Everything happens locally on your Mac. Your files are yours.

Q: What happens after 12 months?
A: The app keeps working forever — you just don't get new features. 
   You can upgrade for a discounted price if you want what's new.

Q: Why not on the Mac App Store?
A: The App Store sandboxes apps in a way that prevents FolderMind 
   from watching arbitrary folders and writing to your filesystem. 
   We distribute direct so the app actually works the way it should.

Q: Does it work with iCloud Drive?
A: Yes. FolderMind watches any folder including iCloud-synced ones. 
   iCloud sync still runs normally alongside it.

Q: What if I accidentally move something I didn't want to?
A: Hit undo. Every action FolderMind takes is logged with a one-click 
   undo button. You have 30 days to reverse anything.

Q: Is there a trial?
A: Yes — 7 days, full features, no card required. 
   If you don't buy, the app stops running rules after the trial ends. 
   Your files stay exactly where FolderMind left them.
```

---

## Section 8 — Final CTA

```
HEADLINE
A clean Mac is a calm Mac.

SUBHEAD
3 minutes to set up. A lifetime of not thinking about it.

CTA
[ Download free trial ]

SUBTEXT
No account. No card for trial. $14.99 to own forever.

FOOTER
FolderMind · Made by [your name] · Salem, India
[Twitter] [Changelog] [Contact] [License] [Privacy]
```

---

## Landing Page Technical Notes

```
Stack:         Next.js or plain HTML — no need for a framework
Hosting:       Vercel (free tier is fine)
Analytics:     Plausible or Fathom (privacy-first — matches "no tracking" positioning)
Payment:       LemonSqueezy or Paddle — both handle VAT automatically
Download gate: Paddle/LS license key email flow — no custom backend needed
OG image:      Static 1200×630 with before/after screenshot split
```

---

## Launch Checklist

| Task | Priority |
|---|---|
| Landing page live with waitlist | Week 3 |
| Trial build (.dmg, signed, notarized) | Week 3 |
| LemonSqueezy store page live | Week 3 |
| Product Hunt scheduled (Tuesday) | Week 4 |
| Post on r/macapps | Week 4 |
| Post on r/productivity | Week 4 |
| Hacker News "Show HN" | Week 4 |
| Submit to MacMenuBar.com | Week 4 |
| DM 5 macOS YouTubers with free key | Week 4 |
| SEO: "Hazel alternative" content | Week 5+ |
| Community rule packs page | Week 5+ |

---

*FolderMind spec v1.0 — last updated April 2025*
