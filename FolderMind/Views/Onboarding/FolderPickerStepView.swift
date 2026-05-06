import SwiftUI

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

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDraggingOver ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .frame(height: 160)
                .overlay {
                    VStack(spacing: 12) {
                        if let url = watchedFolderURL {
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
