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
                    // Ensure main window defaults to min size on launch
                    setMainWindowToMinSize()
                }
                .onChange(of: appearancePreferenceRaw) { _, newValue in
                    NSApp.appearance = Self.nsAppearance(for: newValue)
                }
                .onChange(of: languagePreference) { _, _ in
                    updateSettingsWindowTitle()
                    // When language changes, adjust default size (min width may differ per language)
                    setMainWindowToMinSize()
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

    private var minWindowWidth: CGFloat {
        if languagePreference == "en" { return 685 }
        if languagePreference == "zh-Hans" { return 580 }
        // System fallback
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return lang.contains("zh") ? 580 : 685
    }

    private let minWindowHeight: CGFloat = 640

    private func setMainWindowToMinSize() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let appTitleLower = localizedString("app.title").lowercased()
            // Try find the main app window by title match first, otherwise fall back to keyWindow
            var targetWindow: NSWindow? = nil
            for window in NSApp.windows {
                guard window.styleMask.contains(.titled) else { continue }
                if window.title.lowercased() == appTitleLower {
                    targetWindow = window
                    break
                }
            }
            if targetWindow == nil {
                targetWindow = NSApp.keyWindow
            }
            guard let window = targetWindow else { return }

            let targetSize = NSSize(width: minWindowWidth, height: minWindowHeight)

            // Set minimum size to prevent shrinking below designed layout
            window.minSize = targetSize

            // Compute centered frame on the window's screen or main screen
            let screen = window.screen ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let originX = visible.origin.x + (visible.size.width - targetSize.width) / 2.0
                let originY = visible.origin.y + (visible.size.height - targetSize.height) / 2.0
                let targetFrame = NSRect(x: originX, y: originY, width: targetSize.width, height: targetSize.height)
                window.setFrame(targetFrame, display: true, animate: false)
            } else {
                // Fallback: resize without reposition
                var frame = window.frame
                frame.size = targetSize
                window.setFrame(frame, display: true, animate: false)
            }
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
                let isSettingsLike = lower.contains("settings") || lower.contains("设置") || (abs(width - 480) < 40)
                let isAppWindow = lower == appTitleLower
                if isSettingsLike && !isAppWindow {
                    window.title = title
                }
            }
        }
    }
}
