import SwiftUI

struct ContentView: View {
    @State private var isTargeted = false
    @State private var imageURLs: [URL] = []
    @State private var outputFolder: URL?
    @State private var statusMessage: String?
    @State private var isProcessing = false
    @State private var showInfo = false
    private let tutorialURL = URL(string: "https://wenlei.top/wenremover-docs-v1/#header-id-2")!

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("app.title")
                        .font(.title2)
                    Text("app.subtitle")
                        .foregroundStyle(.secondary)
                    Link(LocalizedStringKey("tutorial.link"), destination: tutorialURL)
                        .font(.callout)
                }
                Spacer()
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help(LocalizedStringKey("help.about"))
                .popover(isPresented: $showInfo, arrowEdge: .top) {
                    AppInfoView()
                        .padding(16)
                        .frame(width: 300)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            dropZone

            HStack(spacing: 12) {
                Button {
                    chooseInputFiles()
                } label: {
                    Label(LocalizedStringKey("button.addFiles"), systemImage: "plus.circle")
                }
                Button {
                    chooseOutputFolder()
                } label: {
                    Label(LocalizedStringKey("button.chooseOutput"), systemImage: "folder")
                }
                Text(outputFolder?.path ?? NSLocalizedString("output.none", comment: ""))
                    .foregroundStyle(outputFolder == nil ? .red : .primary)
                    .fontWeight(outputFolder == nil ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    processImages()
                } label: {
                    Label(isProcessing ? LocalizedStringKey("button.removing") : LocalizedStringKey("button.removeExif"), systemImage: "wand.and.stars")
                }
                .disabled(imageURLs.isEmpty || outputFolder == nil || isProcessing)

                Button {
                    imageURLs.removeAll()
                    statusMessage = nil
                } label: {
                    Label(LocalizedStringKey("button.clearList"), systemImage: "trash")
                }
                .disabled(imageURLs.isEmpty || isProcessing)

                Spacer()
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            fileList
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 520)
        .background(FullscreenDisabler())
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                    Text("dropzone.title")
                        .font(.headline)
                    Text("dropzone.subtitle")
                        .foregroundStyle(.secondary)
                }
            )
            .frame(height: 180)
            .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String.localizedStringWithFormat(NSLocalizedString("selected.count", comment: ""), imageURLs.count))
                    .font(.headline)
                Spacer()
                Button {
                    imageURLs.removeAll()
                    statusMessage = nil
                } label: {
                    Label(LocalizedStringKey("button.clearAll"), systemImage: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(imageURLs, id: \.self) { url in
                        HStack {
                            Text(url.lastPathComponent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                imageURLs.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(LocalizedStringKey("button.removeOne"))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var newURLs: [URL] = []

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier("public.file-url") else { continue }
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.isFileURL {
                    newURLs.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            let filtered = newURLs.filter { ImageStripper.isSupportedImage(url: $0) }
            imageURLs.append(contentsOf: filtered)
            if filtered.isEmpty {
                statusMessage = NSLocalizedString("status.noneSupported", comment: "")
            } else {
                statusMessage = String.localizedStringWithFormat(NSLocalizedString("status.added", comment: ""), filtered.count)
            }
        }

        return true
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.begin { response in
            if response == .OK {
                outputFolder = panel.urls.first
            }
        }
    }

    private func chooseInputFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.prompt = "添加"
        panel.begin { response in
            if response == .OK {
                let filtered = panel.urls.filter { ImageStripper.isSupportedImage(url: $0) }
                imageURLs.append(contentsOf: filtered)
                if filtered.isEmpty {
                    statusMessage = NSLocalizedString("status.noneSupported", comment: "")
                } else {
                    statusMessage = String.localizedStringWithFormat(NSLocalizedString("status.added", comment: ""), filtered.count)
                }
            }
        }
    }


private struct AppInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("info.title")
                .font(.headline)
            Text("info.subtitle")
                .foregroundStyle(.secondary)
            Divider()
            Text("info.supported")
                .font(.callout)
            Text("info.outputRule")
                .font(.callout)
        }
    }
}

private struct FullscreenDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.collectionBehavior.insert(.fullScreenNone)
                window.collectionBehavior.remove(.fullScreenPrimary)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
    private func processImages() {
        guard let outputFolder else { return }
        let urlsToProcess = imageURLs
        isProcessing = true
        statusMessage = NSLocalizedString("status.processing", comment: "")

        Task.detached {
            var successCount = 0
            var failureCount = 0

            for url in urlsToProcess {
                do {
                    _ = try ImageStripper.stripMetadata(inputURL: url, outputFolder: outputFolder)
                    successCount += 1
                } catch {
                    failureCount += 1
                }
            }

            let finalSuccess = successCount
            let finalFailure = failureCount

            await MainActor.run {
                isProcessing = false
                statusMessage = String.localizedStringWithFormat(NSLocalizedString("status.done", comment: ""), finalSuccess, finalFailure)
            }
        }
    }
}

#Preview {
    ContentView()
}
