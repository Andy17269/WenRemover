import SwiftUI
import UniformTypeIdentifiers

struct PrivacyProtectorView: View {
    @StateObject private var viewModel = PrivacyEditorViewModel()
    @AppStorage("languagePreference") private var languagePreference: String = "system"
    @AppStorage("outputSuffix") private var storedOutputSuffix = "_clean"
    @AppStorage("outputConflictRule") private var storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
    @AppStorage("defaultOutputPath") private var defaultOutputPath: String = ""
    
    @State private var isTargeted = false
    @State private var isHoveringDropZone = false
    @State private var showOutputSettings = false
    @State private var dragOffset: CGSize = .zero
    @State private var showSuccessCheck = false
    @State private var showBetaBanner = false
    @State private var isDrawingMode = false
    
    @AppStorage("hasSeenPrivacyBetaBanner") private var hasSeenPrivacyBetaBanner = false
    @AppStorage("alwaysShowChangelogBanner") private var alwaysShowChangelogBanner = false
    
    private var outputConfiguration: OutputConfiguration {
        OutputConfiguration(
            suffix: storedOutputSuffix,
            rule: OutputConflictRule(rawValue: storedOutputConflictRule) ?? .appendIndex
        )
    }

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

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("privacy.title"))
                    .font(.largeTitle)
                    .bold()
                
                Text(LocalizedStringKey("privacy.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if showBetaBanner || alwaysShowChangelogBanner {
                    betaBannerView
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 28)
            
            if viewModel.state == .idle {
                dropZone
            } else {
                imageStackView
            }
            
            controlBar
            
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            fileList
        }
        .padding(20)
        .ignoresSafeArea()
        .sheet(isPresented: $showOutputSettings) {
            OutputSettingsView(configuration: outputConfiguration, blurIntensity: $viewModel.blurIntensity) { newConfiguration in
                let normalized = newConfiguration.normalized()
                storedOutputSuffix = normalized.suffix
                storedOutputConflictRule = normalized.rule.rawValue
            }
        }
        .onAppear {
            if !defaultOutputPath.isEmpty {
                viewModel.outputFolder = URL(fileURLWithPath: defaultOutputPath)
            }
            if !hasSeenPrivacyBetaBanner {
                showBetaBanner = true
                hasSeenPrivacyBetaBanner = true
            }
            if alwaysShowChangelogBanner {
                showBetaBanner = true
            }
        }
        .onChange(of: defaultOutputPath) { _, newValue in
            if !newValue.isEmpty {
                viewModel.outputFolder = URL(fileURLWithPath: newValue)
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .exported {
                withAnimation {
                    showSuccessCheck = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        withAnimation {
                            showSuccessCheck = false
                        }
                        if viewModel.state == .exported {
                            viewModel.state = .review
                        }
                    }
                }
            }
        }
    }
    
    private var betaBannerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("privacy.beta.title"))
                    .font(.headline)
                Text(LocalizedStringKey("privacy.beta.body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                withAnimation {
                    showBetaBanner = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(LocalizedStringKey("privacy.beta.dismiss"))
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isTargeted || isHoveringDropZone ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.05))
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(isTargeted ? Color.accentColor : (isHoveringDropZone ? Color.gray : Color.clear))
                    
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.hierarchical)
                        Text(LocalizedStringKey("dropzone.title"))
                            .font(.headline)
                        Text(LocalizedStringKey("dropzone.subtitle"))
                            .foregroundStyle(.secondary)
                    }
                }
            )
            .frame(height: 300)
            .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                return handleDrop(providers: providers)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringDropZone = hovering
                }
            }
            .onTapGesture {
                chooseInputFiles()
            }
    }
    
    private var imageStackView: some View {
        ZStack {
            let startIndex = viewModel.currentIndex
            let maxItems = min(3, viewModel.items.count - startIndex)
            
            if maxItems > 0 {
                let visibleItems = Array(viewModel.items[startIndex..<(startIndex + maxItems)].enumerated().reversed())
                
                ForEach(visibleItems, id: \.element.id) { offsetIndex, item in
                    let isTop = offsetIndex == 0
                    let offset = isTop ? dragOffset : .zero
                    let scale: CGFloat = 1.0 - CGFloat(offsetIndex) * 0.05
                    let yOffset: CGFloat = -CGFloat(offsetIndex) * 20.0
                    
                    PrivacyImageCardView(item: item, viewModel: viewModel, isTopCard: isTop, isDrawingMode: isDrawingMode)
                        .offset(x: offset.width, y: offset.height + yOffset)
                        .scaleEffect(scale)
                        .zIndex(Double(-offsetIndex))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: offsetIndex)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                        .gesture(
                            isTop && !isDrawingMode ?
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 100
                                    if abs(value.translation.width) > threshold {
                                        let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            dragOffset = CGSize(width: direction * 500, height: value.translation.height)
                                        }
                                        let keep = direction > 0 // 右滑保留，左滑移除
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            viewModel.popItem(id: item.id, keep: keep)
                                            dragOffset = .zero
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                            : nil
                        )
                }
            }
            
            if viewModel.items.count > 1 {
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.currentIndex = max(viewModel.currentIndex - 1, 0)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(viewModel.currentIndex > 0 ? 1.0 : 0.0)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            viewModel.currentIndex = min(viewModel.currentIndex + 1, viewModel.items.count - 1)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(viewModel.currentIndex < viewModel.items.count - 1 ? 1.0 : 0.0)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .padding(.horizontal, 20)
                .zIndex(50)
                
                Button(action: {
                    if viewModel.currentIndex < viewModel.items.count {
                        let item = viewModel.items[viewModel.currentIndex]
                        swipeTopCard(item: item, direction: -1)
                    }
                }) { EmptyView() }
                .keyboardShortcut(.delete, modifiers: [])
                .opacity(0)
            }
            
            if viewModel.items.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(viewModel.currentIndex + 1) / \(viewModel.items.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding()
                    }
                    Spacer()
                }
                .zIndex(100)
            }
        }
    }
    
    private func swipeTopCard(item: PrivacyImageItem, direction: CGFloat) {
        guard dragOffset == .zero else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: direction * 500, height: 0)
        }
        let keep = direction > 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.popItem(id: item.id, keep: keep)
            dragOffset = .zero
        }
    }
    
    private var controlBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    viewModel.clearImages()
                } label: {
                    Label {
                        Text(LocalizedStringKey("button.clearList"))
                    } icon: {
                        Image(systemName: "trash")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
                .disabled(viewModel.state == .idle || viewModel.state == .rendering)
                .opacity(viewModel.state == .idle || viewModel.state == .rendering ? 0.5 : 1)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Toggle(isOn: $isDrawingMode) {
                        Label(LocalizedStringKey("privacy.button.drawMode"), systemImage: "paintbrush.pointed")
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)
                    .frame(height: 38)
                    .padding(.horizontal, 16)
                    .background(isDrawingMode ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isDrawingMode ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                    .disabled(viewModel.state == .idle || viewModel.state == .rendering)
                    .opacity(viewModel.state == .idle || viewModel.state == .rendering ? 0.5 : 1)
    
                    Button {
                        showOutputSettings = true
                    } label: {
                        Label {
                            Text(LocalizedStringKey("button.outputSettings"))
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .frame(height: 38)
                        .padding(.horizontal, 16)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help(LocalizedStringKey("help.outputSettings"))
                    .disabled(viewModel.state == .rendering)
                    .opacity(viewModel.state == .rendering ? 0.5 : 1)

                    Button {
                        chooseOutputFolder()
                    } label: {
                        Label {
                            Text(viewModel.outputFolder?.lastPathComponent ?? localizedString("button.chooseOutput"))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } icon: {
                            Image(systemName: "folder")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .frame(height: 38)
                        .padding(.horizontal, 16)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .overlay(alignment: .topTrailing) {
                        if viewModel.outputFolder == nil {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                .offset(x: 4, y: -4)
                        }
                    }
                    .help(LocalizedStringKey("button.chooseOutput"))
                }
            }
            
            HStack(spacing: 12) {
                Spacer()
                
                if viewModel.items.count == 1 {
                    Button {
                        viewModel.copySingleImageToClipboard(configuration: outputConfiguration)
                    } label: {
                        Label(LocalizedStringKey("button.copyToClipboard"), systemImage: "doc.on.clipboard")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 24)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(viewModel.state == .idle || viewModel.state == .rendering)
                    .opacity((viewModel.state == .idle || viewModel.state == .rendering) && !showSuccessCheck ? 0.5 : 1)
                }
                
                Button {
                    viewModel.exportAllImages(configuration: outputConfiguration)
                } label: {
                    HStack(spacing: 8) {
                        if showSuccessCheck {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: viewModel.items.count > 1 ? "square.and.arrow.down.on.square" : "square.and.arrow.down")
                                .font(.headline)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        if viewModel.state == .rendering {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(viewModel.items.count > 1 ? localizedString("privacy.button.exportAll") : localizedString("privacy.button.export"))
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 38)
                .padding(.horizontal, 32)
                .background(showSuccessCheck ? Color.green : Color.accentColor)
                .animation(.easeInOut(duration: 0.2), value: showSuccessCheck)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled((viewModel.state != .review && viewModel.state != .exported) || viewModel.outputFolder == nil || viewModel.state == .rendering)
                .opacity(((viewModel.state != .review && viewModel.state != .exported) || viewModel.outputFolder == nil || viewModel.state == .rendering) && !showSuccessCheck ? 0.5 : 1)
            }
        }
        .padding(16)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                viewModel.loadImages(from: urls)
            }
        }
        return true
    }
    
    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localizedString("panel.choose")
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                viewModel.outputFolder = url
                defaultOutputPath = url.path
            }
        }
    }
    
    private func chooseInputFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.prompt = localizedString("panel.add")
        panel.begin { response in
            if response == .OK {
                DispatchQueue.main.async {
                    self.viewModel.loadImages(from: panel.urls)
                }
            }
        }
    }
    
    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String.localizedStringWithFormat(localizedString("selected.count %lld"), viewModel.items.count))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    viewModel.clearImages()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text(LocalizedStringKey("button.clearAll"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(viewModel.items.isEmpty ? Color.secondary.opacity(0.5) : Color.red)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.items.isEmpty)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(viewModel.items) { item in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text(item.url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                viewModel.popItem(id: item.id, keep: false)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                            .help(LocalizedStringKey("button.removeOne"))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 150)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrivacyImageCardView: View {
    let item: PrivacyImageItem
    @ObservedObject var viewModel: PrivacyEditorViewModel
    let isTopCard: Bool
    let isDrawingMode: Bool
    
    @State private var dragStartPoint: CGPoint? = nil
    @State private var dragCurrentPoint: CGPoint? = nil

    private var currentDragRect: CGRect? {
        guard let start = dragStartPoint, let current = dragCurrentPoint else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
    
    var body: some View {
        Image(nsImage: item.nsImage)
            .resizable()
            .scaledToFit()
            .cornerRadius(12)
            .overlay(
                GeometryReader { geo in
                    boundingBoxesOverlay(in: geo.size)
                }
            )
            .overlay(
                Group {
                    if item.isDetecting {
                        ProgressView()
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
    
    private func boundingBoxesOverlay(in viewSize: CGSize) -> some View {
        return ZStack {
            ForEach(item.detectedRegions) { region in
                let isSelected = item.selectedRegionIDs.contains(region.id)
                let rectX = region.boundingBox.minX * viewSize.width
                let rectY = (1 - region.boundingBox.maxY) * viewSize.height
                let rectWidth = region.boundingBox.width * viewSize.width
                let rectHeight = region.boundingBox.height * viewSize.height
                let rect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
                
                let themeColor = Color(red: 33/255.0, green: 150/255.0, blue: 243/255.0)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeColor.opacity(0.3) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeColor, style: StrokeStyle(lineWidth: isSelected ? 3 : 1, dash: isSelected ? [] : [4]))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .frame(width: rectWidth, height: rectHeight)
                    .position(x: rect.midX, y: rect.midY)
                    .onTapGesture {
                        if isTopCard {
                            viewModel.toggleRegionSelection(itemID: item.id, regionID: region.id)
                        }
                    }
            }
            
            if let dragRect = currentDragRect {
                Rectangle()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .frame(width: dragRect.width, height: dragRect.height)
                    .position(x: dragRect.midX, y: dragRect.midY)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            isTopCard && isDrawingMode ? 
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartPoint == nil {
                        dragStartPoint = value.startLocation
                    }
                    dragCurrentPoint = value.location
                }
                .onEnded { value in
                    if let start = dragStartPoint {
                        let rect = CGRect(
                            x: min(start.x, value.location.x),
                            y: min(start.y, value.location.y),
                            width: abs(value.location.x - start.x),
                            height: abs(value.location.y - start.y)
                        )
                        if rect.width > 5 && rect.height > 5 {
                            let normalizedRect = CGRect(
                                x: rect.minX / viewSize.width,
                                y: 1.0 - (rect.maxY / viewSize.height),
                                width: rect.width / viewSize.width,
                                height: rect.height / viewSize.height
                            )
                            viewModel.addManualRegion(itemID: item.id, boundingBox: normalizedRect)
                        }
                    }
                    dragStartPoint = nil
                    dragCurrentPoint = nil
                }
            : nil
        )
    }
}
