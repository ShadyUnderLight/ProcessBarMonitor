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

                Picker(L10n.string("picker.display_template"), selection: $viewModel.displayTemplate) {
                    ForEach(MenuBarDisplayTemplate.allCases) { template in
                        Text(template.title).tag(template)
                    }
                }
            } header: {
                Text(L10n.string("settings.section.display"))
            }

            Section {
                Toggle(L10n.string("toggle.sparklines"), isOn: Binding(
                    get: { viewModel.moduleVisibility.contains(.sparklines) },
                    set: { viewModel.moduleVisibility = $0 ? viewModel.moduleVisibility.union(.sparklines) : viewModel.moduleVisibility.subtracting(.sparklines) }
                ))
                Toggle(L10n.string("toggle.top_cpu"), isOn: Binding(
                    get: { viewModel.moduleVisibility.contains(.topCPU) },
                    set: { viewModel.moduleVisibility = $0 ? viewModel.moduleVisibility.union(.topCPU) : viewModel.moduleVisibility.subtracting(.topCPU) }
                ))
                Toggle(L10n.string("toggle.top_memory"), isOn: Binding(
                    get: { viewModel.moduleVisibility.contains(.topMemory) },
                    set: { viewModel.moduleVisibility = $0 ? viewModel.moduleVisibility.union(.topMemory) : viewModel.moduleVisibility.subtracting(.topMemory) }
                ))
                Toggle(L10n.string("toggle.temperature_hint"), isOn: Binding(
                    get: { viewModel.moduleVisibility.contains(.temperatureHint) },
                    set: { viewModel.moduleVisibility = $0 ? viewModel.moduleVisibility.union(.temperatureHint) : viewModel.moduleVisibility.subtracting(.temperatureHint) }
                ))
                Toggle(L10n.string("toggle.diagnostics"), isOn: Binding(
                    get: { viewModel.moduleVisibility.contains(.diagnostics) },
                    set: { viewModel.moduleVisibility = $0 ? viewModel.moduleVisibility.union(.diagnostics) : viewModel.moduleVisibility.subtracting(.diagnostics) }
                ))
                Toggle(L10n.string("toggle.power"), isOn: Binding(
                    get: { viewModel.moduleVisibility.contains(.power) },
                    set: { viewModel.moduleVisibility = $0 ? viewModel.moduleVisibility.union(.power) : viewModel.moduleVisibility.subtracting(.power) }
                ))
            } header: {
                Text(L10n.string("settings.section.modules"))
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