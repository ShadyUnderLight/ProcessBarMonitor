import Foundation
import Combine
import AppKit
import OSLog

private struct SettingsStore {
    let defaults: UserDefaults

    func int(forKey key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

@MainActor
final class MonitorViewModel: ObservableObject {
    let launchAtLogin = LaunchAtLoginManager()

    @Published private(set) var summary = SystemSummary.empty
    @Published private(set) var allProcesses: [ProcessStat] = []
    @Published private(set) var topCPUProcesses: [ProcessStat] = []
    @Published private(set) var topMemoryProcesses: [ProcessStat] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var cpuHistory: [MetricPoint] = []
    @Published private(set) var memoryHistory: [MetricPoint] = []
    @Published private(set) var temperatureHistory: [MetricPoint] = []
    @Published private(set) var isMenuExpanded = false
    @Published var statusMessage: String?
    @Published private(set) var processDiagnostics = ProcessSnapshotDiagnostics()

    @Published var searchText = ""
    @Published var processLimit: Int {
        didSet {
            settings.set(processLimit, forKey: Keys.processLimit)
            recomputeVisibleProcesses()
        }
    }
    @Published var temperatureMode: TemperatureMode {
        didSet {
            settings.set(temperatureMode.rawValue, forKey: Keys.temperatureMode)
            Task { await refresh(forceProcesses: true) }
        }
    }
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            settings.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
            Task { await refresh(forceProcesses: false) }
        }
    }
    @Published var refreshRatePreset: RefreshRatePreset {
        didSet {
            settings.set(refreshRatePreset.rawValue, forKey: Keys.refreshRatePreset)
            applyRefreshRatePreset()
            if let existingTask = refreshTask {
                existingTask.cancel()
                refreshTask = createRefreshTask()
            }
        }
    }
    @Published var displayTemplate: MenuBarDisplayTemplate {
        didSet {
            settings.set(displayTemplate.rawValue, forKey: Keys.displayTemplate)
        }
    }
    @Published var moduleVisibility: PopupModuleVisibility {
        didSet {
            settings.set(moduleVisibility.rawValue, forKey: Keys.moduleVisibility)
        }
    }

    private var currentSummaryRefreshInterval: UInt64 = 2_000_000_000
    private var currentProcessRefreshInterval: TimeInterval = 10

    private let metricsProvider = SystemMetricsProvider()
    private let processProvider = ProcessSnapshotProvider.shared
    private let settings: SettingsStore
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai.openclaw.ProcessBarMonitor", category: "process-snapshot")
    private var refreshTask: Task<Void, Never>?
    private var lastProcessRefresh = Date.distantPast
    private var lastLoggedFailureSignature: String?
    private var lastLoggedFailureAt = Date.distantPast

    private enum Keys {
        static let processLimit = "processLimit"
        static let temperatureMode = "temperatureMode"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let refreshRatePreset = "refreshRatePreset"
        static let displayTemplate = "displayTemplate"
        static let moduleVisibility = "moduleVisibility"
    }

    init(defaults: UserDefaults = .standard) {
        let settings = SettingsStore(defaults: defaults)
        self.settings = settings

        let savedProcessLimit = settings.int(forKey: Keys.processLimit) ?? 5
        processLimit = [5, 8, 12, 20].contains(savedProcessLimit) ? savedProcessLimit : 5

        if let rawTemperatureMode = settings.string(forKey: Keys.temperatureMode),
           let parsedTemperatureMode = TemperatureMode(savedValue: rawTemperatureMode) {
            temperatureMode = parsedTemperatureMode
        } else {
            temperatureMode = .hottestCPU
        }

        if let rawMenuBarDisplayMode = settings.string(forKey: Keys.menuBarDisplayMode),
           let parsedMenuBarDisplayMode = MenuBarDisplayMode(savedValue: rawMenuBarDisplayMode) {
            menuBarDisplayMode = parsedMenuBarDisplayMode
        } else {
            menuBarDisplayMode = .compact
        }

        if let rawRefreshRatePreset = settings.string(forKey: Keys.refreshRatePreset),
           let parsedRefreshRatePreset = RefreshRatePreset(savedValue: rawRefreshRatePreset) {
            refreshRatePreset = parsedRefreshRatePreset
        } else {
            refreshRatePreset = .balanced
        }

        if let rawDisplayTemplate = settings.string(forKey: Keys.displayTemplate),
           let parsedTemplate = MenuBarDisplayTemplate(savedValue: rawDisplayTemplate) {
            displayTemplate = parsedTemplate
        } else {
            displayTemplate = .standard
        }

        if let savedRaw = settings.int(forKey: Keys.moduleVisibility) {
            let visibility = PopupModuleVisibility(rawValue: savedRaw)
            if visibility.isEmpty || (visibility.rawValue & ~PopupModuleVisibility.all.rawValue) != 0 {
                moduleVisibility = .defaultVisibility
            } else {
                moduleVisibility = visibility
            }
        } else {
            moduleVisibility = .defaultVisibility
        }
    }

    var menuBarTitle: String {
        let cpu = String(format: "%.0f%%", summary.cpuPercent)
        let mem = String(format: "%.0f%%", summary.memoryPressurePercent)
        let temp = summary.cpuTemperatureC.map { String(format: "%.0f°", $0) } ?? "--°"

        switch menuBarDisplayMode {
        case .compact:
            return L10n.format("menu_bar_title.compact", cpu, mem, temp)
        case .labeled:
            return L10n.format("menu_bar_title.labeled", cpu, mem, temp)
        case .temperatureFirst:
            return L10n.format("menu_bar_title.temperature_first", temp, cpu, mem)
        }
    }

    private func shortMemoryString(bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 10 { return String(format: "%.0fG", gb) }
        return String(format: "%.1fG", gb)
    }

    private func applyRefreshRatePreset() {
        currentSummaryRefreshInterval = refreshRatePreset.summaryInterval
        currentProcessRefreshInterval = refreshRatePreset.processInterval
    }

    private func createRefreshTask() -> Task<Void, Never> {
        Task { [weak self] in
            await self?.refresh(forceProcesses: true)
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.currentSummaryRefreshInterval)
                await self.refresh()
            }
        }
    }

    func start() {
        guard refreshTask == nil else { return }

        let legacyCleanup = LegacyLaunchAgentCleaner.cleanupIfNeeded()
        if let messageKey = legacyCleanup.messageKey {
            if let details = legacyCleanup.details {
                statusMessage = L10n.format(messageKey, details)
            } else {
                statusMessage = L10n.string(messageKey)
            }
        }
        launchAtLogin.refreshState()
        applyRefreshRatePreset()

        refreshTask = createRefreshTask()
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
        defer { isRefreshing = false }

        let processIntervalElapsed = Date().timeIntervalSince(lastProcessRefresh) >= currentProcessRefreshInterval
        let shouldRefreshProcesses = forceProcesses
            || allProcesses.isEmpty
            || (isMenuExpanded && processIntervalElapsed)

        async let summaryTask = metricsProvider.snapshot(temperatureMode: temperatureMode)
        async let processTask: Result<[ProcessStat], Error>? = shouldRefreshProcesses ? processSnapshotResult() : nil

        let snapshotSummary = await summaryTask
        summary = snapshotSummary
        appendHistory(cpu: snapshotSummary.cpuPercent, memory: snapshotSummary.memoryPressurePercent, temperature: snapshotSummary.cpuTemperatureC)

        if let processResult = await processTask {
            processDiagnostics.markAttempt()
            switch processResult {
            case .success(let processes):
                allProcesses = processes
                lastProcessRefresh = Date()
                recomputeVisibleProcesses()
                processDiagnostics.markSuccess(
                    processCount: processes.count,
                    topCPUCount: topCPUProcesses.count,
                    topMemoryCount: topMemoryProcesses.count
                )
                statusMessage = nil
            case .failure(let error):
                let message = error.localizedDescription
                let details = String(describing: error)
                processDiagnostics.markFailure(message: message, details: details)
                logProcessSnapshotFailureIfNeeded(message: message, details: details)
                statusMessage = L10n.format("status.failed_to_load_top_apps", error.localizedDescription)
            }
        }
    }

    private func processSnapshotResult() async -> Result<[ProcessStat], Error> {
        do {
            return .success(try await processProvider.snapshot())
        } catch {
            return .failure(error)
        }
    }

    private func appendHistory(cpu: Double, memory: Double, temperature: Double?) {
        cpuHistory.append(MetricPoint(value: cpu))
        memoryHistory.append(MetricPoint(value: memory))

        if let temperature {
            temperatureHistory.append(MetricPoint(value: temperature))
        } else {
            // Temperature unavailable: record a stale point so the sparkline
            // visually gaps rather than silently repeating the last known value.
            let value = temperatureHistory.last?.value
            temperatureHistory.append(MetricPoint(value: value ?? 0, isStale: true))
        }

        let limit = 60
        if cpuHistory.count > limit { cpuHistory.removeFirst(cpuHistory.count - limit) }
        if memoryHistory.count > limit { memoryHistory.removeFirst(memoryHistory.count - limit) }
        if temperatureHistory.count > limit { temperatureHistory.removeFirst(temperatureHistory.count - limit) }
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

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            statusMessage = enabled
                ? L10n.string("status.launch_at_login_enabled")
                : L10n.string("status.launch_at_login_disabled")
        } catch {
            statusMessage = error.localizedDescription
            launchAtLogin.refreshState()
        }
    }

    func clearStatusMessage() {
        statusMessage = nil
    }

    func copyDiagnosticsToPasteboard() {
        let report = diagnosticsReport()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(report, forType: .string) {
            statusMessage = L10n.string("status.diagnostics_copied")
        } else {
            statusMessage = L10n.string("status.diagnostics_copy_failed")
        }
    }

    func thermalText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return L10n.string("thermal.nominal")
        case .fair: return L10n.string("thermal.fair")
        case .serious: return L10n.string("thermal.serious")
        case .critical: return L10n.string("thermal.critical")
        @unknown default: return L10n.string("thermal.unknown")
        }
    }

    private func logProcessSnapshotFailureIfNeeded(message: String, details: String) {
        let signature = "\(message)|\(details)"
        let now = Date()
        let minInterval: TimeInterval = 60

        if signature == lastLoggedFailureSignature, now.timeIntervalSince(lastLoggedFailureAt) < minInterval {
            return
        }

        lastLoggedFailureSignature = signature
        lastLoggedFailureAt = now
        logger.error("Process snapshot failed. attempts=\(self.processDiagnostics.attemptCount, privacy: .public) failures=\(self.processDiagnostics.failureCount, privacy: .public) message=\(message, privacy: .public) details=\(details, privacy: .public)")
    }

    private func diagnosticsReport() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "unknown"
        let appBuild = (info["CFBundleVersion"] as? String) ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = iso.string(from: Date())

        func format(_ date: Date?) -> String {
            guard let date else { return "n/a" }
            return iso.string(from: date)
        }

        return """
        ProcessBarMonitor Diagnostics
        generated_at: \(now)
        app_version: \(appVersion)
        app_build: \(appBuild)
        os: \(osVersion)
        process_snapshot_attempts: \(processDiagnostics.attemptCount)
        process_snapshot_successes: \(processDiagnostics.successCount)
        process_snapshot_failures: \(processDiagnostics.failureCount)
        process_snapshot_last_attempt: \(format(processDiagnostics.lastAttemptAt))
        process_snapshot_last_success: \(format(processDiagnostics.lastSuccessAt))
        process_snapshot_last_failure: \(format(processDiagnostics.lastFailureAt))
        process_snapshot_last_process_count: \(processDiagnostics.lastSnapshotProcessCount)
        top_cpu_rows: \(processDiagnostics.lastTopCPUCount)
        top_memory_rows: \(processDiagnostics.lastTopMemoryCount)
        process_snapshot_last_error: \(processDiagnostics.lastFailureMessage ?? "n/a")
        process_snapshot_last_error_detail: \(processDiagnostics.lastFailureDetails ?? "n/a")
        status_message: \(statusMessage ?? "n/a")
        menu_expanded: \(isMenuExpanded)
        search_text: \(searchText)
        """
    }
}
