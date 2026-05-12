import SwiftUI

struct ProcessingStepView: View {
    @EnvironmentObject var undoManager: FMUndoManager

    let folderURL: URL
    let enabledRules: [StarterRule]
    var onAdvance: (Int) -> Void

    @State private var processedFiles: [ProcessedFile] = []
    @State private var isScanning = true
    @State private var totalProcessed = 0
    @State private var scanCompleted = false
    @State private var didStartProcessing = false

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
                .onChange(of: processedFiles.count) { oldValue, newValue in
                    if let last = processedFiles.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Spacer()

            if scanCompleted {
                VStack(spacing: 12) {
                    Text(resultMessage)
                        .font(.system(size: 15, weight: .medium))
                    Button(totalProcessed > 0 ? "See the results" : "Continue") {
                        onAdvance(totalProcessed)
                    }
                        .buttonStyle(FMPrimaryButtonStyle())
                }
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: folderURL) {
            await startProcessing()
        }
        .onAppear {
            scheduleCompletionFallback()
        }
    }

    private var resultMessage: String {
        if totalProcessed == 0 {
            return "No matching files found"
        }
        return "Sorted \(totalProcessed) file\(totalProcessed == 1 ? "" : "s")"
    }

    @MainActor
    func startProcessing() async {
        guard !didStartProcessing else { return }
        didStartProcessing = true

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            completeScan()
            return
        }

        let fmRules = enabledRules.map { $0.asFMRule(watchedFolderURL: folderURL) }
        let engine = RuleEngine.shared

        for fileURL in files where isRegularFile(fileURL) {
            if Task.isCancelled { return }

            for rule in fmRules {
                let matched = await engine.evaluate(rule: rule, for: fileURL)
                if matched {
                    let result = await engine.executeActions(rule.actions, for: fileURL)
                    if case .moved(let dest) = result {
                        let processed = ProcessedFile(
                            originalName: fileURL.lastPathComponent,
                            destinationFolder: dest.deletingLastPathComponent().lastPathComponent,
                            rule: rule.name
                        )
                        
                        // Surface to UI
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            processedFiles.append(processed)
                            totalProcessed += 1
                        }
                        
                        // Log to undo manager for immediate regret support
                        undoManager.logAction(
                            ActivityEntry(
                                ruleName: rule.name,
                                sourceURL: fileURL,
                                destinationURL: dest,
                                actionType: .moved
                            )
                        )
                        
                        // Artificial delay for "magic" effect
                        try? await Task.sleep(for: .milliseconds(120))
                    }
                    // First rule wins
                    break
                }
            }
        }

        completeScan()
    }

    @MainActor
    private func completeScan() {
        isScanning = false
        scanCompleted = true
    }

    private func scheduleCompletionFallback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if !scanCompleted {
                completeScan()
            }
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
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
