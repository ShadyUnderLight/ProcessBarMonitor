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

enum RefreshRatePreset: String, CaseIterable, Identifiable {
    case powerSaving
    case balanced
    case realTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .powerSaving:
            return L10n.string("refresh_rate.power_saving")
        case .balanced:
            return L10n.string("refresh_rate.balanced")
        case .realTime:
            return L10n.string("refresh_rate.real_time")
        }
    }

    var summaryInterval: UInt64 {
        switch self {
        case .powerSaving: return 10_000_000_000
        case .balanced: return 2_000_000_000
        case .realTime: return 500_000_000
        }
    }

    var processInterval: TimeInterval {
        switch self {
        case .powerSaving: return 30
        case .balanced: return 10
        case .realTime: return 5
        }
    }

    init?(savedValue: String) {
        if let preset = RefreshRatePreset(rawValue: savedValue) {
            self = preset
            return
        }

        switch savedValue {
        case "Power Saving": self = .powerSaving
        case "Balanced": self = .balanced
        case "Real-time": self = .realTime
        default: return nil
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

enum MenuBarDisplayTemplate: String, CaseIterable, Identifiable {
    case minimal
    case standard
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal:
            return L10n.string("template.minimal")
        case .standard:
            return L10n.string("template.standard")
        case .detailed:
            return L10n.string("template.detailed")
        }
    }

    init?(savedValue: String) {
        if let template = MenuBarDisplayTemplate(rawValue: savedValue) {
            self = template
            return
        }

        switch savedValue {
        case "Minimal": self = .minimal
        case "Standard": self = .standard
        case "Detailed": self = .detailed
        default: return nil
        }
    }
}

struct PopupModuleVisibility: OptionSet, Equatable {
    let rawValue: Int

    static let sparklines        = PopupModuleVisibility(rawValue: 1 << 0)
    static let topCPU           = PopupModuleVisibility(rawValue: 1 << 1)
    static let topMemory        = PopupModuleVisibility(rawValue: 1 << 2)
    static let temperatureHint  = PopupModuleVisibility(rawValue: 1 << 3)
    static let diagnostics      = PopupModuleVisibility(rawValue: 1 << 4)
    static let power            = PopupModuleVisibility(rawValue: 1 << 5)

    static let all: PopupModuleVisibility = [.sparklines, .topCPU, .topMemory, .temperatureHint, .diagnostics, .power]

    static var defaultVisibility: PopupModuleVisibility {
        [.sparklines, .topCPU, .topMemory]
    }
}

enum BatteryStatus: String {
    case charging
    case discharging
    case full
    case noBattery

    var title: String {
        switch self {
        case .charging:   return L10n.string("battery.charging")
        case .discharging: return L10n.string("battery.discharging")
        case .full:      return L10n.string("battery.full")
        case .noBattery: return L10n.string("battery.no_battery")
        }
    }
}

struct PowerSourceInfo: Equatable {
    let batteryPercent: Double
    let status: BatteryStatus
    let isPluggedIn: Bool
    /// Time remaining in seconds, nil if unavailable.
    let timeRemaining: Int?
    /// True if battery is present on this device.
    let hasBattery: Bool

    var timeRemainingText: String {
        guard let seconds = timeRemaining else {
            return L10n.string("battery.time_remaining_unavailable")
        }
        if seconds <= 0 {
            return L10n.string("battery.time_remaining_unavailable")
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return L10n.format("battery.time_remaining_format", hours, minutes)
    }

    static var unavailable: PowerSourceInfo {
        PowerSourceInfo(
            batteryPercent: 0,
            status: .noBattery,
            isPluggedIn: false,
            timeRemaining: nil,
            hasBattery: false
        )
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
    let powerSource: PowerSourceInfo
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
        powerSource: .unavailable,
        updatedAt: Date()
    )
}
