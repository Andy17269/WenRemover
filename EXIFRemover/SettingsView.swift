import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("alwaysShowChangelogBanner") private var alwaysShowChangelogBanner = false
    @AppStorage("disableOnlineNotice") private var disableOnlineNotice = false
    @AppStorage("outputSuffix") private var storedOutputSuffix = "_clean"
    @AppStorage("outputConflictRule") private var storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
    // Store appearance preference as raw Int (0 = system, 1 = light, 2 = dark)
    @AppStorage("appearancePreference") private var appearancePreferenceRaw: Int = 0
    @AppStorage("languagePreference") private var languagePreference: String = "system"

    @State private var isDeveloperOptionsExpanded = false
    @State private var showResetConfirmation = false

    var body: some View {
        ZStack {
            // Vibrant material background, same as main ContentView
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Section: Language
                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.language.section"), systemImage: "globe")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Picker(selection: $languagePreference) {
                            Text(LocalizedStringKey("settings.language.system")).tag("system")
                            Text(LocalizedStringKey("settings.language.english")).tag("en")
                            Text(LocalizedStringKey("settings.language.chinese")).tag("zh-Hans")
                        } label: {
                            Text(LocalizedStringKey("settings.language.label"))
                        }

                        // Placeholder helper: localized text + tappable link
                        HStack(spacing: 6) {
                            Text(LocalizedStringKey("settings.language.helper.text"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                let urlString = localizedString("settings.language.helper.url")
                                if let url = URL(string: urlString) {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Text(LocalizedStringKey("settings.language.helper.linkText"))
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Section: Output
                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.output.section"), systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Button {
                                resetOutputSettings()
                            } label: {
                                Text(LocalizedStringKey("settings.output.reset"))
                            }

                            if showResetConfirmation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Text(LocalizedStringKey("settings.output.reset.note"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Section: Network
                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.network.section"), systemImage: "network")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Toggle(isOn: $disableOnlineNotice) {
                            Text(LocalizedStringKey("settings.notice.disable"))
                        }

                        Text(LocalizedStringKey("settings.notice.disable.note"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Section: Appearance
                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.appearance.section"), systemImage: "moon.stars")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Picker(selection: $appearancePreferenceRaw) {
                            ForEach([0, 1, 2], id: \.self) { raw in
                                Text(LocalizedStringKey(localizedKey(for: raw))).tag(raw)
                            }
                        } label: {
                            Text(LocalizedStringKey("appearance.theme"))
                        }

                        Text(LocalizedStringKey("settings.appearance.footer"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Section: Developer
                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.dev.section"), systemImage: "wrench.and.screwdriver")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        DisclosureGroup(isExpanded: $isDeveloperOptionsExpanded) {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $alwaysShowChangelogBanner) {
                                    Text(LocalizedStringKey("settings.dev.alwaysShowChangelog"))
                                }
                                Text(LocalizedStringKey("settings.dev.alwaysShowChangelog.note"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                            }
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text(LocalizedStringKey("settings.dev.options"))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 480)
        .frame(minHeight: 540)
        .background(SettingsFullscreenDisabler())
        .onAppear {
            updateWindowTitle()
        }
        .onChange(of: languagePreference) { _, _ in
            updateWindowTitle()
        }
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

    private func updateWindowTitle() {
        DispatchQueue.main.async {
            let title = localizedString("settings.window.title")
            // Try keyWindow first
            if let window = NSApp.keyWindow {
                window.title = title
            }
            // Also apply to any likely Settings window by matching width and being titled
            for window in NSApp.windows {
                if window.styleMask.contains(.titled) {
                    let width = window.frame.size.width
                    if abs(width - 480) < 40 || window.title.lowercased().contains("settings") || window.title.contains("设置") {
                        window.title = title
                    }
                }
            }
        }
    }

    private func localizedKey(for raw: Int) -> String {
        switch raw {
        case 1:
            return "appearance.light"
        case 2:
            return "appearance.dark"
        default:
            return "appearance.system"
        }
    }

    private func resetOutputSettings() {
        storedOutputSuffix = "_clean"
        storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showResetConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showResetConfirmation = false
            }
        }
    }
}

// Keep settings window translucent and disable full screen (match main view behavior)
fileprivate struct SettingsFullscreenDisabler: NSViewRepresentable {
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

#Preview {
    SettingsView()
}
