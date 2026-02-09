import SwiftUI

struct SettingsView: View {
    @AppStorage("alwaysShowChangelogBanner") private var alwaysShowChangelogBanner = false
    @AppStorage("disableOnlineNotice") private var disableOnlineNotice = false
    @AppStorage("outputSuffix") private var storedOutputSuffix = "_clean"
    @AppStorage("outputConflictRule") private var storedOutputConflictRule = OutputConflictRule.appendIndex.rawValue
    @State private var isDeveloperOptionsExpanded = false
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Button {
                        resetOutputSettings()
                    } label: {
                        Text("settings.output.reset")
                    }

                    if showResetConfirmation {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            } header: {
                Label("settings.output.section", systemImage: "slider.horizontal.3")
            } footer: {
                Text("settings.output.reset.note")
                    .foregroundStyle(.secondary)
            }

            Section {
                Color.clear
                    .frame(height: 8)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
                Toggle(isOn: $disableOnlineNotice) {
                    Text("settings.notice.disable")
                }
            } header: {
                Label("settings.network.section", systemImage: "network")
            } footer: {
                Text("settings.notice.disable.note")
                    .foregroundStyle(.secondary)
            }

            Section {
                DisclosureGroup(isExpanded: $isDeveloperOptionsExpanded) {
                    Toggle(isOn: $alwaysShowChangelogBanner) {
                        Text("settings.dev.alwaysShowChangelog")
                    }
                    Text("settings.dev.alwaysShowChangelog.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                } label: {
                    Label("settings.dev.section", systemImage: "wrench.and.screwdriver")
                }
            }
        }
        .padding(20)
        .frame(width: 420)
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

#Preview {
    SettingsView()
}
