import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

public struct EXIFEditorView: View {
    @StateObject private var viewModel = EXIFEditorViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("enableGlassmorphism") private var enableGlassmorphism = true
    @AppStorage("defaultOutputPath") private var defaultOutputPath: String = ""
    @AppStorage("languagePreference") private var languagePreference: String = "system"
    
    @State private var isPhotoPickerPresented = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isTargeted = false
    
    @State private var batchRenameFormat: String = "{Year}-{Make}-{Model}"
    @State private var timeShiftHours: Double = 0
    @State private var isExporting = false
    @State private var exportMessage = ""
    @State private var isEditMode = false
    @State private var showOutputSettings = false
    @State private var outputFolder: URL?
    @AppStorage("outputSuffix") private var storedOutputSuffix = "_clean"
    @AppStorage("outputConflictRule") private var storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
    
    private var outputConfiguration: OutputConfiguration {
        OutputConfiguration(
            suffix: storedOutputSuffix,
            rule: OutputConflictRule(rawValue: storedOutputConflictRule) ?? .appendIndex
        )
    }
    
    public init() {}
    
    public var body: some View {
        let layout = horizontalSizeClass == .compact ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        
        layout {
            // Left Panel: File List & Filters
            VStack(spacing: 0) {
                #if os(macOS)
                Spacer().frame(height: 38)
                #else
                Spacer().frame(height: 12)
                #endif
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("tab.exifEditor"))
                        .font(.title)
                        .bold()
                    
                    Text(LocalizedStringKey("exifviewer.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(LocalizedStringKey("editor.selectFile"), text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // File List
                if viewModel.files.isEmpty {
                    dropZoneView
                        .padding()
                } else {
                    List(selection: $viewModel.selectedFileIDs) {
                        ForEach(viewModel.filteredFiles) { item in
                            HStack {
                                if let image = PlatformImage(contentsOf: item.url) {
                                    Image(platformImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(item.url.lastPathComponent)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(item.currentEXIF.make ?? NSLocalizedString("editor.unknown", comment: ""))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(item.id)
                            .listRowBackground(Color.clear)
                        }
                    }
                    #if os(macOS)
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    #else
                    .scrollContentBackground(.hidden)
                    #endif
                }
                
                if !viewModel.files.isEmpty {
                    HStack {
                        Button(action: {
                            selectFile()
                        }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .padding()
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.clearAll()
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .padding()
                    }
                }
            }
            .frame(width: horizontalSizeClass == .compact ? nil : 300)
            .frame(maxHeight: horizontalSizeClass == .compact ? 300 : .infinity)
            .background(enableGlassmorphism ? Color.clear : Color.controlBackground)
            
            if horizontalSizeClass != .compact {
                Divider()
            }
            
            // Right Panel: Editor & Batch Actions
            VStack(spacing: 0) {
                #if os(macOS)
                Spacer().frame(height: 38)
                #endif
                if viewModel.selectedFileIDs.isEmpty {
                    VStack {
                        Image(systemName: "hand.point.up.left")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey("editor.selectFile"))
                            .foregroundStyle(.secondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.selectedFileIDs.count == 1 {
                    // Single Item Editor
                    if let selectedId = viewModel.selectedFileIDs.first,
                       let index = viewModel.files.firstIndex(where: { $0.id == selectedId }) {
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Picker("", selection: $isEditMode) {
                                    Text(LocalizedStringKey("editor.mode.view")).tag(false)
                                    Text(LocalizedStringKey("editor.mode.edit")).tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            Divider()
                            if isEditMode {
                                editorForm(for: $viewModel.files[index])
                            } else {
                                viewerForm(for: viewModel.files[index])
                            }
                        }
                    }
                } else {
                    // Multi Item / Batch Actions
                    batchActionsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(enableGlassmorphism ? Color.clear : Color.windowBackground)
            .overlay {
                if viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView(value: viewModel.processingProgress)
                            .progressViewStyle(.circular)
                            .padding()
                            .background(Color.windowBackground)
                            .cornerRadius(8)
                    }
                }
            }
        }
        #if os(macOS)
        .ignoresSafeArea()
        .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        #endif
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $photoPickerItems, matching: .any(of: [.images, .videos]))
        .onChange(of: photoPickerItems) { _ , newItems in
            handlePhotoSelection(items: newItems)
        }
        .sheet(isPresented: $showOutputSettings) {
            OutputSettingsView(configuration: outputConfiguration) { newConfiguration in
                let normalized = newConfiguration.normalized()
                storedOutputSuffix = normalized.suffix
                storedOutputConflictRule = normalized.rule.rawValue
            }
        }
    }
    
    private var dropZoneView: some View {
        #if os(macOS)
        RoundedRectangle(cornerRadius: 12)
            .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.05))
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.2))
                    
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                        Text(LocalizedStringKey("dropzone.title"))
                            .font(.title3)
                            .bold()
                        Text(LocalizedStringKey("dropzone.subtitle"))
                            .foregroundStyle(.secondary)
                    }
                }
            )
            .onTapGesture {
                selectFile()
            }
        #else
        Button(action: { selectFile() }) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 48))
                Text(LocalizedStringKey("button.chooseImages"))
                    .font(.title3)
                    .bold()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        #endif
    }
    
    @ViewBuilder
    private func viewerForm(for item: EXIFFileItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(LocalizedStringKey("tab.exifEditor"))
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        let text = generateEXIFString(for: item)
                        PlatformCompat.copyToClipboard(text)
                        exportMessage = NSLocalizedString("status.copiedToClipboard", comment: "")
                    }) {
                        Label(LocalizedStringKey("button.copyEXIF"), systemImage: "doc.on.doc")
                    }
                }
                
                Divider()
                
                let exif = item.originalEXIF
                
                Group {
                    infoRow(title: "exif.make", value: exif.make)
                    infoRow(title: "exif.model", value: exif.model)
                    infoRow(title: "exif.lens", value: exif.lensModel)
                    infoRow(title: "exif.datetime", value: exif.dateTimeOriginal)
                    if let fl = exif.focalLength {
                        infoRow(title: "exif.focalLength", value: "\(fl) mm")
                    }
                    infoRow(title: "exif.colorProfile", value: exif.colorProfile)
                    if let cd = exif.colorDepth {
                        infoRow(title: "exif.colorDepth", value: "\(cd)")
                    }
                }
                
                Group {
                    if let fNum = exif.fNumber {
                        infoRow(title: "exif.aperture", value: "f/\(fNum)")
                    }
                    if let et = exif.exposureTime {
                        infoRow(title: "exif.exposureTime", value: "1/\(Int(1/et)) s")
                    }
                    if let iso = exif.isoSpeedRatings?.first {
                        infoRow(title: "exif.iso", value: "\(iso)")
                    }
                    if let lat = exif.latitude, let lon = exif.longitude {
                        infoRow(title: "editor.gps", value: "\(lat), \(lon)")
                        GPSMapView(coordinate: .constant(exif.coordinate), isReadOnly: true)
                            .disabled(true)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func infoRow(title: String, value: String?) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value ?? "-")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func generateEXIFString(for item: EXIFFileItem) -> String {
        let exif = item.originalEXIF
        var lines: [String] = []
        lines.append("Make: \(exif.make ?? "-")")
        lines.append("Model: \(exif.model ?? "-")")
        lines.append("Lens: \(exif.lensModel ?? "-")")
        lines.append("DateTime: \(exif.dateTimeOriginal ?? "-")")
        if let fl = exif.focalLength { lines.append("Focal Length: \(fl) mm") }
        if let fNum = exif.fNumber { lines.append("Aperture: f/\(fNum)") }
        if let et = exif.exposureTime { lines.append("Exposure Time: 1/\(Int(1/et)) s") }
        if let iso = exif.isoSpeedRatings?.first { lines.append("ISO: \(iso)") }
        if let lat = exif.latitude, let lon = exif.longitude {
            lines.append("GPS: \(lat), \(lon)")
        }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func editorForm(for item: Binding<EXIFFileItem>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey("editor.basic"))
                    .font(.headline)
                
                Group {
                    HStack {
                        Text(LocalizedStringKey("editor.make"))
                        Spacer()
                        TextField("", text: Binding(get: { item.currentEXIF.make.wrappedValue ?? "" }, set: { item.currentEXIF.make.wrappedValue = $0.isEmpty ? nil : $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    HStack {
                        Text(LocalizedStringKey("editor.model"))
                        Spacer()
                        TextField("", text: Binding(get: { item.currentEXIF.model.wrappedValue ?? "" }, set: { item.currentEXIF.model.wrappedValue = $0.isEmpty ? nil : $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    HStack {
                        Text(LocalizedStringKey("editor.date"))
                        Spacer()
                        TextField("yyyy:MM:dd HH:mm:ss", text: Binding(get: { item.currentEXIF.dateTimeOriginal.wrappedValue ?? "" }, set: { item.currentEXIF.dateTimeOriginal.wrappedValue = $0.isEmpty ? nil : $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    HStack {
                        Text(LocalizedStringKey("editor.artist"))
                        Spacer()
                        TextField("", text: Binding(get: { item.currentEXIF.artist.wrappedValue ?? "" }, set: { item.currentEXIF.artist.wrappedValue = $0.isEmpty ? nil : $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    HStack {
                        Text(LocalizedStringKey("editor.copyright"))
                        Spacer()
                        TextField("", text: Binding(get: { item.currentEXIF.copyright.wrappedValue ?? "" }, set: { item.currentEXIF.copyright.wrappedValue = $0.isEmpty ? nil : $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                }
                
                Divider()
                
                Text(LocalizedStringKey("editor.gps"))
                    .font(.headline)
                
                GPSMapView(coordinate: item.currentEXIF.coordinate)
                
                Divider()
                
                outputSection {
                    Task {
                        let folder = URL(fileURLWithPath: defaultOutputPath.isEmpty ? NSHomeDirectory() : defaultOutputPath)
                        do {
                            let config = OutputConfiguration(suffix: storedOutputSuffix, rule: OutputConflictRule(rawValue: storedOutputConflictRule) ?? .appendIndex)
                            // We use config if BatchProcessingEngine supports it, else we just pass nil newName
                            let url = try BatchProcessingEngine.processFile(url: item.wrappedValue.url, newEXIF: item.wrappedValue.currentEXIF, newName: nil, outputFolder: folder)
                            exportMessage = String(format: NSLocalizedString("editor.status.saved", comment: ""), url.lastPathComponent)
                        } catch {
                            exportMessage = String(format: NSLocalizedString("editor.status.failed", comment: ""), error.localizedDescription)
                        }
                    }
                }
                .padding(.top)
                
                if !exportMessage.isEmpty {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding()
        }
    }
    
    private var batchActionsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(String(format: NSLocalizedString("selected.count %lld", comment: ""), viewModel.selectedFileIDs.count))
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("editor.batch.rename"))
                    .font(.headline)
                HStack {
                    TextField(LocalizedStringKey("editor.batch.renameFormat"), text: $batchRenameFormat)
                        .textFieldStyle(.roundedBorder)
                    Button(LocalizedStringKey("editor.batch.renameAndExport")) {
                        Task {
                            let folder = URL(fileURLWithPath: defaultOutputPath.isEmpty ? NSHomeDirectory() : defaultOutputPath)
                            try? await viewModel.batchRename(format: batchRenameFormat, outputFolder: folder)
                            exportMessage = NSLocalizedString("editor.status.batchRenameCompleted", comment: "")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text(LocalizedStringKey("editor.batch.varsDescription"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("editor.batch.timeShift"))
                    .font(.headline)
                HStack {
                    Text(LocalizedStringKey("editor.batch.hoursToShift"))
                    #if os(macOS)
                    Stepper(value: $timeShiftHours, in: -24...24, step: 1) {
                        Text("\(timeShiftHours, specifier: "%.0f")")
                    }
                    #else
                    Stepper("\(timeShiftHours, specifier: "%.0f")", value: $timeShiftHours, in: -24...24, step: 1)
                    #endif
                    Button(LocalizedStringKey("editor.batch.applyShift")) {
                        viewModel.batchTimeShift(timeInterval: timeShiftHours * 3600)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Divider()
            
            outputSection {
                Task {
                    let folder = URL(fileURLWithPath: defaultOutputPath.isEmpty ? NSHomeDirectory() : defaultOutputPath)
                    try? await viewModel.batchExport(outputFolder: folder)
                    exportMessage = NSLocalizedString("editor.status.batchExportCompleted", comment: "")
                }
            }
            
            if !exportMessage.isEmpty {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func selectFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .movie, .rawImage]
        if panel.runModal() == .OK {
            Task {
                await viewModel.addFiles(urls: panel.urls)
            }
        }
        #else
        isPhotoPickerPresented = true
        #endif
    }
    
    private func handlePhotoSelection(items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task(priority: .userInitiated) {
            var imported: [URL] = []
            for item in items {
                if let url = await persistPhotoPickerItem(item) {
                    imported.append(url)
                }
            }

            if !imported.isEmpty {
                await viewModel.addFiles(urls: imported)
            }
            await MainActor.run {
                photoPickerItems.removeAll()
            }
        }
    }

    private func persistPhotoPickerItem(_ item: PhotosPickerItem) async -> URL? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenremover-editor-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        do {
            try data.write(to: tempURL, options: [.atomic])
            return tempURL
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
    
    #if os(macOS)
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didHandle = false
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                        urls.append(url)
                    } else if let url = item as? URL, url.isFileURL {
                        urls.append(url)
                    }
                    group.leave()
                }
                didHandle = true
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                Task {
                    await viewModel.addFiles(urls: urls)
                }
            }
        }
        
        return didHandle
    }
    #endif
    
    @ViewBuilder
    private func outputSection(processAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("label.output"))
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                #if os(macOS)
                Button {
                    chooseOutputFolder()
                } label: {
                    Label {
                        Text(outputFolder?.lastPathComponent ?? NSLocalizedString("button.chooseOutput", comment: ""))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: "folder")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    if outputFolder == nil {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .offset(x: 4, y: -4)
                    }
                }
                #else
                Label {
                    Text("保存到相册 (Photos Library)")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "photo.on.rectangle")
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                #endif
                
                Button {
                    showOutputSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 38, height: 38)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            
            Button {
                processAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.headline)
                    Text(LocalizedStringKey("button.export"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
    
    #if os(macOS)
    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("button.chooseOutput", comment: "")
        
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
            defaultOutputPath = url.path
        }
    }
    #endif
    
    private func localizedString(_ key: String) -> String {
        if languagePreference == "system" {
            return NSLocalizedString(key, comment: "")
        }
        if let path = Bundle.main.path(forResource: languagePreference, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }
}
