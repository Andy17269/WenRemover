import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SettingsView: View {
    @AppStorage("alwaysShowChangelogBanner") private var alwaysShowChangelogBanner = false
    @AppStorage("disableOnlineNotice") private var disableOnlineNotice = false
    @AppStorage("outputSuffix") private var storedOutputSuffix = "_clean"
    @AppStorage("outputConflictRule") private var storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
    @AppStorage("appearancePreference") private var appearancePreferenceRaw: Int = 0
    @AppStorage("languagePreference") private var languagePreference: String = "system"
    @AppStorage("hasSeenChangelogBanner") private var hasSeenChangelogBanner = false
    @AppStorage("hasSeenPrivacyBetaBanner") private var hasSeenPrivacyBetaBanner = false
    @AppStorage("enableGlassmorphism") private var enableGlassmorphism = true

    @State private var isDeveloperOptionsExpanded = false
    @State private var showResetConfirmation = false
    @State private var showNoticeResetConfirmation = false

    var body: some View {
        #if os(macOS)
        macOSSettingsBody
        #else
        iOSSettingsBody
        #endif
    }

    private var macOSSettingsBody: some View {
        ZStack {
            Group {
                if enableGlassmorphism {
                    Rectangle().fill(.regularMaterial)
                } else {
                    Rectangle().fill(Color.windowBackground)
                }
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.language.section"), systemImage: "globe")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Picker(selection: $languagePreference) {
                            Text(LocalizedStringKey("settings.language.system")).tag("system")
                            Text(LocalizedStringKey("settings.language.english")).tag("en")
                            Text(LocalizedStringKey("settings.language.chinese")).tag("zh-Hans")
                            Text(LocalizedStringKey("settings.language.chinese_traditional")).tag("zh-Hant")
                            Text(LocalizedStringKey("settings.language.japanese")).tag("ja")
                            Text(LocalizedStringKey("settings.language.russian")).tag("ru")
                        } label: {
                            Text(LocalizedStringKey("settings.language.label"))
                        }

                        HStack(spacing: 6) {
                            Text(LocalizedStringKey("settings.language.helper.text"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                let urlString = localizedString("settings.language.helper.url")
                                if let url = URL(string: urlString) {
                                    #if os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #else
                                    UIApplication.shared.open(url)
                                    #endif
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

                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.general.section"), systemImage: "gearshape")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Button {
                                resetAllNotices()
                            } label: {
                                Text(LocalizedStringKey("settings.notice.reset"))
                            }
                            if showNoticeResetConfirmation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        Text(LocalizedStringKey("settings.notice.reset.note"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

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
                        
                        Toggle(isOn: $enableGlassmorphism) {
                            Text(LocalizedStringKey("settings.appearance.glassmorphism"))
                        }

                        Text(LocalizedStringKey("settings.appearance.footer"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label(LocalizedStringKey("settings.permission.section"), systemImage: "hand.raised")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                                #if os(macOS)
                                NSWorkspace.shared.open(url)
                                #else
                                UIApplication.shared.open(url)
                                #endif
                            }
                        }) {
                            Text(LocalizedStringKey("settings.permission.manage"))
                        }

                        Text(LocalizedStringKey("settings.permission.note"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

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
                                
                                Divider().padding(.vertical, 8)
                                
                                Text("Device Capability (Core ML Ready)")
                                    .font(.subheadline).bold()
                                    .padding(.bottom, 4)
                                
                                let caps = DeviceCapability.current
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Neural Engine:")
                                        Spacer()
                                        Text(caps.hasNeuralEngine ? "Available" : "Not Found")
                                            .foregroundStyle(caps.hasNeuralEngine ? .green : .orange)
                                    }
                                    HStack {
                                        Text("Physical Memory:")
                                        Spacer()
                                        Text("\(caps.memoryGB) GB")
                                            .foregroundStyle(caps.memoryGB >= 8 ? .green : .orange)
                                    }
                                    HStack {
                                        Text("Low Power Mode:")
                                        Spacer()
                                        Text(caps.isLowPower ? "Active" : "Inactive")
                                            .foregroundStyle(caps.isLowPower ? .orange : .secondary)
                                    }
                                }
                                .font(.caption)
                                .padding(12)
                                .background(.black.opacity(0.1))
                                .cornerRadius(8)
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
        #if os(macOS)
        .background(SettingsFullscreenDisabler())
        #endif
        .onAppear {
            updateWindowTitle()
        }
        .onChange(of: languagePreference) { _, _ in
            updateWindowTitle()
        }
    }
    
    private var iOSSettingsBody: some View {
        Form {
            Section {
                Picker(selection: $languagePreference) {
                    Text(LocalizedStringKey("settings.language.system")).tag("system")
                    Text(LocalizedStringKey("settings.language.english")).tag("en")
                    Text(LocalizedStringKey("settings.language.chinese")).tag("zh-Hans")
                    Text(LocalizedStringKey("settings.language.chinese_traditional")).tag("zh-Hant")
                    Text(LocalizedStringKey("settings.language.japanese")).tag("ja")
                    Text(LocalizedStringKey("settings.language.russian")).tag("ru")
                } label: {
                    Text(LocalizedStringKey("settings.language.label"))
                }
                
                Button(action: {
                    let urlString = localizedString("settings.language.helper.url")
                    if let url = URL(string: urlString) {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    Text(LocalizedStringKey("settings.language.helper.linkText"))
                }
            } header: {
                Text(LocalizedStringKey("settings.language.section"))
            } footer: {
                Text(LocalizedStringKey("settings.language.helper.text"))
            }
            
            Section {
                Button {
                    resetAllNotices()
                } label: {
                    HStack {
                        Text(LocalizedStringKey("settings.notice.reset"))
                        Spacer()
                        if showNoticeResetConfirmation {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
            } header: {
                Text(LocalizedStringKey("settings.general.section"))
            } footer: {
                Text(LocalizedStringKey("settings.notice.reset.note"))
            }
            
            Section {
                Button {
                    resetOutputSettings()
                } label: {
                    HStack {
                        Text(LocalizedStringKey("settings.output.reset"))
                        Spacer()
                        if showResetConfirmation {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
            } header: {
                Text(LocalizedStringKey("settings.output.section"))
            } footer: {
                Text(LocalizedStringKey("settings.output.reset.note"))
            }
            
            Section {
                Toggle(isOn: $disableOnlineNotice) {
                    Text(LocalizedStringKey("settings.notice.disable"))
                }
            } header: {
                Text(LocalizedStringKey("settings.network.section"))
            } footer: {
                Text(LocalizedStringKey("settings.notice.disable.note"))
            }
            
            Section {
                Picker(selection: $appearancePreferenceRaw) {
                    ForEach([0, 1, 2], id: \.self) { raw in
                        Text(LocalizedStringKey(localizedKey(for: raw))).tag(raw)
                    }
                } label: {
                    Text(LocalizedStringKey("appearance.theme"))
                }
                
                Toggle(isOn: $enableGlassmorphism) {
                    Text(LocalizedStringKey("settings.appearance.glassmorphism"))
                }
            } header: {
                Text(LocalizedStringKey("settings.appearance.section"))
            } footer: {
                Text(LocalizedStringKey("settings.appearance.footer"))
            }
            
            Section {
                DisclosureGroup(isExpanded: $isDeveloperOptionsExpanded) {
                    Toggle(isOn: $alwaysShowChangelogBanner) {
                        Text(LocalizedStringKey("settings.dev.alwaysShowChangelog"))
                    }
                    
                    let caps = DeviceCapability.current
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Neural Engine:")
                            Spacer()
                            Text(caps.hasNeuralEngine ? "Available" : "Not Found")
                                .foregroundStyle(caps.hasNeuralEngine ? .green : .orange)
                        }
                        HStack {
                            Text("Physical Memory:")
                            Spacer()
                            Text("\(caps.memoryGB) GB")
                                .foregroundStyle(caps.memoryGB >= 8 ? .green : .orange)
                        }
                        HStack {
                            Text("Low Power Mode:")
                            Spacer()
                            Text(caps.isLowPower ? "Active" : "Inactive")
                                .foregroundStyle(caps.isLowPower ? .orange : .secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.vertical, 8)
                } label: {
                    Text(LocalizedStringKey("settings.dev.options"))
                }
            } header: {
                Text(LocalizedStringKey("settings.dev.section"))
            }
        }
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
        #if os(macOS)
        DispatchQueue.main.async {
            let title = localizedString("settings.window.title")
            if let window = NSApp.keyWindow {
                window.title = title
            }
            for window in NSApp.windows {
                if window.styleMask.contains(.titled) {
                    let width = window.frame.size.width
                    if abs(width - 480) < 40 || window.title.lowercased().contains("settings") || window.title.contains("设置") {
                        window.title = title
                    }
                }
            }
        }
        #endif
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
    
    private func resetAllNotices() {
        hasSeenChangelogBanner = false
        hasSeenPrivacyBetaBanner = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showNoticeResetConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showNoticeResetConfirmation = false
            }
        }
    }
}

// 窗口半透明+禁全屏
#if os(macOS)
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
#endif

#Preview {
    SettingsView()
}

struct DeviceCapability {
    let hasNeuralEngine: Bool
    let memoryGB: Int
    let isLowPower: Bool
    
    static var current: DeviceCapability {
        let mem = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        #if arch(arm64)
        let hasNE = true // M系列芯片标配 ANE
        #else
        let hasNE = false
        #endif
        
        return DeviceCapability(hasNeuralEngine: hasNE, memoryGB: mem, isLowPower: lowPower)
    }
}
