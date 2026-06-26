import SwiftUI

struct ContentView: View {
    @AppStorage("defaultOutputPath") private var defaultOutputPath: String = ""
    @AppStorage("enableGlassmorphism") private var enableGlassmorphism = true
    @State private var showPermissionAlert = false
    @State private var showSettings = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    enum NavigationItem: Hashable {
        case exif, privacy, viewer
    }
    @State private var selectedItem: NavigationItem? = .exif
    
    var body: some View {
        #if os(macOS)
        mainContent
        #else
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(selection: $selectedItem) {
                    Label(LocalizedStringKey("tab.exif"), systemImage: "wand.and.stars")
                        .tag(NavigationItem.exif)
                    Label(LocalizedStringKey("tab.privacy"), systemImage: "eye.slash")
                        .tag(NavigationItem.privacy)
                    Label(LocalizedStringKey("tab.exifEditor"), systemImage: "info.circle")
                        .tag(NavigationItem.viewer)
                }
                .navigationTitle(LocalizedStringKey("app.title"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            } detail: {
                Group {
                    switch selectedItem {
                    case .exif, .none:
                        EXIFRemoverView()
                    case .privacy:
                        PrivacyProtectorView()
                    case .viewer:
                        EXIFEditorView()
                    }
                }
                .background(
                    Group {
                        if enableGlassmorphism {
                            Rectangle().fill(.regularMaterial)
                        } else {
                            Rectangle().fill(Color.windowBackground)
                        }
                    }
                    .ignoresSafeArea()
                )
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle(LocalizedStringKey("settings.window.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完成") {
                                    showSettings = false
                                }
                            }
                        }
                }
            }
        } else {
            NavigationStack {
                mainContent
                    .navigationTitle(LocalizedStringKey("app.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        NavigationStack {
                            SettingsView()
                                .navigationTitle(LocalizedStringKey("settings.window.title"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button("完成") {
                                            showSettings = false
                                        }
                                    }
                                }
                        }
                    }
            }
        }
        #endif
    }
    
    private var mainContent: some View {
        TabView {
            EXIFRemoverView()
                .tabItem {
                    Label(LocalizedStringKey("tab.exif"), systemImage: "wand.and.stars")
                }
            
            PrivacyProtectorView()
                .tabItem {
                    Label(LocalizedStringKey("tab.privacy"), systemImage: "eye.slash")
                }
                
            EXIFEditorView()
                .tabItem {
                    Label(LocalizedStringKey("tab.exifEditor"), systemImage: "info.circle")
                }
        }
        .background(
            Group {
                if enableGlassmorphism {
                    Rectangle().fill(.regularMaterial)
                } else {
                    Rectangle().fill(Color.windowBackground)
                }
            }
            .ignoresSafeArea()
        )
        .onAppear {
            checkAndRequestFolderAccess()
        }
        .alert(LocalizedStringKey("permission.alert.title"), isPresented: $showPermissionAlert) {
            Button(LocalizedStringKey("permission.alert.button"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("permission.alert.message"))
        }
    }
    
    private func checkAndRequestFolderAccess() {
        #if os(macOS)
        if defaultOutputPath.isEmpty {
            if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                Task.detached {
                    do {
                        _ = try FileManager.default.contentsOfDirectory(atPath: downloadsURL.path)
                        await MainActor.run {
                            defaultOutputPath = downloadsURL.path
                        }
                    } catch {
                        await MainActor.run {
                            showPermissionAlert = true
                        }
                    }
                }
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
}
