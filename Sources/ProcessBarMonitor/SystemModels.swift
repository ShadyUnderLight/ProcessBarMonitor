import Foundation

enum TemperatureMode: String, CaseIterable, Identifiable {
    case hottestCPU
    case averageCPU
    case hottestSoC

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hottestCPU:
            return L10n.string("temp_mode.hottest_cpu")
        case .averageCPU:
            return L10n.string("temp_mode.average_cpu")
        case .hottestSoC:
            return L10n.string("temp_mode.hottest_soc")
        }
    }

    init?(savedValue: String) {
        if let mode = TemperatureMode(rawValue: savedValue) {
            self = mode
            return
        }

        switch savedValue {
        case "Hottest CPU":
            self = .hottestCPU
        case "Average CPU":
            self = .averageCPU
        case "Hottest SoC":
            self = .hottestSoC
        default:
            return nil
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case compact
    case labeled
    case temperatureFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            return L10n.string("menu_display.compact")
        case .labeled:
            return L10n.string("menu_display.labeled")
        case .temperatureFirst:
            return L10n.string("menu_display.temperature_first")
        }
    }

    init?(savedValue: String) {
        if let mode = MenuBarDisplayMode(rawValue: savedValue) {
            self = mode
            return
        }

        switch savedValue {
        case "Compact":
            self = .compact
        case "Labeled":
            self = .labeled
        case "Temperature First":
            self = .temperatureFirst
        default:
            return nil
        }
    }
}

struct ProcessChildStat: Identifiable, Hashable {
    let pid: Int
    let command: String
    let cpuPercent: Double
    let memoryMB: Double

    var id: Int { pid }

    var displayName: String {
        let name = URL(fileURLWithPath: command).lastPathComponent
        return name.isEmpty ? command : name
    }
}

struct ProcessStat: Identifiable, Hashable {
    let pid: Int
    let command: String
    let appName: String
    let bundleIdentifier: String?
    let cpuPercent: Double
    let memoryMB: Double
    let processCount: Int
    let childProcesses: [ProcessChildStat]

    var id: String { bundleIdentifier ?? "pid-\(pid)-\(appName)" }

    var displayName: String {
        if !appName.isEmpty { return appName }
        let name = URL(fileURLWithPath: command).lastPathComponent
        return name.isEmpty ? command : name
    }

    var searchableText: String {
        let childText = childProcesses.map { "\($0.displayName) \($0.command) \($0.pid)" }.joined(separator: " ")
        return "\(displayName) \(command) \(pid) \(bundleIdentifier ?? "") \(childText)"
    }

    var pidSummary: String {
        processCount > 1
            ? L10n.format("process.count_procs", processCount)
            : L10n.format("process.pid", pid)
    }
}

struct MetricPoint: Identifiable, Hashable {
    let id = UUID()
    let value: Double
    /// When true, this point represents unavailable/stale data and should be
    /// visually distinguished (e.g. greyed, dashed, or treated as a gap).
    var isStale: Bool = false
}

struct SystemSummary {
    let cpuPercent: Double
    /// System-wide memory pages: active + inactive + wired + compressor.
    /// This is the macOS "memory pressure" figure — not per-process RSS.
    let systemMemoryUsedBytes: UInt64
    /// Actual RSS of this app's processes, summed across all children.
    let appMemoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64
    let thermalState: ProcessInfo.ThermalState
    let cpuTemperatureC: Double?
    let architectureNote: String
    /// Actionable hint shown when temperature is unavailable (nil).
    /// - Intel without tool: install hint; Apple Silicon read-fail: permission check hint.
    let temperatureHint: String?
    let updatedAt: Date

    var memoryPressurePercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return (Double(systemMemoryUsedBytes) / Double(memoryTotalBytes)) * 100
    }

    static let empty = SystemSummary(
        cpuPercent: 0,
        systemMemoryUsedBytes: 0,
        appMemoryUsedBytes: 0,
        memoryTotalBytes: 0,
        thermalState: .nominal,
        cpuTemperatureC: nil,
        architectureNote: "",
        temperatureHint: nil,
        updatedAt: Date()
    )
}
