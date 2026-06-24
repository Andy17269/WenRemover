import SwiftUI
import UniformTypeIdentifiers

struct EXIFViewerView: View {
    @State private var isTargeted = false
    @State private var imageURL: URL?
    @State private var exifData: EXIFData?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("tab.exifViewer"))
                        .font(.largeTitle)
                        .bold()
                    Text(LocalizedStringKey("exifviewer.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if imageURL != nil {
                    HStack(spacing: 16) {
                        Button {
                            imageURL = nil
                            exifData = nil
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text(LocalizedStringKey("button.clearAll"))
                            }
                            .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            selectFile()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                Text(LocalizedStringKey("button.nextImage"))
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding()
            
            Divider()
            
            if let url = imageURL, let data = exifData {
                HSplitView {
                    VStack {
                        if let nsImage = NSImage(contentsOf: url) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.clear)
                        } else {
                            Text("Invalid Image")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                    
                    EXIFInfoView(url: url, data: data)
                        .background(Color.clear)
                        .frame(width: 350)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(isTargeted ? .blue : .secondary)
                    
                    Text(LocalizedStringKey("dropzone.title"))
                        .font(.headline)
                    
                    Text(LocalizedStringKey("dropzone.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isTargeted ? Color.blue : Color.secondary.opacity(0.2),
                                      style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
                .padding()
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }
                .onTapGesture {
                    selectFile()
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.file-url") }) else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    loadImage(url)
                }
            }
        }
        return true
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(url)
        }
    }
    
    private func loadImage(_ url: URL) {
        if let data = EXIFReader.readEXIF(from: url) {
            self.imageURL = url
            self.exifData = data
        }
    }
}
