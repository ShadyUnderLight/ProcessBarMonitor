import Foundation
import Combine

@MainActor
final class MonitorViewModel: ObservableObject {
    let launchAtLogin = LaunchAtLoginManager()
    private let summaryRefreshInterval: UInt64 = 2_000_000_000
    private let processRefreshInterval: TimeInterval = 10

    @Published private(set) var summary = SystemSummary.empty
    @Published private(set) var allProcesses: [ProcessStat] = []
    @Published private(set) var topCPUProcesses: [ProcessStat] = []
    @Published private(set) var topMemoryProcesses: [ProcessStat] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var cpuHistory: [MetricPoint] = []
    @Published private(set) var memoryHistory: [MetricPoint] = []
    @Published private(set) var temperatureHistory: [MetricPoint] = []
    @Published private(set) var isMenuExpanded = false

    @Published var searchText = ""
    @Published var processLimit = 5
    @Published var temperatureMode: TemperatureMode = .hottestCPU
    @Published var menuBarDisplayMode: MenuBarDisplayMode = .compact

    private let metricsProvider = SystemMetricsProvider()
    private let processProvider = ProcessSnapshotProvider()
    private var refreshTask: Task<Void, Never>?
    private var lastProcessRefresh = Date.distantPast

    var menuBarTitle: String {
        let cpu = String(format: "%.0f%%", summary.cpuPercent)
        let memoryUsed = shortMemoryString(bytes: summary.memoryUsedBytes)
        let temp = summary.cpuTemperatureC.map { String(format: "%.0f°", $0) } ?? "--°"

        switch menuBarDisplayMode {
        case .compact:
            return "\(cpu)  \(memoryUsed)  \(temp)"
        case .labeled:
            return "CPU \(cpu)  RAM \(memoryUsed)  \(temp)"
        case .temperatureFirst:
            return "\(temp)  \(cpu)  \(memoryUsed)"
        }
    }

    private func shortMemoryString(bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 10 { return String(format: "%.0fG", gb) }
        return String(format: "%.1fG", gb)
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.refresh(forceProcesses: true)
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.summaryRefreshInterval)
                await self.refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func setMenuExpanded(_ expanded: Bool) {
        isMenuExpanded = expanded
        if expanded {
            Task { await refresh(forceProcesses: true) }
        }
    }

    func refresh(forceProcesses: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true

        let snapshotSummary = metricsProvider.snapshot(temperatureMode: temperatureMode)
        summary = snapshotSummary
        appendHistory(cpu: snapshotSummary.cpuPercent, memory: snapshotSummary.memoryPressurePercent, temperature: snapshotSummary.cpuTemperatureC)

        let shouldRefreshProcesses = forceProcesses
            || isMenuExpanded
            || allProcesses.isEmpty
            || Date().timeIntervalSince(lastProcessRefresh) >= processRefreshInterval

        if shouldRefreshProcesses {
            allProcesses = processProvider.snapshot()
            lastProcessRefresh = Date()
            recomputeVisibleProcesses()
        }

        isRefreshing = false
    }

    private func appendHistory(cpu: Double, memory: Double, temperature: Double?) {
        cpuHistory.append(MetricPoint(value: cpu))
        memoryHistory.append(MetricPoint(value: memory))

        if let temperature {
            temperatureHistory.append(MetricPoint(value: temperature))
        } else if let last = temperatureHistory.last {
            temperatureHistory.append(MetricPoint(value: last.value))
        }

        // Keep history bounded using prefix to avoid unbounded growth
        let limit = 60
        if cpuHistory.count > limit { cpuHistory = Array(cpuHistory.suffix(limit)) }
        if memoryHistory.count > limit { memoryHistory = Array(memoryHistory.suffix(limit)) }
        if temperatureHistory.count > limit { temperatureHistory = Array(temperatureHistory.suffix(limit)) }
    }

    func recomputeVisibleProcesses() {
        let filtered: [ProcessStat]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = allProcesses
        } else {
            let needle = searchText.lowercased()
            filtered = allProcesses.filter { $0.searchableText.lowercased().contains(needle) }
        }

        topCPUProcesses = Array(filtered.sorted(by: { $0.cpuPercent > $1.cpuPercent }).prefix(processLimit))
        topMemoryProcesses = Array(filtered.sorted(by: { $0.memoryMB > $1.memoryMB }).prefix(processLimit))
    }

    func thermalText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
