import SwiftUI

struct ContentView: View {
    @AppStorage("defaultOutputPath") private var defaultOutputPath: String = ""
    @State private var showPermissionAlert = false
    var body: some View {
        TabView {
            EXIFRemoverView()
                .tabItem {
                    Label(LocalizedStringKey("tab.exif"), systemImage: "wand.and.stars")
                }
            
            PrivacyProtectorView()
                .tabItem {
                    Label(LocalizedStringKey("tab.privacy"), systemImage: "eye.slash")
                }
                
            EXIFViewerView()
                .tabItem {
                    Label(LocalizedStringKey("tab.exifViewer"), systemImage: "info.circle")
                }
        }
        .background(.regularMaterial)
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
    }
}

#Preview {
    ContentView()
}
