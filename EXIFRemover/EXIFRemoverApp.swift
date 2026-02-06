import SwiftUI
import AppKit

@main
struct EXIFRemoverApp: App {
    private let helpURL = URL(string: "https://wenlei.top/wenremover-docs-v1/#header-id-2")!

    var body: some Scene {
        WindowGroup("WenRemover") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .help) {
                Button(LocalizedStringKey("menu.help")) {
                    NSWorkspace.shared.open(helpURL)
                }
            }
        }
    }
}
