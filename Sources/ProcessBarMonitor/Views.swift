import SwiftUI
import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct SummaryCardView: View {
    let title: String
    let value: String
    var accent: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ProcessRowView: View {
    let process: ProcessStat
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text(process.displayName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(process.pidSummary)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 72, alignment: .leading)

                    Text(String(format: "%.1f%%", process.cpuPercent))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 56, alignment: .trailing)

                    Text(String(format: "%.0f MB", process.memoryMB))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 66, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let bundleIdentifier = process.bundleIdentifier {
                        Text(bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(process.childProcesses.prefix(8)) { child in
                        HStack(spacing: 8) {
                            Text("↳ \(child.displayName)")
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(L10n.format("process.pid", child.pid))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Text(String(format: "%.1f%%", child.cpuPercent))
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 56, alignment: .trailing)
                            Text(String(format: "%.0f MB", child.memoryMB))
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 66, alignment: .trailing)
                        }
                    }

                    if process.childProcesses.count > 8 {
                        Text(L10n.format("process.more_count", process.childProcesses.count - 8))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MonitorViewModel
    @State private var expandedCPUApps: Set<String> = []
    @State private var expandedMemoryApps: Set<String> = []

    private func quitApplication() {
        viewModel.setMenuExpanded(false)
        viewModel.stop()

        NSApp.windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    private var memorySummary: String {
        let used = ByteCountFormatter.string(fromByteCount: Int64(viewModel.summary.systemMemoryUsedBytes), countStyle: .memory)
        let total = ByteCountFormatter.string(fromByteCount: Int64(viewModel.summary.memoryTotalBytes), countStyle: .memory)
        return "\(used) / \(total)"
    }

    private var memoryCompact: String {
        L10n.format("metric.used_percent", viewModel.summary.memoryPressurePercent)
    }

    private var currentTemperatureColor: Color {
        guard let temp = viewModel.summary.cpuTemperatureC else { return .secondary }
        if temp >= 85 { return .red }
        if temp >= 70 { return .orange }
        return .green
    }

    private var healthLine: String {
        let temp = viewModel.summary.cpuTemperatureC.map { String(format: "%.1f°C", $0) } ?? "--"
        return L10n.format("health.line", String(format: "%.0f%%", viewModel.summary.cpuPercent), memoryCompact, temp)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    SummaryCardView(title: L10n.string("summary.cpu"), value: String(format: "%.1f %%", viewModel.summary.cpuPercent), accent: .primary)
                    SummaryCardView(title: L10n.string("summary.ram"), value: memorySummary, accent: .blue)
                    SummaryCardView(title: L10n.string("summary.temp"), value: viewModel.summary.cpuTemperatureC.map { String(format: "%.1f °C", $0) } ?? "--", accent: currentTemperatureColor)
                    SummaryCardView(title: L10n.string("summary.thermal"), value: viewModel.thermalText(viewModel.summary.thermalState), accent: .pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(healthLine)
                        .font(.subheadline.weight(.medium))
                    Text(viewModel.summary.architectureNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    SparklineView(
                        title: L10n.string("trend.cpu"),
                        points: viewModel.cpuHistory,
                        color: .primary,
                        valueText: String(format: "%.1f%%", viewModel.summary.cpuPercent),
                        fixedMax: 100,
                        warningThreshold: 60,
                        criticalThreshold: 85
                    )
                    SparklineView(
                        title: L10n.string("trend.ram"),
                        points: viewModel.memoryHistory,
                        color: .blue,
                        valueText: String(format: "%.0f%%", viewModel.summary.memoryPressurePercent),
                        fixedMax: 100,
                        warningThreshold: 75,
                        criticalThreshold: 90
                    )
                    SparklineView(
                        title: L10n.string("trend.temp"),
                        points: viewModel.temperatureHistory,
                        color: .green,
                        valueText: viewModel.summary.cpuTemperatureC.map { String(format: "%.1f°C", $0) } ?? "--",
                        fixedMax: nil,
                        warningThreshold: 70,
                        criticalThreshold: 85
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("section.filter_display"))
                        .font(.headline)

                    Picker(L10n.string("picker.menu_bar"), selection: $viewModel.menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(L10n.string("picker.temperature"), selection: $viewModel.temperatureMode) {
                        ForEach(TemperatureMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .onChange(of: viewModel.temperatureMode) { _ in
                        Task { await viewModel.refresh(forceProcesses: true) }
                    }

                    TextField(L10n.string("search.placeholder"), text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.searchText) { _ in
                            viewModel.recomputeVisibleProcesses()
                        }

                    Picker(L10n.string("picker.rows"), selection: $viewModel.processLimit) {
                        Text("5").tag(5)
                        Text("8").tag(8)
                        Text("12").tag(12)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.processLimit) { _ in
                        viewModel.recomputeVisibleProcesses()
                    }
                }

                Toggle(L10n.string("toggle.launch_at_login"), isOn: Binding(
                    get: { viewModel.launchAtLogin.isEnabled },
                    set: { newValue in
                        viewModel.setLaunchAtLogin(newValue)
                    }
                ))

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -4)
                        .onTapGesture {
                            viewModel.clearStatusMessage()
                        }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("section.top_apps_cpu"))
                        .font(.headline)
                    Text(L10n.string("section.top_apps_cpu_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    processHeader
                    ForEach(viewModel.topCPUProcesses) { process in
                        ProcessRowView(
                            process: process,
                            expanded: expandedCPUApps.contains(process.id),
                            onToggle: {
                                if expandedCPUApps.contains(process.id) { expandedCPUApps.remove(process.id) }
                                else { expandedCPUApps.insert(process.id) }
                            }
                        )
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("section.top_apps_memory"))
                        .font(.headline)
                    Text(L10n.string("section.top_apps_memory_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    processHeader
                    ForEach(viewModel.topMemoryProcesses) { process in
                        ProcessRowView(
                            process: process,
                            expanded: expandedMemoryApps.contains(process.id),
                            onToggle: {
                                if expandedMemoryApps.contains(process.id) { expandedMemoryApps.remove(process.id) }
                                else { expandedMemoryApps.insert(process.id) }
                            }
                        )
                    }
                }

                Divider()

                HStack {
                    Button(action: { Task { await viewModel.refresh(forceProcesses: true) } }) {
                        Text(viewModel.isRefreshing ? L10n.string("button.refreshing") : L10n.string("button.refresh_now"))
                    }
                    .disabled(viewModel.isRefreshing)

                    Button(L10n.string("button.copy_diagnostics")) {
                        viewModel.copyDiagnosticsToPasteboard()
                    }

                    Button(L10n.string("button.quit")) {
                        quitApplication()
                    }

                    Spacer()

                    Text(L10n.format("label.updated_at", viewModel.summary.updatedAt.formatted(date: .omitted, time: .standard)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 620, maxWidth: 620, minHeight: 760, maxHeight: 760)
        .onAppear {
            viewModel.setMenuExpanded(true)
        }
        .onDisappear {
            viewModel.setMenuExpanded(false)
        }
    }

    private var processHeader: some View {
        HStack(spacing: 8) {
            Text(L10n.string("header.app"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.string("header.group"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(L10n.string("header.cpu"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(L10n.string("header.memory"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .trailing)
        }
    }
}
