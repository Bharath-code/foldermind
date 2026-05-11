import SwiftUI

struct BuilderCondition: Identifiable {
    let id = UUID()
    var condition: RuleCondition
}

struct BuilderAction: Identifiable {
    let id = UUID()
    var action: RuleAction
}

struct RuleBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ruleStore: RuleStore

    let existingRule: FMRule?

    // MARK: – Builder UI state
    @State private var ruleName: String
    @State private var isEnabled: Bool
    @State private var watchedFolderURL: URL?
    @State private var conditionLogic: ConditionLogic
    @State private var priority: Int

    @State private var builderConditions: [BuilderCondition]
    @State private var builderActions: [BuilderAction]

    @State private var dryRunMatches: [DryRunMatch] = []
    @State private var isPreviewLoading = false

    init(existingRule: FMRule? = nil) {
        self.existingRule = existingRule
        if let existing = existingRule {
            _ruleName = State(initialValue: existing.name)
            _isEnabled = State(initialValue: existing.isEnabled)
            _watchedFolderURL = State(initialValue: existing.watchedFolderURL)
            _conditionLogic = State(initialValue: existing.conditionLogic)
            _priority = State(initialValue: existing.priority)
            _builderConditions = State(initialValue: existing.conditions.map { BuilderCondition(condition: $0) })
            _builderActions = State(initialValue: existing.actions.map { BuilderAction(action: $0) })
        } else {
            _ruleName = State(initialValue: "")
            _isEnabled = State(initialValue: true)
            _watchedFolderURL = State(initialValue: nil)
            _conditionLogic = State(initialValue: .all)
            _priority = State(initialValue: 3) // Normal
            _builderConditions = State(initialValue: [BuilderCondition(condition: .extensionIs([""]))])
            _builderActions = State(initialValue: [BuilderAction(action: .moveToFolder(URL(fileURLWithPath: NSHomeDirectory())))])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    basicsSection
                    conditionSection
                    actionSection
                    previewSection
                }
                .padding(24)
            }

            Divider()

            HStack {
                if let existingRule {
                    Button("Delete Rule", role: .destructive) {
                        ruleStore.deleteRule(existingRule)
                        dismiss()
                    }
                    .keyboardShortcut(.delete, modifiers: [.command])
                }

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Rule") {
                    saveRule()
                }
                .buttonStyle(FMPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(20)
        }
        .frame(minWidth: 720, minHeight: 680)
        .onAppear { loadExistingRule() }
        .onChange(of: existingRule?.id) { _, _ in loadExistingRule() }
        .task { await refreshPreview() }
        .onChange(of: builderConditions.map { $0.condition }) { _, _ in Task { await refreshPreview() } }
        .onChange(of: builderActions.map { $0.action }) { _, _ in Task { await refreshPreview() } }
        .onChange(of: watchedFolderURL) { _, _ in Task { await refreshPreview() } }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(existingRule == nil ? "New Rule" : "Edit Rule")
                    .font(.system(size: 22, weight: .semibold))
                Text("Choose what FolderMind watches, matches, and does next.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enabled", isOn: $isEnabled)
                .toggleStyle(.switch)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Basics", systemImage: "slider.horizontal.3")

            HStack {
                TextField("Rule name (e.g. Sort Invoices)", text: $ruleName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                HStack {
                    Text("Priority:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $priority) {
                        Text("Highest (5)").tag(5)
                        Text("High (4)").tag(4)
                        Text("Normal (3)").tag(3)
                        Text("Low (2)").tag(2)
                        Text("Lowest (1)").tag(1)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(6)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(watchedFolderURL?.lastPathComponent ?? "No watched folder selected")
                        .font(.system(size: 13, weight: .medium))
                    Text(watchedFolderURL?.path ?? "Pick the folder this rule should monitor.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("Choose Folder", systemImage: "folder") {
                    chooseFolder { watchedFolderURL = $0 }
                }
            }
            .padding(12)
            .background(sectionBackground)
            .cornerRadius(8)
        }
    }

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "When", systemImage: "line.3.horizontal.decrease.circle")
                Spacer()
                if builderConditions.count > 1 {
                    Picker("", selection: $conditionLogic) {
                        Text("All conditions must match").tag(ConditionLogic.all)
                        Text("Any condition can match").tag(ConditionLogic.any)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 200)
                }
            }

            VStack(spacing: 8) {
                ForEach($builderConditions) { $item in
                    ConditionRowView(item: $item) {
                        if builderConditions.count > 1 {
                            withAnimation(.spring()) {
                                builderConditions.removeAll { $0.id == item.id }
                            }
                        }
                    }
                }
            }

            Button {
                withAnimation(.spring()) {
                    builderConditions.append(BuilderCondition(condition: .extensionIs([""])))
                }
            } label: {
                Label("Add Condition", systemImage: "plus.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Then", systemImage: "arrow.triangle.branch")

            VStack(spacing: 8) {
                ForEach($builderActions) { $item in
                    ActionRowView(item: $item) {
                        if builderActions.count > 1 {
                            withAnimation(.spring()) {
                                builderActions.removeAll { $0.id == item.id }
                            }
                        }
                    }
                }
            }

            Button {
                withAnimation(.spring()) {
                    builderActions.append(BuilderAction(action: .moveToFolder(watchedFolderURL ?? URL(fileURLWithPath: NSHomeDirectory()))))
                }
            } label: {
                Label("Add Action", systemImage: "plus.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Preview", systemImage: "eye")
                Spacer()
                if isPreviewLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if dryRunMatches.isEmpty {
                ContentUnavailableView(
                    "No preview matches",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Pick a folder and condition to preview matching files.")
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(dryRunMatches) { match in
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(match.originalPath.lastPathComponent)
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(match.resultFolder)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .font(.system(size: 12))
                        .padding(.vertical, 8)

                        if match.id != dryRunMatches.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(sectionBackground)
                .cornerRadius(8)
            }
        }
    }

    private var sectionBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var canSave: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && watchedFolderURL != nil
            && !builderConditions.isEmpty
            && !builderActions.isEmpty
    }

    private func saveRule() {
        guard let watchedFolderURL, !builderConditions.isEmpty, !builderActions.isEmpty else { return }

        let rule = FMRule(
            id: existingRule?.id ?? UUID(),
            name: ruleName.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: builderConditions.map { $0.condition },
            conditionLogic: conditionLogic,
            actions: builderActions.map { $0.action },
            priority: priority
        )

        print("[RuleBuilder] Saving rule: \(rule.name) (\(rule.id)) with \(rule.conditions.count) conditions, \(rule.actions.count) actions")
        ruleStore.saveRule(rule)
        dismiss()
    }

    @MainActor
    private func refreshPreview() async {
        guard let watchedFolderURL, !builderConditions.isEmpty, !builderActions.isEmpty else {
            dryRunMatches = []
            return
        }

        isPreviewLoading = true
        let previewRule = FMRule(
            id: existingRule?.id ?? UUID(),
            name: ruleName.isEmpty ? "Preview" : ruleName,
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: builderConditions.map { $0.condition },
            conditionLogic: conditionLogic,
            actions: builderActions.map { $0.action },
            priority: priority
        )

        dryRunMatches = await RuleEngine.shared.dryRun(rule: previewRule, limit: 10)
        isPreviewLoading = false
    }


    private func loadExistingRule() {
        if let existing = existingRule {
            ruleName = existing.name
            isEnabled = existing.isEnabled
            watchedFolderURL = existing.watchedFolderURL
            conditionLogic = existing.conditionLogic
            priority = existing.priority
            builderConditions = existing.conditions.map { BuilderCondition(condition: $0) }
            builderActions = existing.actions.map { BuilderAction(action: $0) }
        } else {
            ruleName = ""
            isEnabled = true
            watchedFolderURL = nil
            conditionLogic = .all
            priority = 3 // Normal
            builderConditions = [BuilderCondition(condition: .extensionIs([""]))]
            builderActions = [BuilderAction(action: .moveToFolder(URL(fileURLWithPath: NSHomeDirectory())))]
        }
    }

    private func chooseFolder(onSelect: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }
}

// MARK: - Components

struct ConditionRowView: View {
    @Binding var item: BuilderCondition
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Button("Extension is") { item.condition = .extensionIs([""]) }
                Button("Name contains") { item.condition = .nameContains("") }
                Button("Name starts with") { item.condition = .nameStartsWith("") }
                Button("Name ends with") { item.condition = .nameEndsWith("") }
                Button("Name matches regex") { item.condition = .nameMatchesRegex("") }
                Button("Larger than (MB)") { item.condition = .fileSizeGreaterThan(10) }
                Button("Smaller than (MB)") { item.condition = .fileSizeLessThan(10) }
                Button("Created within (days)") { item.condition = .dateCreatedWithinDays(7) }
                Button("Modified within (days)") { item.condition = .dateModifiedWithinDays(7) }
                Button("Location") { item.condition = .isInSubfolder(true) }
            } label: {
                Text(item.condition.typeDisplayName)
                    .frame(width: 150, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(6)

            conditionInput

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .opacity(0.6)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    var conditionInput: some View {
        switch item.condition {
        case .extensionIs(let exts):
            let binding = Binding(
                get: { exts.joined(separator: ", ") },
                set: { item.condition = .extensionIs($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }) }
            )
            TextField("e.g. pdf, txt", text: binding)
                .textFieldStyle(.plain)
        case .nameContains(let s):
            TextField("Text", text: Binding(get: { s }, set: { item.condition = .nameContains($0) }))
                .textFieldStyle(.plain)
        case .nameStartsWith(let s):
            TextField("Text", text: Binding(get: { s }, set: { item.condition = .nameStartsWith($0) }))
                .textFieldStyle(.plain)
        case .nameEndsWith(let s):
            TextField("Text", text: Binding(get: { s }, set: { item.condition = .nameEndsWith($0) }))
                .textFieldStyle(.plain)
        case .nameMatchesRegex(let r):
            TextField("Regex", text: Binding(get: { r }, set: { item.condition = .nameMatchesRegex($0) }))
                .textFieldStyle(.plain)
        case .fileSizeGreaterThan(let m):
            Stepper("\(m) MB", value: Binding(get: { m }, set: { item.condition = .fileSizeGreaterThan($0) }), in: 1...10000)
        case .fileSizeLessThan(let m):
            Stepper("\(m) MB", value: Binding(get: { m }, set: { item.condition = .fileSizeLessThan($0) }), in: 1...10000)
        case .dateCreatedWithinDays(let d):
            Stepper("\(d) days", value: Binding(get: { d }, set: { item.condition = .dateCreatedWithinDays($0) }), in: 1...3650)
        case .dateModifiedWithinDays(let d):
            Stepper("\(d) days", value: Binding(get: { d }, set: { item.condition = .dateModifiedWithinDays($0) }), in: 1...3650)
        case .isInSubfolder(let v):
            Picker("", selection: Binding(get: { v }, set: { item.condition = .isInSubfolder($0) })) {
                Text("In a subfolder").tag(true)
                Text("In the root folder").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

struct ActionRowView: View {
    @Binding var item: BuilderAction
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Menu {
                    Button("Move to folder") { item.action = .moveToFolder(URL(fileURLWithPath: NSHomeDirectory())) }
                    Button("Copy to folder") { item.action = .copyToFolder(URL(fileURLWithPath: NSHomeDirectory())) }
                    Button("Rename file") { item.action = .renameWith(template: "{name}-new.{ext}") }
                    Button("Add Tag") { item.action = .addFinderTag("Important") }
                    Button("Run Script") { item.action = .runShellScript("echo \"processed\"") }
                    Button("Delete") { item.action = .deleteAfterDays(0) }
                    Button("Open with App") { item.action = .openWithApp(URL(fileURLWithPath: "/Applications/Preview.app")) }
                } label: {
                    Text(item.action.typeDisplayName)
                        .frame(width: 130, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(6)

                actionInput

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }

            if case .renameWith(let t) = item.action {
                RenameTokenBar { token in
                    item.action = .renameWith(template: t + token)
                }
                .padding(.leading, 150) // align with input
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    var actionInput: some View {
        switch item.action {
        case .moveToFolder(let url), .copyToFolder(let url):
            HStack {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose...") {
                    chooseFolder { selectedUrl in
                        if case .moveToFolder = item.action {
                            item.action = .moveToFolder(selectedUrl)
                        } else {
                            item.action = .copyToFolder(selectedUrl)
                        }
                    }
                }
            }
        case .renameWith(let t):
            TextField("Template", text: Binding(get: { t }, set: { item.action = .renameWith(template: $0) }))
                .textFieldStyle(.plain)
        case .addFinderTag(let t):
            TextField("Tag Name", text: Binding(get: { t }, set: { item.action = .addFinderTag($0) }))
                .textFieldStyle(.plain)
        case .runShellScript(let s):
            TextField("Script command", text: Binding(get: { s }, set: { item.action = .runShellScript($0) }))
                .textFieldStyle(.plain)
        case .deleteAfterDays(let d):
            HStack {
                Stepper("\(d) days", value: Binding(get: { d }, set: { item.action = .deleteAfterDays($0) }), in: 0...365)
                if d == 0 { Text("(Immediate)").foregroundColor(.secondary) }
            }
        case .openWithApp(let url):
            HStack {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                Spacer()
                Button("Choose...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.application]
                    if panel.runModal() == .OK, let selectedUrl = panel.url {
                        item.action = .openWithApp(selectedUrl)
                    }
                }
            }
        }
    }

    private func chooseFolder(onSelect: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }
}

struct RenameTokenBar: View {
    let onInsert: (String) -> Void
    
    let tokens = [
        ("{name}", "Original name"),
        ("{ext}", "Extension"),
        ("{date}", "YYYY-MM-DD"),
        ("{year}", "YYYY"),
        ("{month}", "MM"),
        ("{day}", "DD"),
        ("{time}", "HH-MM-SS"),
        ("{counter}", "001"),
        ("{parent}", "Folder name")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tokens, id: \.0) { token in
                    Button {
                        onInsert(token.0)
                    } label: {
                        Text(token.0)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(token.1)
                }
            }
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

extension RuleCondition {
    var typeDisplayName: String {
        switch self {
        case .extensionIs: return "Extension is"
        case .nameContains: return "Name contains"
        case .nameStartsWith: return "Name starts with"
        case .nameEndsWith: return "Name ends with"
        case .nameMatchesRegex: return "Name matches regex"
        case .fileSizeGreaterThan: return "Larger than"
        case .fileSizeLessThan: return "Smaller than"
        case .dateCreatedWithinDays: return "Created within"
        case .dateModifiedWithinDays: return "Modified within"
        case .isInSubfolder: return "Location"
        }
    }
}

extension RuleAction {
    var typeDisplayName: String {
        switch self {
        case .moveToFolder: return "Move to folder"
        case .copyToFolder: return "Copy to folder"
        case .renameWith: return "Rename file"
        case .addFinderTag: return "Add tag"
        case .runShellScript: return "Run script"
        case .deleteAfterDays: return "Delete"
        case .openWithApp: return "Open with App"
        }
    }
}
