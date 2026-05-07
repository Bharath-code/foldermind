import SwiftUI

struct RuleBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ruleStore: RuleStore

    let existingRule: FMRule?

    @State private var ruleName: String
    @State private var isEnabled: Bool
    @State private var watchedFolderURL: URL?
    @State private var conditionLogic: ConditionLogic
    @State private var conditionType: ConditionBuilderType
    @State private var extensionText: String
    @State private var nameText: String
    @State private var actionType: ActionBuilderType
    @State private var destinationURL: URL?
    @State private var renameTemplate: String
    @State private var dryRunMatches: [DryRunMatch] = []
    @State private var isPreviewLoading = false

    init(existingRule: FMRule? = nil) {
        self.existingRule = existingRule
        _ruleName = State(initialValue: existingRule?.name ?? "")
        _isEnabled = State(initialValue: existingRule?.isEnabled ?? true)
        _watchedFolderURL = State(initialValue: existingRule?.watchedFolderURL)
        _conditionLogic = State(initialValue: existingRule?.conditionLogic ?? .all)
        _conditionType = State(initialValue: ConditionBuilderType(from: existingRule?.conditions.first))
        _extensionText = State(initialValue: existingRule?.extensionSeed ?? "txt, md, pdf")
        _nameText = State(initialValue: existingRule?.nameSeed ?? "")
        _actionType = State(initialValue: ActionBuilderType(from: existingRule?.actions.first))
        _destinationURL = State(initialValue: existingRule?.destinationSeed)
        _renameTemplate = State(initialValue: existingRule?.renameSeed ?? "{name}-{date}.{ext}")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    basicsSection
                    conditionSection
                    actionSection
                    previewSection
                }
                .padding(24)
            }

            Divider()

            HStack {
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
        .frame(minWidth: 680, minHeight: 640)
        .task { await refreshPreview() }
        .onChange(of: conditionType) { _, _ in Task { await refreshPreview() } }
        .onChange(of: extensionText) { _, _ in Task { await refreshPreview() } }
        .onChange(of: nameText) { _, _ in Task { await refreshPreview() } }
        .onChange(of: actionType) { _, _ in Task { await refreshPreview() } }
        .onChange(of: destinationURL) { _, _ in Task { await refreshPreview() } }
        .onChange(of: renameTemplate) { _, _ in Task { await refreshPreview() } }
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

            TextField("Rule name", text: $ruleName)
                .textFieldStyle(.roundedBorder)

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
                    chooseWatchedFolder()
                }
            }
            .padding(12)
            .background(sectionBackground)
        }
    }

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "When", systemImage: "line.3.horizontal.decrease.circle")

            Picker("Match", selection: $conditionType) {
                ForEach(ConditionBuilderType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if conditionType == .fileExtension {
                TextField("Extensions, separated by commas", text: $extensionText)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("Text to match in the file name", text: $nameText)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Logic", selection: $conditionLogic) {
                Text("All conditions").tag(ConditionLogic.all)
                Text("Any condition").tag(ConditionLogic.any)
            }
            .pickerStyle(.segmented)
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Then", systemImage: "arrow.triangle.branch")

            Picker("Action", selection: $actionType) {
                ForEach(ActionBuilderType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if actionType == .rename {
                TextField("Rename template", text: $renameTemplate)
                    .textFieldStyle(.roundedBorder)
                Text("Available tokens: {name}, {ext}, {date}, {year}, {month}, {day}, {time}, {counter}, {parent}")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destinationURL?.lastPathComponent ?? "No destination selected")
                            .font(.system(size: 13, weight: .medium))
                        Text(destinationURL?.path ?? "Pick where matching files should go.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button("Choose Destination", systemImage: "folder.badge.plus") {
                        chooseDestinationFolder()
                    }
                }
                .padding(12)
                .background(sectionBackground)
            }
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
            }
        }
    }

    private var sectionBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var canSave: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && watchedFolderURL != nil
            && !builtConditions.isEmpty
            && builtAction != nil
    }

    private var builtConditions: [RuleCondition] {
        switch conditionType {
        case .fileExtension:
            let extensions = extensionText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "") }
                .filter { !$0.isEmpty }
            return extensions.isEmpty ? [] : [.extensionIs(extensions)]
        case .nameContains:
            let value = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? [] : [.nameContains(value)]
        case .nameStartsWith:
            let value = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? [] : [.nameStartsWith(value)]
        }
    }

    private var builtAction: RuleAction? {
        switch actionType {
        case .move:
            guard let destinationURL else { return nil }
            return .moveToFolder(destinationURL)
        case .copy:
            guard let destinationURL else { return nil }
            return .copyToFolder(destinationURL)
        case .rename:
            let template = renameTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            return template.isEmpty ? nil : .renameWith(template: template)
        }
    }

    private func saveRule() {
        guard let watchedFolderURL, let builtAction else { return }

        let rule = FMRule(
            id: existingRule?.id ?? UUID(),
            name: ruleName.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: builtConditions,
            conditionLogic: conditionLogic,
            actions: [builtAction],
            priority: existingRule?.priority ?? ruleStore.rules.count
        )

        ruleStore.saveRule(rule)
        dismiss()
    }

    @MainActor
    private func refreshPreview() async {
        guard let watchedFolderURL, let builtAction, !builtConditions.isEmpty else {
            dryRunMatches = []
            return
        }

        isPreviewLoading = true
        let previewRule = FMRule(
            id: existingRule?.id ?? UUID(),
            name: ruleName.isEmpty ? "Preview" : ruleName,
            isEnabled: isEnabled,
            watchedFolderURL: watchedFolderURL,
            conditions: builtConditions,
            conditionLogic: conditionLogic,
            actions: [builtAction],
            priority: existingRule?.priority ?? 0
        )

        dryRunMatches = await RuleEngine.shared.dryRun(rule: previewRule, limit: 10)
        isPreviewLoading = false
    }

    private func chooseWatchedFolder() {
        chooseFolder { watchedFolderURL = $0 }
    }

    private func chooseDestinationFolder() {
        chooseFolder { destinationURL = $0 }
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

private struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private enum ConditionBuilderType: String, CaseIterable, Identifiable {
    case fileExtension
    case nameContains
    case nameStartsWith

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileExtension: return "Extension"
        case .nameContains: return "Name contains"
        case .nameStartsWith: return "Name starts with"
        }
    }

    init(from condition: RuleCondition?) {
        switch condition {
        case .nameContains:
            self = .nameContains
        case .nameStartsWith:
            self = .nameStartsWith
        default:
            self = .fileExtension
        }
    }
}

private enum ActionBuilderType: String, CaseIterable, Identifiable {
    case move
    case copy
    case rename

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: return "Move"
        case .copy: return "Copy"
        case .rename: return "Rename"
        }
    }

    init(from action: RuleAction?) {
        switch action {
        case .copyToFolder:
            self = .copy
        case .renameWith:
            self = .rename
        default:
            self = .move
        }
    }
}

private extension FMRule {
    var extensionSeed: String {
        for condition in conditions {
            if case .extensionIs(let extensions) = condition {
                return extensions.joined(separator: ", ")
            }
        }
        return ""
    }

    var nameSeed: String {
        for condition in conditions {
            switch condition {
            case .nameContains(let value), .nameStartsWith(let value):
                return value
            default:
                continue
            }
        }
        return ""
    }

    var destinationSeed: URL? {
        for action in actions {
            switch action {
            case .moveToFolder(let url), .copyToFolder(let url):
                return url
            default:
                continue
            }
        }
        return nil
    }

    var renameSeed: String {
        for action in actions {
            if case .renameWith(let template) = action {
                return template
            }
        }
        return ""
    }
}
