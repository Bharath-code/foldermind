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

        var matches: [ProcessedFile] = []

        for fileURL in files where isRegularFile(fileURL) {
            if let match = matchRule(for: fileURL) {
                guard let processed = move(fileURL, toFolderNamed: match.destination, ruleName: match.ruleName) else {
                    continue
                }
                matches.append(processed)
            }
        }

        guard !matches.isEmpty else {
            completeScan()
            return
        }

        for processed in matches {
            if Task.isCancelled { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                processedFiles.append(processed)
                totalProcessed += 1
            }

            try? await Task.sleep(for: .milliseconds(80))
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

    func matchRule(for url: URL) -> (destination: String, ruleName: String)? {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        for rule in enabledRules where rule.isEnabled {
            switch rule.name {
            case "Screenshots":
                if ext == "png" && (name.contains("screen shot") || name.contains("screenshot")) {
                    return ("Screenshots", rule.name)
                }
            case "Invoices & receipts":
                if ext == "pdf" && (name.contains("invoice") || name.contains("receipt")) {
                    return ("Finance", rule.name)
                }
            case "Archives":
                if ["zip", "tar", "gz", "tgz", "rar", "7z"].contains(ext) {
                    return ("Archives", rule.name)
                }
            case "Photos & images":
                if ["jpg", "jpeg", "heic", "webp", "gif", "tiff"].contains(ext) {
                    return ("Photos", rule.name)
                }
            case "Videos":
                if ["mp4", "mov", "mkv", "avi", "webm"].contains(ext) {
                    return ("Videos", rule.name)
                }
            case "Documents":
                if ["txt", "md", "rtf", "doc", "docx", "pages", "xls", "xlsx", "numbers", "key", "ppt", "pptx", "csv", "pdf"].contains(ext) {
                    return ("Documents", rule.name)
                }
            case "Disk images":
                if ["dmg", "pkg"].contains(ext) {
                    return ("Installers", rule.name)
                }
            case "Audio":
                if ["mp3", "m4a", "flac", "wav", "aac"].contains(ext) {
                    return ("Music", rule.name)
                }
            default:
                continue
            }
        }

        return nil
    }

    private func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private func move(_ fileURL: URL, toFolderNamed folderName: String, ruleName: String) -> ProcessedFile? {
        let fm = FileManager.default
        let destinationFolder = folderURL.appendingPathComponent(folderName, isDirectory: true)

        do {
            try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            let destinationURL = uniqueDestinationURL(
                in: destinationFolder,
                originalName: fileURL.lastPathComponent
            )
            try fm.moveItem(at: fileURL, to: destinationURL)
            undoManager.logAction(
                ActivityEntry(
                    ruleName: ruleName,
                    sourceURL: fileURL,
                    destinationURL: destinationURL,
                    actionType: .moved
                )
            )
            return ProcessedFile(
                originalName: fileURL.lastPathComponent,
                destinationFolder: folderName,
                rule: ruleName
            )
        } catch {
            return nil
        }
    }

    private func uniqueDestinationURL(in folder: URL, originalName: String) -> URL {
        let fm = FileManager.default
        let originalURL = folder.appendingPathComponent(originalName)

        guard fm.fileExists(atPath: originalURL.path) else {
            return originalURL
        }

        let name = (originalName as NSString).deletingPathExtension
        let ext = (originalName as NSString).pathExtension

        for index in 1...999 {
            let candidateName = ext.isEmpty
                ? "\(name) \(index)"
                : "\(name) \(index).\(ext)"
            let candidateURL = folder.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return folder.appendingPathComponent(UUID().uuidString + "-" + originalName)
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
