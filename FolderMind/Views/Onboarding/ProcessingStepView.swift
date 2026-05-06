import SwiftUI

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
        return nil
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
