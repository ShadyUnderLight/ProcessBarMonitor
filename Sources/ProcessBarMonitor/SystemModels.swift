import Foundation

enum TemperatureMode: String, CaseIterable, Identifiable {
    case hottestCPU = "Hottest CPU"
    case averageCPU = "Average CPU"
    case hottestSoC = "Hottest SoC"

    var id: String { rawValue }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case labeled = "Labeled"
    case temperatureFirst = "Temperature First"

    var id: String { rawValue }
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
        processCount > 1 ? "\(processCount) procs" : "pid \(pid)"
    }
}

struct MetricPoint: Identifiable, Hashable {
    let id = UUID()
    let value: Double
}

struct SystemSummary {
    let cpuPercent: Double
    let memoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64
    let thermalState: ProcessInfo.ThermalState
    let cpuTemperatureC: Double?
    let architectureNote: String
    let updatedAt: Date

    var memoryPressurePercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return (Double(memoryUsedBytes) / Double(memoryTotalBytes)) * 100
    }

    static let empty = SystemSummary(
        cpuPercent: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        thermalState: .nominal,
        cpuTemperatureC: nil,
        architectureNote: "",
        updatedAt: Date()
    )
}
