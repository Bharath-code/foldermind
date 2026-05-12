import SwiftUI

struct FolderPickerStepView: View {
    @Binding var watchedFolderURL: URL?
    @State private var isDraggingOver = false
    var onAdvance: () -> Void

    var body: some View {
        ZStack {
            // Watermark Layer
            Text("SOURCE")
                .fmWatermark()
                .offset(y: -240)
            
            VStack(spacing: FMDesign.Spacing.xl) {
                VStack(spacing: FMDesign.Spacing.sm) {
                    Text("Select a Source Folder")
                        .fmTitle()
                    
                    Text("FolderMind will watch this directory and apply logic instantly.")
                        .fmHeadline()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, FMDesign.Spacing.lg)

                Spacer()

                // Interactive Spatial Well
                ZStack {
                    // Refractive background well
                    VisualEffectView(material: .selection, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(
                                    isDraggingOver ? FMDesign.Color.logicBlue : FMDesign.Color.glassStroke, 
                                    lineWidth: isDraggingOver ? 2 : 0.5
                                )
                        }
                        .shadow(color: isDraggingOver ? FMDesign.Color.logicBlue.opacity(0.2) : .clear, radius: 20)
                    
                    dropZoneContent
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .padding(.horizontal, FMDesign.Spacing.xl)
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    handleDrop(providers: providers)
                }
                .animation(.smooth, value: isDraggingOver)

                Spacer()

                FMButton("Continue") {
                    onAdvance()
                }
                .disabled(watchedFolderURL == nil)
            }
            .padding(.vertical, FMDesign.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var dropZoneContent: some View {
        VStack(spacing: 20) {
            if let url = watchedFolderURL {
                ZStack {
                    Circle()
                        .fill(FMDesign.Color.logicBlue.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(FMDesign.Color.logicBlue)
                }
                
                VStack(spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(FMDesign.Font.headline())
                    Text(url.path)
                        .font(FMDesign.Font.caption())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 60)
                }
            } else {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(isDraggingOver ? FMDesign.Color.logicBlue : .secondary)
                
                VStack(spacing: 12) {
                    Text("Drag and drop your folder here")
                        .font(FMDesign.Font.headline())
                    
                    Text("or")
                        .font(FMDesign.Font.body())
                        .foregroundStyle(.tertiary)
                    
                    FMButton("Browse…", style: .secondary) { openFolderPicker() }
                }
            }
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
