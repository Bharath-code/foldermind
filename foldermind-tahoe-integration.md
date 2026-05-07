# FolderMind — Tahoe Integration Plan

> macOS 26 (Tahoe) feature integration strategy
> Version 1.0 · Supplements foldermind-technical-gaps.md

---

## Architecture Decision: Progressive Enhancement

```
macOS 13+ baseline (current spec)
    ├── All core features work on 13+
    └── Tahoe features activate via @available checks
        └── No feature loss on older OS
        └── Marketing: "Optimized for macOS Tahoe"
```

**Why not Tahoe-only?**
- Market share: Tahoe won't be dominant for 12-18 months
- $14.99 price point = broader audience
- Can still market Tahoe features as premium differentiator
- Easy to drop 13+ support later when Tahoe hits 60%+ adoption

---

## 1. Foundation Models — Smart File Categorization

### What it does

Beyond extension matching, uses on-device AI to understand file content:
- PDF named `scan_0042.pdf` → reads text, identifies as "invoice from Stripe"
- Image named `IMG_9921.jpg` → recognizes it's a receipt, not a family photo
- Text file named `notes.txt` → detects it's meeting minutes, not a todo list

### Implementation

```swift
// SmartFileClassifier.swift

import Foundation
#if canImport(AppleIntelligence)
import AppleIntelligence
#endif

@available(macOS 26, *)
actor SmartFileClassifier {
    private var textModel: AIFoundationModel?
    private var visionModel: AIFoundationModel?

    init() async {
        do {
            textModel = try await AIFoundationModel.load(.textAnalysis)
            textModel?.processingLocation = .onDevice
        } catch {
            // Fallback: rule-based classification only
        }
    }

    func classifyFile(_ url: URL) async -> FileClassification? {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf", "txt", "rtf", "docx":
            return await classifyTextFile(url)
        case "jpg", "jpeg", "png", "heic":
            return await classifyImageFile(url)
        default:
            return nil  // Fall back to rule-based
        }
    }

    private func classifyTextFile(_ url: URL) async -> FileClassification? {
        guard let text = try? String(contentsOf: url, encoding: .utf8).prefix(2000) else {
            return nil
        }

        guard let model = textModel else { return nil }

        do {
            let prompt = """
            Classify this document into ONE category.
            Categories: invoice, receipt, contract, letter, report, meeting_notes, personal, other

            Document text:
            \(text)

            Return only the category name.
            """

            let response = try await model.generate(prompt: prompt)
            return FileClassification(
                category: response.text.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: 0.85,
                source: .ai
            )
        } catch {
            return nil
        }
    }

    private func classifyImageFile(_ url: URL) async -> FileClassification? {
        // Vision model for image content analysis
        guard let model = visionModel else { return nil }

        do {
            let imageData = try Data(contentsOf: url)
            let classification = try await model.analyzeImage(imageData)

            return FileClassification(
                category: classification.primaryLabel,
                confidence: classification.confidence,
                source: .ai
            )
        } catch {
            return nil
        }
    }
}

struct FileClassification {
    let category: String
    let confidence: Double
    let source: ClassificationSource

    enum ClassificationSource {
        case ai          // Foundation Model
        case ruleBased   // Extension/name matching
    }
}
```

### Fallback chain (works on all macOS versions)

```
File arrives
    → SmartFileClassifier (Tahoe only, @available check)
        → AI classification returned? Use it
        → nil or unavailable?
            → RuleEngine.evaluate() (extension/name/size rules)
                → Match found? Use it
                → No match? File stays in place (no-op)
```

### Integration with existing RuleEngine

```swift
// In RuleEngine.swift — add AI-enhanced evaluation

func evaluateWithAI(rule: FMRule, for fileURL: URL) async -> Bool {
    // First try AI classification on Tahoe
    if #available(macOS 26, *) {
        if let aiClassification = await SmartFileClassifier.shared.classifyFile(fileURL) {
            // AI found a category — check if rule matches it
            return rule.conditions.contains { condition in
                if case .nameContains(let keyword) = condition {
                    return aiClassification.category.localizedCaseInsensitiveContains(keyword)
                }
                return false
            }
        }
    }

    // Fallback to rule-based
    return evaluate(rule: rule, for: fileURL)
}
```

### Privacy guarantees (marketing point)

- **All processing on-device** — `processingLocation = .onDevice`
- **No network calls** — Foundation Models run locally on Neural Engine
- **No data leaves Mac** — same promise as current spec, now verifiable

---

## 2. Spotlight Integration

### What it does

Two-way Spotlight integration:
1. **Index organized files** — Users can search via Spotlight: "invoice FolderMind"
2. **Quick actions** — "Organize this folder" directly from Spotlight

### Implementation

```swift
// SpotlightIndexer.swift

import CoreSpotlight
import MobileCoreServices

struct SpotlightIndexer {
    static func indexOrganizedFile(
        sourceURL: URL,
        destinationURL: URL,
        ruleName: String,
        activityEntry: ActivityEntry
    ) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = destinationURL.lastPathComponent
        attributeSet.contentDescription = "Organized by FolderMind using rule: \(ruleName)"
        attributeSet.keywords = [
            "FolderMind",
            ruleName,
            "organized",
            destinationURL.deletingLastPathComponent().lastPathComponent
        ]
        attributeSet.path = destinationURL.path

        // Add thumbnail
        if let icon = NSWorkspace.shared.icon(forFile: destinationURL.path) {
            attributeSet.thumbnailData = icon.tiffRepresentation
        }

        let item = CSSearchableItem(
            uniqueIdentifier: activityEntry.id.uuidString,
            domainIdentifier: "app.foldermind.organized",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                os_log("Spotlight indexing error: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }

    static func removeIndexedFile(entryID: String) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [entryID]
        )
    }

    static func indexRule(_ rule: FMRule) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
        attributeSet.title = "FolderMind: \(rule.name)"
        attributeSet.contentDescription = "Rule: \(rule.conditions.map { $0.displayName }.joined(separator: ", "))"
        attributeSet.keywords = ["FolderMind", "rule", rule.name]

        let item = CSSearchableItem(
            uniqueIdentifier: rule.id.uuidString,
            domainIdentifier: "app.foldermind.rules",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item])
    }
}
```

### Spotlight Quick Action (NSUserActivity)

```swift
// SpotlightQuickActions.swift

import AppKit

struct SpotlightQuickActions {
    static func registerOrganizeFolderActivity() {
        let activity = NSUserActivity(activityType: "app.foldermind.organizeFolder")
        activity.title = "Organize Folder with FolderMind"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = "organize-folder"
        activity.becomeCurrent()
    }

    static func registerToggleRuleActivity(rule: FMRule) {
        let activity = NSUserActivity(activityType: "app.foldermind.toggleRule")
        activity.title = "\(rule.isEnabled ? "Disable" : "Enable"): \(rule.name)"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = ["ruleID": rule.id.uuidString]
        activity.becomeCurrent()
    }
}

// In AppDelegate:
func application(
    _ application: NSApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
) -> Bool {
    switch userActivity.activityType {
    case "app.foldermind.organizeFolder":
        openMainWindowAndTriggerOrganize()
        return true
    case "app.foldermind.toggleRule":
        if let ruleID = userActivity.userInfo?["ruleID"] as? String {
            toggleRule(id: UUID(uuidString: ruleID))
        }
        return true
    default:
        return false
    }
}
```

### Where to call the indexer

```swift
// In RuleEngine.executeActions() — after successful move:

case .moved(let dest):
    // Log to activity
    let entry = ActivityEntry(
        ruleName: rule.name,
        sourceURL: sourceURL,
        destinationURL: dest,
        actionType: .moved
    )
    undoManager.logAction(entry)

    // Index for Spotlight
    SpotlightIndexer.indexOrganizedFile(
        sourceURL: sourceURL,
        destinationURL: dest,
        ruleName: rule.name,
        activityEntry: entry
    )

    return .moved(dest)
```

---

## 3. Liquid Glass UI

### What it is

macOS 26 design system replacing vibrancy/materials. Key characteristics:
- Translucent glass surfaces with dynamic blur
- Light refraction effects that respond to window position
- Unified control styling (buttons, toggles, fields all share glass aesthetic)
- Automatic light/dark adaptation

### Implementation for FolderMind

```swift
// LiquidGlassModifiers.swift

import SwiftUI

@available(macOS 26, *)
struct LiquidGlassModifiers {
    /// Glass panel for onboarding steps
    static func glassPanel() -> some ViewModifier {
        LiquidGlassPanelStyle(
            material: .sidebar,
            cornerRadius: 16,
            shadow: .soft
        )
    }

    /// Glass button — replaces FMPrimaryButtonStyle on Tahoe
    static func glassButton(isPrimary: Bool = true) -> some ViewModifier {
        LiquidGlassButtonStyle(
            prominence: isPrimary ? .primary : .standard
        )
    }
}

// Onboarding window with Liquid Glass

@available(macOS 26, *)
struct OnboardingWindowView_Tahoe: View {
    var body: some View {
        OnboardingCoordinatorView()
            .modifier(LiquidGlassModifiers.glassPanel())
            .padding(24)
    }
}

// Fallback for older macOS

struct OnboardingWindowView_Legacy: View {
    var body: some View {
        OnboardingCoordinatorView()
            .background(
                NSVisualEffectView()
                    .material(.underWindowBackground)
                    .blendingMode(.behindWindow)
            )
    }
}

// Version-agnostic wrapper

struct OnboardingWindowView: View {
    var body: some View {
        if #available(macOS 26, *) {
            OnboardingWindowView_Tahoe()
        } else {
            OnboardingWindowView_Legacy()
        }
    }
}
```

### Main window with Liquid Glass sidebar

```swift
@available(macOS 26, *)
struct MainWindowView_Tahoe: View {
    @EnvironmentObject var ruleStore: RuleStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(ruleStore)
                .glassSidebar()  // Liquid Glass sidebar
        } detail: {
            RuleListView()
                .environmentObject(ruleStore)
                .padding()
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

extension View {
    @available(macOS 26, *)
    func glassSidebar() -> some View {
        modifier(LiquidGlassSidebarModifier())
    }
}

@available(macOS 26, *)
struct LiquidGlassSidebarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LiquidGlassShape().fill(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
```

### What changes visually on Tahoe

| Element | Legacy (13-25) | Tahoe (26+) |
|---|---|---|
| Window background | `NSVisualEffectView` `.underWindowBackground` | `LiquidGlassPanelStyle` with dynamic blur |
| Buttons | `FMPrimaryButtonStyle` (solid fill) | `LiquidGlassButtonStyle` (translucent, refractive) |
| Sidebar | `.sidebar` list style | Glass sidebar with edge highlights |
| Cards/rows | `Color(nsColor: .controlBackgroundColor)` | `.thinMaterial` with subtle border |
| Toggle | Standard `.switch` | Glass toggle with haptic feel |
| Drop zone | Dashed border + vibrancy | Glass panel with animated refraction on hover |

---

## 4. MLX — On-Device Image Recognition (Phase 2)

### What it does

Uses MLX framework with M5 Neural Engine for:
- Auto-detecting screenshots vs photos vs documents in images
- OCR on image files (receipts, business cards, whiteboard photos)
- Face detection for "family photos" categorization

### Implementation

```swift
// MLXImageClassifier.swift

import MLX

@available(macOS 26, *)
actor MLXImageClassifier {
    private var model: MLXModel?

    init() async {
        // Configure for M5 neural accelerators
        MLX.configuration.useNeuralAccelerators = true
        MLX.configuration.preferredDevice = .neuralEngine

        do {
            model = try await MLXModel.load(from: Bundle.main.url(forResource: "file-classifier", withExtension: "mlx")!)
        } catch {
            // MLX unavailable — fall back to Foundation Models
        }
    }

    func classifyImage(_ url: URL) async -> ImageClassification? {
        guard let model = model,
              let imageData = try? Data(contentsOf: url) else {
            return nil
        }

        do {
            let input = MLXArray(data: imageData)
            let output = try await model.predict(input)

            return ImageClassification(
                category: output.categoryLabel,
                confidence: output.confidence,
                ocrText: output.extractedText  // If OCR was run
            )
        } catch {
            return nil
        }
    }
}

struct ImageClassification {
    let category: String       // "screenshot", "photo", "document", "receipt"
    let confidence: Double
    let ocrText: String?       // Extracted text for documents/receipts
}
```

### When to use MLX vs Foundation Models

```
Image file arrives
    → MLXImageClassifier (fast, optimized for M5)
        → Result with confidence > 0.8? Use it
        → Confidence < 0.8 or MLX unavailable?
            → Foundation Model vision model (slower, more accurate)
                → Result? Use it
                → nil?
                    → Rule-based (extension matching)
```

---

## 5. Continuity — iPhone Camera → Mac Auto-Sort (Phase 2)

### What it does

When user takes a photo on iPhone (document, receipt, whiteboard):
1. Photo arrives on Mac via iCloud Photos or AirDrop
2. FolderMind detects new file in watched folder
3. AI classifies it → auto-sorts into correct subfolder

### Implementation

```swift
// ContinuityMonitor.swift

import Foundation

actor ContinuityMonitor {
    private var fileWatcher: FileWatcher

    init(watchedURL: URL) {
        fileWatcher = FileWatcher(watchedURL: watchedURL) { events in
            await self.handleNewFiles(events)
        }
    }

    func start() throws {
        try await fileWatcher.start()
    }

    private func handleNewFiles(_ events: [FileEvent]) async {
        for event in events where event.type == .created {
            let url = URL(fileURLWithPath: event.path)

            // Check if file came from iPhone (continuity source)
            let source = await determineFileSource(url)

            if source == .continuity {
                // High-priority processing — user just took this photo
                await processContinuityFile(url)
            }
        }
    }

    private func determineFileSource(_ url: URL) async -> FileSource {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)

        // Check for continuity markers
        if let creator = attrs?[.creatorApplicationName] as? String {
            if creator.contains("Mobile") || creator.contains("Camera") {
                return .continuity
            }
        }

        // Check file metadata
        if let metadata = try? await fetchMetadata(url) {
            if metadata.make == "Apple" && metadata.model?.contains("iPhone") == true {
                return .continuity
            }
        }

        return .local
    }

    private func processContinuityFile(_ url: URL) async {
        // Same AI classification pipeline, but with higher priority
        // and immediate notification to user
        let classification = await SmartFileClassifier.shared.classifyFile(url)

        if let classification = classification {
            // Auto-sort + notify
            await RuleEngine.shared.executeActions(
                actionsForCategory(classification.category),
                for: url
            )

            // Show notification
            await showContinuityNotification(
                fileName: url.lastPathComponent,
                category: classification.category
            )
        }
    }

    private func showContinuityNotification(fileName: String, category: String) async {
        let content = UNMutableNotificationContent()
        content.title = "FolderMind"
        content.body = "Sorted \"\(fileName)\" into \(category)/"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

enum FileSource {
    case continuity  // Came from iPhone/iPad
    case local       // Created/downloaded on Mac
}
```

---

## Build Phases

### Phase 1 — Current (macOS 13+, no Tahoe features)
- [x] Onboarding flow
- [x] Rule builder
- [x] FileWatcher + RuleEngine
- [x] Activity log + undo
- [x] Conflict resolution

### Phase 2 — Tahoe Progressive Enhancement (macOS 26+)
- [ ] `@available(macOS 26, *)` wrappers for all Tahoe features
- [ ] SmartFileClassifier with Foundation Models
- [ ] Spotlight indexing + quick actions
- [ ] Liquid Glass UI for onboarding + main window
- [ ] Version-agnostic view wrappers

### Phase 3 — Advanced AI (macOS 26+ with M5)
- [ ] MLX image classifier
- [ ] OCR on image files
- [ ] Continuity monitor for iPhone photos
- [ ] User notification system

---

## Minimum Deployment Target Decision

```
INFOPLIST_KEY_LSMinimumSystemVersion = 13.0

@available checks guard all Tahoe features:

if #available(macOS 26, *) {
    // Liquid Glass, Foundation Models, MLX
} else {
    // Vibrancy, rule-based classification
}
```

**Marketing angles:**
- "Works on any Mac from 2019 onwards"
- "Optimized for macOS Tahoe — smarter with Apple Intelligence"
- "M5 Neural Engine acceleration for instant image sorting"

---

## Code Organization for Tahoe Features

```
FolderMind/
├── Services/
│   ├── Tahoe/
│   │   ├── SmartFileClassifier.swift      # @available(macOS 26, *)
│   │   ├── SpotlightIndexer.swift         # CoreSpotlight (all versions)
│   │   ├── SpotlightQuickActions.swift    # NSUserActivity (all versions)
│   │   ├── MLXImageClassifier.swift       # @available(macOS 26, *)
│   │   └── ContinuityMonitor.swift        # @available(macOS 26, *)
│   └── [existing services...]
├── Views/
│   ├── Tahoe/
│   │   ├── LiquidGlassModifiers.swift     # @available(macOS 26, *)
│   │   └── TahoeWindowWrappers.swift      # Version-agnostic view selectors
│   └── [existing views...]
└── [existing structure...]
```
