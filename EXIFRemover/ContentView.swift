import SwiftUI
import PhotosUI
import CryptoKit

@MainActor
struct ContentView: View {
    @State private var isTargeted = false
    @State private var isHoveringDropZone = false
    @State private var imageURLs: [URL] = []
    @State private var outputFolder: URL?
    @State private var statusMessage: String?
    @State private var isProcessing = false
    @State private var showInfo = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var tempPhotoURLs: Set<URL> = []
    @State private var isPhotoPickerPresented = false
    @State private var showOutputSettings = false
    @State private var showSuccessCheck = false // New state for success animation
    @State private var showChangelogBanner = false
    @State private var noticeBanner: NoticeBanner?
    @State private var showNoticeBanner = false
    @AppStorage("outputSuffix") private var storedOutputSuffix = "_clean"
    @AppStorage("outputConflictRule") private var storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
    @AppStorage("hasSeenChangelogBanner") private var hasSeenChangelogBanner = false
    @AppStorage("alwaysShowChangelogBanner") private var alwaysShowChangelogBanner = false
    @AppStorage("disableOnlineNotice") private var disableOnlineNotice = false
    @AppStorage("noticeBannerDismissedAt") private var noticeBannerDismissedAt = 0.0
    @AppStorage("noticeBannerDismissedID") private var noticeBannerDismissedID = ""
    @AppStorage("languagePreference") private var languagePreference: String = "system"
    private let tutorialURL = URL(string: "https://wenlei.top/wenremover-docs-v1/#header-id-2")!
    private let noticeBannerURL = URL(string: "https://assets.wenlei.top/wenremover/index-notice.config")!

    private var outputConfiguration: OutputConfiguration {
        OutputConfiguration(
            suffix: storedOutputSuffix,
            rule: OutputConflictRule(rawValue: storedOutputConflictRule) ?? .appendIndex
        )
    }

    private var minWindowWidth: CGFloat {
        if languagePreference == "en" { return 685 }
        if languagePreference == "zh-Hans" { return 580 }
        // System fallback
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return lang.contains("zh") ? 580 : 685
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header and Banners grouped with less spacing
            VStack(alignment: .leading, spacing: 10) {
                // Header: large title + subtitle + tutorial link; info button at top-right
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Large, bold title for macOS modern feel
                        Text(LocalizedStringKey("app.title"))
                            .font(.largeTitle)
                            .bold()

                        // Description under the title with lower emphasis
                        Text(LocalizedStringKey("app.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Tutorial / help link kept as-is
                        Link(LocalizedStringKey("tutorial.link"), destination: tutorialURL)
                            .font(.callout)
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    // Info button stays at top-right; aligned with the header top
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title2)
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
                .padding(.top, 28)

                if showNoticeBanner, let noticeBanner {
                    noticeBannerView(noticeBanner)
                }
                if showChangelogBanner || alwaysShowChangelogBanner {
                    changelogBanner
                }
            }

            dropZone

            controlBar

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            fileList
        }
        .padding(20)
        .frame(minWidth: minWindowWidth, idealWidth: minWindowWidth, minHeight: 640, idealHeight: 720)
        .background(.regularMaterial)
        .background(FullscreenDisabler())
        .ignoresSafeArea()
        .onAppear {
            if !hasSeenChangelogBanner {
                showChangelogBanner = true
                hasSeenChangelogBanner = true
            }
            if alwaysShowChangelogBanner {
                showChangelogBanner = true
            }
            Task {
                await loadNoticeBanner()
            }
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $photoPickerItems, matching: .images)
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

    private var controlBar: some View {
        HStack(spacing: 16) {
            // Group 1: Left - Input
            // 1. Add Files Menu (Consolidated)
            Menu {
                Button {
                    chooseInputFiles()
                } label: {
                    Label(LocalizedStringKey("menu.addFromFinder"), systemImage: "folder.badge.plus")
                }
                Button {
                    isPhotoPickerPresented = true
                } label: {
                    Label(LocalizedStringKey("button.addFromPhotos"), systemImage: "photo.on.rectangle")
                }
                .disabled(isProcessing)
            } label: {
                Label {
                    Text(LocalizedStringKey("button.addFiles"))
                } icon: {
                    Image(systemName: "plus")
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
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(LocalizedStringKey("button.addFiles"))
            .disabled(isProcessing)

            Spacer()

            // Group 2: Right - Settings, Output & Action
            HStack(spacing: 12) {
                // 2. Settings Button
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
                .disabled(isProcessing)

                // 3. Choose Output Folder Button
                Button {
                    chooseOutputFolder()
                } label: {
                    Label {
                        Text(outputFolder?.lastPathComponent ?? localizedString("button.chooseOutput"))
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
                    if outputFolder == nil {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .offset(x: 4, y: -4)
                    }
                }
                .help(LocalizedStringKey("button.chooseOutput"))

                // 4. Remove EXIF Button (Primary Capsule)
                Button {
                    processImages()
                } label: {
                    ZStack {
                        // Original Label (Hidden when processing or showing success)
                        Label {
                            Text(LocalizedStringKey("button.removeExif"))
                                .fontWeight(.bold)
                        } icon: {
                            Image(systemName: "wand.and.stars")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .opacity((isProcessing || showSuccessCheck) ? 0 : 1)
                        
                        // Progress View
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        
                        // Success Checkmark
                        if showSuccessCheck {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 24) // Maintain padding to keep width stable if possible, or adequate for content
                    .frame(minWidth: 140) // Ensure button doesn't shrink too much during state changes
                    .background(showSuccessCheck ? Color.green : Color.accentColor) // Green background on success
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: isProcessing)
                    .animation(.easeInOut(duration: 0.2), value: showSuccessCheck)
                }
                .buttonStyle(.plain)
                .disabled(imageURLs.isEmpty || outputFolder == nil || isProcessing)
                .opacity((imageURLs.isEmpty || outputFolder == nil || isProcessing) && !showSuccessCheck ? 0.5 : 1)
            }
        }
        .padding(.top, 12)
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
            .frame(height: 180)
            .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringDropZone = hovering
                }
            }
    }

    private var changelogBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("changelog.title"))
                    .font(.headline)
                Text(LocalizedStringKey("changelog.body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                withAnimation {
                    showChangelogBanner = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(LocalizedStringKey("changelog.dismiss"))
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func noticeBannerView(_ banner: NoticeBanner) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: banner.title)
                    .font(.headline)
                if !banner.message.isEmpty {
                    Text(verbatim: banner.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let linkURL = banner.linkURL {
                    Link(banner.linkTitle ?? localizedString("notice.action"), destination: linkURL)
                        .font(.callout)
                }
            }
            Spacer()
            Button {
                dismissNoticeBanner()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(LocalizedStringKey("notice.dismiss"))
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status bar header
            HStack {
                Text(String.localizedStringWithFormat(localizedString("selected.count %lld"), imageURLs.count))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    clearAllImages()
                    statusMessage = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text(LocalizedStringKey("button.clearAll"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(imageURLs.isEmpty ? Color.secondary.opacity(0.5) : Color.red)
                }
                .buttonStyle(.plain)
                .disabled(imageURLs.isEmpty)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(imageURLs, id: \.self) { url in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                removeImageURL(url)
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
            handleNewImageURLs(newURLs)
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
        panel.prompt = localizedString("panel.add")
        panel.begin { response in
            if response == .OK {
                handleNewImageURLs(panel.urls)
            }
        }
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

            if imported.isEmpty {
                statusMessage = localizedString("status.noneSupported")
                photoPickerItems.removeAll()
                return
            }

            handleNewImageURLs(imported)
            tempPhotoURLs.formUnion(imported)
            photoPickerItems.removeAll()
        }
    }

    private func persistPhotoPickerItem(_ item: PhotosPickerItem) async -> URL? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenremover-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        do {
            try data.write(to: tempURL, options: [.atomic])
            guard ImageStripper.isSupportedImage(url: tempURL) else {
                try? FileManager.default.removeItem(at: tempURL)
                return nil
            }
            return tempURL
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }

    @MainActor
    private func handleNewImageURLs(_ urls: [URL]) {
        let filtered = urls.filter { ImageStripper.isSupportedImage(url: $0) }
        imageURLs.append(contentsOf: filtered)
        if filtered.isEmpty {
            statusMessage = localizedString("status.noneSupported")
        } else {
            statusMessage = String.localizedStringWithFormat(localizedString("status.added %lld"), filtered.count)
        }
    }

    private func removeImageURL(_ url: URL) {
        cleanupTemporaryFiles(for: [url])
        imageURLs.removeAll { $0 == url }
    }

    private func clearAllImages() {
        cleanupTemporaryFiles(for: imageURLs)
        imageURLs.removeAll()
    }

    private func cleanupTemporaryFiles(for urls: [URL]) {
        let fileManager = FileManager.default
        for url in urls where tempPhotoURLs.contains(url) {
            try? fileManager.removeItem(at: url)
            tempPhotoURLs.remove(url)
        }
    }

    private func processImages() {
        guard let outputFolder else { return }
        let urlsToProcess = imageURLs
        let configuration = outputConfiguration
        isProcessing = true
        statusMessage = localizedString("status.processing")

        Task.detached {
            var successCount = 0
            var failureCount = 0
            var skippedCount = 0

            for url in urlsToProcess {
                do {
                    _ = try ImageStripper.stripMetadata(
                        inputURL: url,
                        outputFolder: outputFolder,
                        configuration: configuration
                    )
                    successCount += 1
                } catch ImageStripper.StripError.skippedByRule {
                    skippedCount += 1
                } catch {
                    failureCount += 1
                }
            }

            let finalSuccess = successCount
            let finalFailure = failureCount
            let finalSkipped = skippedCount

            await MainActor.run {
                isProcessing = false
                
                // Trigger success animation
                withAnimation {
                    showSuccessCheck = true
                }
                
                // Hide success check after delay
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await MainActor.run {
                        withAnimation {
                            showSuccessCheck = false
                        }
                    }
                }

                if finalSkipped > 0 {
                    statusMessage = String.localizedStringWithFormat(localizedString("status.doneDetailed %lld %lld %lld"), finalSuccess, finalFailure, finalSkipped)
                } else {
                    statusMessage = String.localizedStringWithFormat(localizedString("status.done %lld %lld"), finalSuccess, finalFailure)
                }
            }
        }
    }

    @MainActor
    private func loadNoticeBanner() async {
        guard !disableOnlineNotice else {
            noticeBanner = nil
            showNoticeBanner = false
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: noticeBannerURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            guard let banner = NoticeBanner.from(data: data) else {
                noticeBanner = nil
                showNoticeBanner = false
                return
            }
            noticeBanner = banner
            showNoticeBanner = shouldShowNoticeBanner(for: banner)
        } catch {
            // Silently ignore network errors.
        }
    }

    private func shouldShowNoticeBanner(for banner: NoticeBanner) -> Bool {
        guard !banner.id.isEmpty else { return true }
        if noticeBannerDismissedID == banner.id {
            let elapsed = Date().timeIntervalSince1970 - noticeBannerDismissedAt
            if elapsed < 86400 {
                return false
            }
        }
        return true
    }

    private func dismissNoticeBanner() {
        guard let banner = noticeBanner else {
            showNoticeBanner = false
            return
        }
        noticeBannerDismissedID = banner.id
        noticeBannerDismissedAt = Date().timeIntervalSince1970
        withAnimation {
            showNoticeBanner = false
        }
    }

    private func localizedString(_ key: String) -> String {
        // If using system, fall back to default NSLocalizedString behavior
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

private struct NoticeBanner: Equatable {
    let id: String
    let title: String
    let message: String
    let linkTitle: String?
    let linkURL: URL?

    static func from(data: Data) -> NoticeBanner? {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            if let dict = json as? [String: Any] {
                return parse(dictionary: dict, data: data)
            }
            if let array = json as? [[String: Any]], let first = array.first {
                return parse(dictionary: first, data: data)
            }
            if let text = json as? String {
                return parse(text: text, data: data)
            }
        }

        if let text = String(data: data, encoding: .utf8) {
            return parse(text: text, data: data)
        }
        return nil
    }

    private static func parse(dictionary: [String: Any], data: Data) -> NoticeBanner? {
        if let enabled = dictionary["enabled"] as? Bool, enabled == false {
            return nil
        }
        if let show = dictionary["show"] as? Bool, show == false {
            return nil
        }
        if shouldHideForLocale(dictionary: dictionary) {
            return nil
        }

        let titleValue = (dictionary["title"] as? String)
            ?? (dictionary["headline"] as? String)
            ?? (dictionary["name"] as? String)

        let messageValue = (dictionary["message"] as? String)
            ?? (dictionary["body"] as? String)
            ?? (dictionary["desc"] as? String)
            ?? (dictionary["content"] as? String)

        let resolvedTitle = (titleValue?.isEmpty == false) ? titleValue! : NSLocalizedString("notice.defaultTitle", comment: "")
        let resolvedMessage: String
        if let messageValue, !messageValue.isEmpty {
            resolvedMessage = messageValue
        } else if let titleValue, !titleValue.isEmpty {
            resolvedMessage = titleValue
        } else {
            return nil
        }

        let linkString = (dictionary["link"] as? String)
            ?? (dictionary["url"] as? String)
            ?? (dictionary["href"] as? String)

        let linkTitle = (dictionary["linkTitle"] as? String)
            ?? (dictionary["action"] as? String)
            ?? (dictionary["button"] as? String)

        let linkURL = linkString.flatMap { URL(string: $0) }

        let id = (dictionary["id"] as? String)
            ?? (dictionary["version"] as? String)
            ?? (dictionary["noticeId"] as? String)
            ?? makeID(from: data)

        return NoticeBanner(id: id, title: resolvedTitle, message: resolvedMessage, linkTitle: linkTitle, linkURL: linkURL)
    }

    private static func parse(text: String, data: Data) -> NoticeBanner? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return NoticeBanner(
            id: makeID(from: data),
            title: NSLocalizedString("notice.defaultTitle", comment: ""),
            message: trimmed,
            linkTitle: nil,
            linkURL: nil
        )
    }

    private static func shouldHideForLocale(dictionary: [String: Any]) -> Bool {
        if let onlyZhHans = dictionary["onlyZhHans"] as? Bool, onlyZhHans == true {
            return !isSimplifiedChinese
        }

        if let locale = dictionary["locale"] as? String {
            return !matchesLocale(locale)
        }
        if let lang = dictionary["lang"] as? String {
            return !matchesLocale(lang)
        }
        if let language = dictionary["language"] as? String {
            return !matchesLocale(language)
        }

        if let locales = dictionary["locales"] as? [String] {
            return !locales.contains(where: matchesLocale)
        }
        if let languages = dictionary["languages"] as? [String] {
            return !languages.contains(where: matchesLocale)
        }

        return false
    }

    private static func matchesLocale(_ value: String) -> Bool {
        let normalized = value.lowercased().replacingOccurrences(of: "_", with: "-")
        let appLocale = preferredAppLocale

        if normalized == "zh-hans" || normalized == "zh-cn" || normalized == "zh-hans-cn" {
            return isSimplifiedChinese
        }

        if appLocale == normalized {
            return true
        }

        if normalized.count == 2 {
            return appLocale.hasPrefix(normalized + "-")
        }

        return false
    }

    private static var preferredAppLocale: String {
        let preferred = Bundle.main.preferredLocalizations.first
        let locale = preferred ?? Locale.current.identifier
        return locale.lowercased().replacingOccurrences(of: "_", with: "-")
    }

    private static var isSimplifiedChinese: Bool {
        let locale = preferredAppLocale
        return locale.hasPrefix("zh-hans") || locale.hasPrefix("zh-cn") || locale == "zh"
    }

    private static func makeID(from data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

private struct AppInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("info.title"))
                .font(.headline)
            Text(LocalizedStringKey("info.subtitle"))
                .foregroundStyle(.secondary)
            Divider()
            Text(LocalizedStringKey("info.supported"))
                .font(.callout)
            Text(LocalizedStringKey("info.outputRule"))
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
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct OutputSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OutputConfiguration
    let onSave: (OutputConfiguration) -> Void

    @AppStorage("languagePreference") private var languagePreference: String = "system"

    init(configuration: OutputConfiguration, onSave: @escaping (OutputConfiguration) -> Void) {
        _draft = State(initialValue: configuration)
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            // Match main view's material background
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(localizedString("output.settingsTitle"))
                    .font(.title3)
                Text(localizedString("output.settingsDescription"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("output.suffixLabel"))
                        .font(.headline)
                    TextField(localizedString("output.suffixPlaceholder"), text: $draft.suffix)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("output.ruleLabel"))
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(OutputConflictRule.allCases) { rule in
                            OutputRuleOptionRow(
                                rule: rule,
                                isSelected: draft.rule == rule,
                                action: { draft.rule = rule }
                            )
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                HStack {
                    Button(localizedString("button.cancel")) {
                        dismiss()
                    }
                    Spacer()
                    Button(localizedString("button.saveChanges")) {
                        save()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(minWidth: 360)
        }
    }

    private func save() {
        onSave(draft.normalized())
        dismiss()
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
}

private extension OutputConflictRule {
    var titleKeyString: String {
        switch self {
        case .appendIndex:
            return "output.rule.appendIndex"
        case .overwrite:
            return "output.rule.overwrite"
        case .skip:
            return "output.rule.skip"
        }
    }

    var detailKeyString: String {
        switch self {
        case .appendIndex:
            return "output.rule.appendIndex.desc"
        case .overwrite:
            return "output.rule.overwrite.desc"
        case .skip:
            return "output.rule.skip.desc"
        }
    }
}

private struct OutputRuleOptionRow: View {
    let rule: OutputConflictRule
    let isSelected: Bool
    let action: () -> Void

    @AppStorage("languagePreference") private var languagePreference: String = "system"

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString(rule.titleKeyString))
                        .foregroundStyle(.primary)
                    Text(localizedString(rule.detailKeyString))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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
}

#Preview {
    ContentView()
}
