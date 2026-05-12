# FolderMind — Implementation Status & Roadmap

> Source of truth for all development work
> Last updated: 2026-05-11
> Target: macOS 13+ with Tahoe progressive enhancement
> Price: $14.99 one-time

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented & scaffolded |
| 🚧 | Scaffolded, needs completion |
| ⬜ | Not started |
| 🔮 | Phase 2+ (Tahoe-only or future) |

---

# Phase 1 — Core Product (macOS 13+)

## 1. Onboarding Flow

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 1.1 | AppState state machine | ✅ | `needsOnboarding` → `onboarded` via `@AppStorage` flag |
| 1.2 | OnboardingStep enum (6 steps) | ✅ | All 6 cases defined, `CaseIterable` for iteration |
| 1.3 | WelcomeStepView | ✅ | Logo animation, tagline, "Get started" button, auto-advance |
| 1.4 | FolderPickerStepView | ✅ | Drag-and-drop + browse, shows selected folder path, Continue disabled until selection |
| 1.5 | StarterRulesStepView | ✅ | 8 preset rules with toggles, binding saves enabled state into onboarding coordinator |
| 1.6 | PermissionsStepView | ✅ | FDA check loop, opens System Settings, auto-detects permission grant |
| 1.7 | ProcessingStepView | ✅ | Live file feed animation, starter rule matching, file moves, activity logging |
| 1.8 | DoneStepView | ✅ | Big number animation, time-saved pill, "Start using" button |
| 1.9 | OnboardingCoordinatorView | ✅ | Step navigation, transitions, state passing between steps |
| 1.10 | FMPrimaryButtonStyle | ✅ | Enabled/disabled states, press animation, rounded corners |
| 1.11 | OnboardingWindowController | ✅ | 600×480 window, transparent titlebar, hidden traffic lights, vibrancy (via WindowConfigurator) |
| 1.12 | Window config (no close/minimize during onboarding) | ✅ | Hide traffic lights, prevent window dismissal mid-flow (via WindowConfigurator) |

## 2. Rule System

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 2.1 | FMRule data model | ✅ | Codable, Identifiable, conditions + actions arrays |
| 2.2 | RuleCondition enum (11 types) | ✅ | Extension, name contains/starts/ends/regex, size, date, location |
| 2.3 | RuleAction enum (7 types) | ✅ | Move, copy, rename, tag, shell script, delete, open with |
| 2.4 | ConditionLogic (AND/OR) | ✅ | `.all` and `.any` with correct evaluation in RuleEngine |
| 2.5 | FMRuleModel (SwiftData) | ✅ | JSON-encoded conditions/actions, `toFMRule()` decoder |
| 2.6 | RuleStore (CRUD) | ✅ | Load, save, delete, toggle — persists to SwiftData |
| 2.7 | RuleBuilderView | ✅ | Chip-based builder implemented with dynamic lists |
| 2.8 | ConditionChipRow | ✅ | ConditionRowView implemented with inline editing |
| 2.9 | ExtensionPickerChips | ✅ | Replaced with dynamic condition type menus |
| 2.10 | RenameTemplateBuilder | ✅ | RenameTokenBar implemented with inline text field |
| 2.11 | AddConditionButton | ✅ | Append flow with animation implemented |
| 2.12 | AddActionButton | ✅ | Append flow with animation implemented |
| 2.13 | Dry-run preview | ✅ | Shows up to 10 matching files with results via RuleEngine.dryRun |
| 2.14 | Rule priority ordering | ✅ | `priority: Int` field, RuleStore sorts by priority desc |
| 2.15 | Rule enable/disable toggle | ✅ | `isEnabled: Bool` on FMRule, toggle in RuleStore |

## 3. File Watching Engine

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 3.1 | FileWatcher actor | ✅ | FSEventStream creation, start/stop, callback dispatch |
| 3.2 | EventDebouncer actor | ✅ | 0.5s window, coalesces bursts, returns stable events |
| 3.3 | FileEvent struct | ✅ | Path, type (created/modified/moved/deleted), timestamp |
| 3.4 | Event classification from FSEvent flags | ✅ | Maps `kFSEventStreamEventFlag*` to `FileEvent.EventType` |
| 3.5 | Ignore metadata-only events | ✅ | Returns `nil` for non-file-change events |
| 3.6 | FileWatcherError enum | ✅ | `streamCreationFailed` case |
| 3.7 | Watcher lifecycle management | ✅ | Start on app launch, stop on quit, restart on folder change |
| 3.8 | Multiple folder watching | ✅ | Support watching multiple folders simultaneously |
| 3.9 | Recursive subfolder watching | ✅ | Recursive matching + recursive manual scan implemented |

## 4. Rule Engine

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 4.1 | RuleEngine actor | ✅ | Singleton, `evaluate()` with AND/OR logic |
| 4.2 | Condition evaluation (all 11 types) | ✅ | Extension, name matching, regex, size, date, location |
| 4.3 | Dry-run preview | ✅ | Scans folder, filters by rule, returns up to N matches |
| 4.4 | Action execution | ✅ | Move/copy with conflict resolution, rename via template |
| 4.5 | ActionResult enum | ✅ | `.moved`, `.copied`, `.skipped`, `.failed` with URLs/messages |
| 4.6 | RenameEngine | ✅ | Token replacement: {name}, {ext}, {date}, {year}, {month}, {day}, {time}, {counter}, {parent} |
| 4.7 | ConflictResolver | ✅ | Counter-based rename (`file_001.pdf`), auto-create destination folder |
| 4.8 | Error handling (permission denied, disk full) | ✅ | ConflictResolver returns `.error()` — integrated into executeActions |
| 4.9 | Rename preview function | ✅ | `RenameEngine.preview(template:for:date:)` for dry-run |

## 5. Activity Log & Undo

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 5.1 | ActivityEntry model (SwiftData) | ✅ | Timestamp, rule name, source/dest URLs, action type, undo state |
| 5.2 | ActionType enum | ✅ | moved, copied, renamed, deleted, createdFolder with `reverseAction` |
| 5.3 | FMUndoManager | ✅ | Log, undo latest, undo all, clear older than N days |
| 5.4 | Per-entry undo | ✅ | `performUndo()` reverses moved/copied actions, marks `isUndone` |
| 5.5 | ActivityFeedView | ✅ | List of entries with per-entry undo button |
| 5.6 | ActivityRowView | ✅ | Shows icon, filename, destination, timestamp, rule name, undone state |
| 5.7 | Activity log persistence | ✅ | SwiftData auto-persists, survives app restart |
| 5.8 | Auto-cleanup old entries | ✅ | `clearOlderThan(_ days:)` method |

## 6. Main Window UI

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 6.1 | MainWindowView | ✅ | NavigationSplitView with sidebar + toolbar (Scan Now, Add Rule) |
| 6.2 | SidebarView | ✅ | List with "Rules" and "Activity" navigation with selection state |
| 6.3 | RuleListView | ✅ | Shows rules or empty state, rows open builder |
| 6.4 | RuleRowView | ✅ | Shows name, summary, priority, enable toggle, and context menu |
| 6.5 | Empty state (no rules) | ✅ | `ContentUnavailableView` with icon and description |
| 6.6 | Toolbar "Add Rule" button | ✅ | Opens RuleBuilderView for new rule creation |
| 6.7 | Settings/Preferences window | ✅ | License key input, auto-start toggle, debug tools |
| 6.8 | Window state persistence | ✅ | Remembers window size/position across launches (via WindowGroup ID) |

## 7. Menu Bar Integration

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 7.1 | MenuBarExtra | ✅ | Folder gear icon in system menu bar |
| 7.2 | MenuBarView | ✅ | Shows active rules, undo button, quit |
| 7.3 | Open main window from menu bar | ✅ | "Open FolderMind" button with app activation |
| 7.4 | Real-time rule status in menu bar | ✅ | Shows active rules list, refreshes automatically |

## 8. Permissions & Licensing

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 8.1 | PermissionChecker | ✅ | `hasFullDiskAccess` bool, `openSystemSettings()` URL |
| 8.2 | FDA usage description in Info.plist | ✅ | `NSFullDiskAccessUsageDescription` key present |
| 8.3 | Entitlements (non-sandboxed) | ✅ | `com.apple.security.app-sandbox = false`, `user-selected.read-write = true` |
| 8.4 | LicenseManager | ✅ | Validate key, store in UserDefaults, `isLicensed` check |
| 8.5 | License validation UI | ✅ | Settings panel with key input, validate button, status indicator |
| 8.6 | Trial enforcement (7-day) | ✅ | Track first launch date, block after 7 days without license (Implemented via LicenseManager) |
| 8.7 | Paddle/Gumroad SDK integration | ⬜ | Purchase flow, license key delivery, receipt validation |

## 9. App Lifecycle

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 9.1 | FolderMindApp @main | ✅ | SwiftData container, StateObject injection, WindowGroup + MenuBarExtra |
| 9.2 | SwiftData ModelContainer | ✅ | ActivityEntry + FMRuleModel, local-only (no CloudKit) |
| 9.3 | Auto-start on login | ✅ | SMAppService integration in SettingsView |
| 9.4 | Graceful shutdown | ⬜ | Stop FileWatcher, save pending state, close database |
| 9.5 | App delegate for URL handling | ⬜ | Handle `file://` opens, Spotlight activity continuation |
| 9.6 | Keyboard shortcuts | ✅ | Cmd+, (settings), Cmd+S (scan), Cmd+N (add rule) |

---

# Phase 2 — Tahoe Progressive Enhancement (macOS 26+)

## 10. Spotlight Integration

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 10.1 | SpotlightIndexer | ✅ | Index organized files with metadata, remove on undo |
| 10.2 | SpotlightQuickActions | ✅ | Register "Organize Folder" and "Toggle Rule" activities |
| 10.3 | Index on file move | ✅ | Call `SpotlightIndexer.indexOrganizedFile()` after successful move |
| 10.4 | Remove index on undo | ✅ | Call `SpotlightIndexer.removeIndexedFile()` when undoing |
| 10.5 | Index rules for search | ✅ | Call `SpotlightIndexer.indexRule()` when rule is saved |
| 10.6 | Handle Spotlight activity continuation | ✅ | AppDelegate `continue userActivity` routes to correct action |

## 11. Liquid Glass UI

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 11.1 | TahoeWindowWrappers | ✅ | Version-agnostic view selectors for onboarding + main window |
| 11.2 | OnboardingWindowView_Tahoe | ✅ | Uses Liquid Glass panel style with background bloom |
| 11.3 | MainWindowView_Tahoe | ✅ | Glass sidebar, edge-to-edge glass controls |
| 11.4 | LiquidGlassModifiers | ✅ | `liquidGlass()`, `TahoeButtonStyle` view modifiers |
| 11.5 | Legacy fallback views | ✅ | `OnboardingWindowView_Legacy`, `MainWindowView_Legacy` use current UI |
| 11.6 | @available guards everywhere | ⬜ | All Tahoe-specific code wrapped in `@available(macOS 26, *)` |

## 12. Foundation Models (Smart File Classification)

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 12.1 | SmartFileClassifier | ✅ | Actor, loads text/vision models, `classifyFile()` method |
| 12.2 | Text file classification | ✅ | Reads first 2000 chars, prompts model, returns category |
| 12.3 | Image file classification | ✅ | Vision model analyzes image content, returns category |
| 12.4 | FileClassification struct | ✅ | Category, confidence, source (AI vs rule-based) |
| 12.5 | On-device processing guarantee | ✅ | `processingLocation = .onDevice` enforced |
| 12.6 | Fallback to rule-based | ✅ | If AI unavailable or returns nil, RuleEngine.evaluate() runs |
| 12.7 | Integration with RuleEngine | 🚧 | `evaluateWithAI()` method that tries AI first, falls back to rules |
| 12.8 | Graceful degradation on pre-Tahoe | ✅ | `if #available(macOS 26, *)` guard, no crash on older OS |

## 13. MLX Image Recognition

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 13.1 | MLXImageClassifier | ✅ | Actor, loads MLX model, configures neural accelerators |
| 13.2 | M5 neural engine optimization | ✅ | `MLX.configuration.useNeuralAccelerators = true` |
| 13.3 | Image classification output | ✅ | Returns category (screenshot/photo/document/receipt) + confidence |
| 13.4 | OCR on images | ⬜ | Extracts text from document/receipt images |
| 13.5 | Fallback chain | ⬜ | MLX → Foundation Model vision → rule-based |
| 13.6 | Model bundling | ⬜ | Pre-trained classifier model included in app bundle |

## 14. Continuity (iPhone → Mac)

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 14.1 | ContinuityMonitor | ⬜ | Watches for files from iPhone (EXIF metadata, creator app) |
| 14.2 | File source detection | ⬜ | `determineFileSource()` checks creator, EXIF make/model |
| 14.3 | High-priority processing | ⬜ | Continuity files processed immediately, not debounced |
| 14.4 | User notification | ⬜ | Shows notification: "Sorted 'photo.jpg' into Receipts/" |
| 14.5 | FileSource enum | ⬜ | `.continuity` vs `.local` cases |
| 14.6 | Hand-written OCR | ⬜ | AI-powered text extraction from images/PDFs |

## 15. AI-Driven Product Strategy

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 15.1 | Vector-Based Organization | ⬜ | Use local embeddings for semantic file matching |
| 15.2 | Observation Mode | ⬜ | Passive learning from manual file moves to suggest rules |
| 15.3 | Workflow Sync (Notion/Obsidian) | ⬜ | Automated indexing/linking to PKM tools |
| 15.4 | Smart Rename (Context-Aware) | ⬜ | Generate meaningful filenames from file content |
| 15.5 | Pro AI Pack | ⬜ | Advanced model support for complex classification |

---

# Phase 3 — Polish & Distribution

## 15. UI Polish

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 15.1 | Micro-animations | ✅ | File move animations, toast notifications, expansion/collapse |
| 15.2 | Drag & drop (into app) | ✅ | Drop files onto app window to trigger rule evaluation |
| 15.3 | Drag & drop (out of app) | ✅ | Drag organized files from activity log to Finder |
| 15.4 | Toast/notification system | ✅ | Non-intrusive banners for file operations, errors, undo confirmations |
| 15.5 | Loading states | ✅ | Progress indicators for bulk operations, rule dry-runs |
| 15.6 | Error states | ✅ | User-friendly error messages with recovery suggestions |
| 15.7 | Dark mode support | ✅ | All views using semantic colors; verified in Light/Dark |
| 15.8 | Accessibility | ✅ | VoiceOver labels, keyboard navigation, Dynamic Type support |

## 16. Rule Builder (Detailed)

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 16.1 | Inline condition editing | ✅ | Inline editors per condition type |
| 16.2 | Inline action editing | ✅ | Inline editors per action type |
| 16.3 | Live preview updates | ✅ | Dry-run triggers 400ms after any condition/action change |
| 16.4 | AND/OR toggle visibility | ✅ | Only shows when 2+ conditions exist, animates in/out |
| 16.5 | Rule name editing | ✅ | TextField at top of builder, placeholder "e.g. Sort invoices" |
| 16.6 | Delete rule confirmation | ✅ | Confirmation dialog before deleting a rule |
| 16.7 | Duplicate rule | ✅ | Right-click context menu → "Duplicate" creates copy |
| 16.8 | Rule reordering | ✅ | Drag to reorder rules (changes priority) |
| 16.9 | Export/import rules | ✅ | JSON export/import via `RuleBackupManager` |

## 17. Testing

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 17.1 | Unit tests: RuleEngine | ✅ | Test all 11 condition types with sample files |
| 17.2 | Unit tests: ConflictResolver | ✅ | Test collision detection, counter naming, folder creation |
| 17.3 | Unit tests: RenameEngine | ✅ | Test all token replacements with sample filenames |
| 17.4 | Unit tests: FileWatcher | ⬜ | Test event classification, debouncing behavior |
| 17.5 | Integration tests: Full pipeline | ⬜ | File arrives → watched → matched → moved → logged |
| 17.6 | UI tests: Onboarding flow | ⬜ | Complete all 6 steps, verify state persistence |
| 17.7 | UI tests: Rule CRUD | ⬜ | Create, edit, delete, toggle rules in main window |

## 18. Distribution

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 18.1 | App icon | ✅ | 1024×1024 icon, all required @1x/@2x sizes |
| 18.2 | Code signing | ✅ | Developer ID certificate, notarization |
| 18.3 | DMG installer | ✅ | Custom background, drag-to-Applications layout |
| 18.4 | Sparkle updates | ⬜ | In-app update checking, release notes, download |
| 18.5 | Landing page | ⬜ | Hero, problem, how it works, pricing, FAQ, download CTA |
| 18.6 | Privacy policy | ⬜ | "Files never leave your Mac" statement, data collection (none) |
| 18.7 | Payment integration | ⬜ | Paddle or Gumroad SDK, license key delivery |
| 18.8 | Analytics (optional) | ⬜ | Anonymous usage metrics (rules created, files sorted) — opt-in |

## 19. Strategic Growth

| # | Item | Status | Acceptance Criteria |
|---|------|--------|---------------------|
| 19.1 | Time-Saved Dashboard | ⬜ | Weekly report showing quantified efficiency gains |
| 19.2 | Community Rule Templates | ⬜ | Shareable JSON rule packs for specific workflows |
| 19.3 | Referral Loops | ⬜ | "Invite a friend" to extend trial or get a discount |
| 19.4 | B2B Fleet Management | ⬜ | Manage rules across a company/team (Future) |

---

# File Inventory

## Implemented (28 files)

```
FolderMind/
├── FolderMindApp.swift                    ✅ App entry, SwiftData, scenes
├── Info.plist                             ✅ FDA permission description
├── FolderMind.entitlements                ✅ Non-sandboxed config
├── Models/
│   ├── AppState.swift                     ✅ Onboarding state machine
│   ├── OnboardingStep.swift               ✅ 6-step enum
│   ├── RuleModel.swift                    ✅ FMRule, conditions, actions
│   ├── FMRuleModel.swift                  ✅ SwiftData persistence model
│   ├── ActivityEntry.swift                ✅ Activity log + undo model
│   └── StarterRule.swift                  ✅ Onboarding preset rules
├── Services/
│   ├── FileWatcher.swift                  ✅ FSEvents + debouncer
│   ├── RuleEngine.swift                   ✅ Condition evaluation + dry-run
│   ├── ConflictResolver.swift             ✅ Filename collision handling
│   ├── RenameEngine.swift                 ✅ Template token replacement
│   ├── RuleStore.swift                    ✅ CRUD for rules
│   ├── FMUndoManager.swift                ✅ Undo/redo with SwiftData
│   ├── PermissionChecker.swift            ✅ FDA verification
│   ├── LicenseManager.swift               ✅ One-time license validation
│   └── Tahoe/
│       ├── SpotlightIndexer.swift         ✅ CoreSpotlight indexing
│       └── SpotlightQuickActions.swift    ✅ NSUserActivity quick actions
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingCoordinatorView.swift ✅ Step coordinator
│   │   ├── WelcomeStepView.swift          ✅ Welcome screen
│   │   ├── FolderPickerStepView.swift     ✅ Folder selection
│   │   ├── StarterRulesStepView.swift     ✅ Rule toggles with coordinator binding
│   │   ├── PermissionsStepView.swift      ✅ FDA permission
│   │   ├── ProcessingStepView.swift       ✅ Live sorting with starter rule matching
│   │   └── DoneStepView.swift             ✅ Completion screen
│   ├── MainWindow/
│   │   ├── MainWindowView.swift           🚧 Main UI with rule builder entry points
│   │   └── RuleBuilderView.swift          🚧 First usable custom rule builder
│   ├── Components/
│   │   ├── FMPrimaryButtonStyle.swift     ✅ Primary button style
│   │   └── MenuBarView.swift              ✅ Menu bar extras
│   └── Tahoe/
│       └── TahoeWindowWrappers.swift      ✅ Version-agnostic view selectors
```

## Not Yet Created (0 files)

| File | Phase | Priority |
|------|-------|----------|
| `Views/MainWindow/RuleBuilderView.swift` | 1 | HIGH — first usable version implemented |
| `Services/Tahoe/SmartFileClassifier.swift` | 2 | MEDIUM |
| `Services/Tahoe/MLXImageClassifier.swift` | 2 | LOW |
| `Services/Tahoe/ContinuityMonitor.swift` | 2 | LOW |
| `Views/MainWindow/ActivityFeedView.swift` | 1 | HIGH — currently embedded in MainWindowView |
| `Views/MainWindow/SettingsView.swift` | 1 | MEDIUM |
| `Views/Components/ToastView.swift` | 3 | MEDIUM |
| `Views/Tahoe/LiquidGlassModifiers.swift` | 2 | MEDIUM |
| `Helpers/RuleBackupManager.swift` | 3 | LOW |
| `Helpers/BookmarkManager.swift` | 2 | LOW (MAS Phase) |
| `Services/Tahoe/DeepSemanticEngine.swift` | 2 | HIGH |
| `Models/GrowthReport.swift` | 3 | LOW |

---

# Priority Order for Next Work

## Sprint 1 — Finish Phase 1 Core (Ship-able MVP)

1. **File watching lifecycle** (#3.7) — ✅ Start watching saved rule folders and process new files automatically (Cascading rules + manual scan fixed)
2. **RuleBuilder polish** (#2.8-2.12, #16.1-16.5) — ✅ Multiple chips/actions, token buttons, inline editing polish, Priority 1-5 picker
3. **Onboarding window config** (#1.11, 1.12) — ✅ Proper compact onboarding window behavior
4. **MainWindow polish** (#6.3, #6.8) — ✅ Rule detail, window persistence
5. **Menu Bar Integration** (#7.4) — ✅ Open main window, real-time rule status
6. **Trial enforcement** (#8.6) — ✅ 7-day trial gate

## Sprint 2 — Polish & Configuration (CURRENT FOCUS)

7. **Settings & Preferences** (#6.7, #8.5, #9.3) — ✅ License key input, Auto-start on login toggle, Keyboard shortcuts
8. **UI polish** (#15.1-15.8) — ✅ Animations, drag-drop (in/out), dark mode (native)
9. **Rule builder advanced** (#16.6-16.9) — ✅ Duplicate, export/import (JSON)
10. **Distribution (Core)** (#18.1-18.3) — ✅ Icon, signing, DMG
11. **Testing (Core)** (#17.1-17.3) — ✅ Unit tests for engine/logic
12. **Web & Growth** (#18.5-18.7) — ⬜ Landing page, payments, Sparkle

## Sprint 3 — Tahoe & Growth (NEXT FOCUS)

10. **Spotlight integration** (#10.3-10.6) — Wire up existing indexer to actual operations
11. **Liquid Glass UI** (#11.2-11.6) — Actual Tahoe API integration
12. **Foundation Models** (#12.1-12.8) — Smart file classification
13. **Observation Mode** (#15.2) — Passive learning system
14. **MLX** (#13.1-13.6) — Image recognition (requires M5 Mac)
15. **Continuity** (#14.1-14.5) — iPhone photo auto-sort
16. **Growth Dashboard** (#19.1) — Time-saved reporting

---

# Acceptance Criteria: "Ready to Ship"

The product is ready to sell at $14.99 when ALL Phase 1 items are ✅:

- [ ] User can complete onboarding in < 90 seconds
- [ ] User can pick a folder, toggle starter rules, see files sorted
- [ ] User can create custom rules with the chip-based builder
- [ ] Files are watched and sorted automatically in real-time
- [ ] Every action is logged and reversible (undo)
- [ ] Filename conflicts are handled gracefully (no data loss)
- [ ] Menu bar shows active status and quick controls
- [ ] 7-day trial works, license key unlocks full version
- [ ] App auto-starts on login (optional)
- [ ] Dark mode works without visual bugs
- [ ] App is notarized and distributable as .dmg
- [ ] Landing page converts visitors to downloads
