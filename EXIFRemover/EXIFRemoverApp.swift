import SwiftUI
import AppKit

@main
struct EXIFRemoverApp: App {
    private let helpURL: URL = {
        guard let url = URL(string: "https://wenlei.top/wenremover-docs-v1/#header-id-2") else {
            fatalError("Invalid help URL")
        }
        return url
    }()

    // Observe the stored appearance preference (raw Int). Use raw Int to avoid cross-file symbol resolution issues.
    @AppStorage("appearancePreference") private var appearancePreferenceRaw: Int = 0
    @AppStorage("languagePreference") private var languagePreference: String = "system"

    var body: some Scene {
        WindowGroup(NSLocalizedString("app.title", comment: "")) {
            ContentView()
                .environment(\.locale, languagePreference == "system" ? .current : Locale(identifier: languagePreference))
                .onAppear {
                    NSApp.appearance = Self.nsAppearance(for: appearancePreferenceRaw)
                    updateSettingsWindowTitle()
                }
                .onChange(of: appearancePreferenceRaw) { _, newValue in
                    NSApp.appearance = Self.nsAppearance(for: newValue)
                }
                .onChange(of: languagePreference) { _, _ in
                    updateSettingsWindowTitle()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        Settings {
            SettingsView()
                .environment(\.locale, languagePreference == "system" ? .current : Locale(identifier: languagePreference))
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button(LocalizedStringKey("menu.help")) {
                    NSWorkspace.shared.open(helpURL)
                }
            }
        }
    }

    private static func nsAppearance(for rawValue: Int) -> NSAppearance? {
        switch rawValue {
        case 1:
            return NSAppearance(named: .aqua)
        case 2:
            return NSAppearance(named: .darkAqua)
        default:
            return nil
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

    private func updateSettingsWindowTitle() {
        DispatchQueue.main.async {
            let title = localizedString("settings.window.title")
            let appTitleLower = localizedString("app.title").lowercased()
            for window in NSApp.windows {
                guard window.styleMask.contains(.titled) else { continue }
                let lower = window.title.lowercased()
                let width = window.frame.size.width
                // Only update windows that look like the Settings window:
                // - title already contains "settings"/"设置" (likely the settings window)
                // - OR window width roughly matches the settings view width
                // Never override the main app window whose title equals the app title.
                let isSettingsLike = lower.contains("settings") || lower.contains("设置") || (abs(width - 560) < 40)
                let isAppWindow = lower == appTitleLower
                if isSettingsLike && !isAppWindow {
                    window.title = title
                }
            }
        }
    }
}
