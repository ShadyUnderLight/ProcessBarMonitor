import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MonitorViewModel

    var body: some View {
        Form {
            Section {
                Picker(L10n.string("picker.menu_bar"), selection: $viewModel.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker(L10n.string("picker.temperature"), selection: $viewModel.temperatureMode) {
                    ForEach(TemperatureMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker(L10n.string("picker.rows"), selection: $viewModel.processLimit) {
                    Text("5").tag(5)
                    Text("8").tag(8)
                    Text("12").tag(12)
                    Text("20").tag(20)
                }

                Picker(L10n.string("picker.refresh_rate"), selection: $viewModel.refreshRatePreset) {
                    ForEach(RefreshRatePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
            } header: {
                Text(L10n.string("settings.section.display"))
            }

            Section {
                Toggle(L10n.string("toggle.launch_at_login"), isOn: Binding(
                    get: { viewModel.launchAtLogin.isEnabled },
                    set: { newValue in
                        viewModel.setLaunchAtLogin(newValue)
                    }
                ))
            } header: {
                Text(L10n.string("settings.section.startup"))
            }

            if let statusMessage = viewModel.statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            viewModel.clearStatusMessage()
                        }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 300)
    }
}