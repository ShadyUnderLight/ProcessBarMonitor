import Foundation
import Darwin

actor SystemMetricsProvider {
    private var previousCPUInfo: host_cpu_load_info?
    private var cachedTemperature: Double?
    private var lastTemperatureRefresh = Date.distantPast
    private var lastTemperatureMode: TemperatureMode = .hottestCPU
    private let appleSiliconProvider = AppleSiliconTemperatureProvider()
    /// Caches the confirmed temperature tool state to avoid repeated shell detection.
    private var temperatureToolState: TemperatureToolState = .unchecked

    /// 3-state cache for temperature command resolution.
    /// - unchecked: initial state, needs detection
    /// - unavailable: both tools confirmed missing, skip detection
    /// - resolved: tool found, store its kind and the resolved executable path
    private enum TemperatureToolState {
        case unchecked
        case unavailable
        case resolved(kind: TemperatureToolKind, path: String)
    }

    /// Supported temperature measurement tools.
    private enum TemperatureToolKind {
        case istats
        case osxCpuTemp
    }

    func snapshot(temperatureMode: TemperatureMode) -> SystemSummary {
        let temperature = bestEffortCPUTemperature(mode: temperatureMode)

        return SystemSummary(
            cpuPercent: cpuUsagePercent(),
            memoryUsedBytes: currentUsedMemory(),
            memoryTotalBytes: ProcessInfo.processInfo.physicalMemory,
            thermalState: ProcessInfo.processInfo.thermalState,
            cpuTemperatureC: temperature,
            architectureNote: architectureAndTemperatureNote(temperatureAvailable: temperature != nil, mode: temperatureMode),
            updatedAt: Date()
        )
    }

    private func currentUsedMemory() -> UInt64 {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        var pageSize: vm_size_t = 0
        host_page_size(hostPort, &pageSize)
        let usedPages = UInt64(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count + vmStats.compressor_page_count)
        return usedPages * UInt64(pageSize)
    }

    private func cpuUsagePercent() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        guard let previous = previousCPUInfo else {
            previousCPUInfo = cpuInfo
            return 0
        }

        let user = Double(cpuInfo.cpu_ticks.0 - previous.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1 - previous.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2 - previous.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3 - previous.cpu_ticks.3)
        previousCPUInfo = cpuInfo

        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return ((user + system + nice) / total) * 100
    }

    private func bestEffortCPUTemperature(mode: TemperatureMode) -> Double? {
        let now = Date()
        if mode == lastTemperatureMode, now.timeIntervalSince(lastTemperatureRefresh) < 5 {
            return cachedTemperature
        }

        lastTemperatureRefresh = now
        lastTemperatureMode = mode

        if let appleTemp = appleSiliconProvider.temperature(mode: mode) {
            cachedTemperature = appleTemp
            return appleTemp
        }

        // Skip detection entirely if both tools were previously confirmed unavailable
        if case .unchecked = temperatureToolState {
            temperatureToolState = resolveTemperatureTool()
        }

        switch temperatureToolState {
        case .unavailable:
            cachedTemperature = nil
        case .resolved(let kind, let path):
            cachedTemperature = runTemperatureCommand(kind: kind, path: path)
        case .unchecked:
            cachedTemperature = nil
        }
        return cachedTemperature
    }

    /// Detects which temperature tool is available and caches the resolved executable path.
    /// Called at most once per app run when cache is cold.
    private func resolveTemperatureTool() -> TemperatureToolState {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", """
            if command -v istats >/dev/null 2>&1; then
                echo "istats:$(command -v istats)"
            elif command -v osx-cpu-temp >/dev/null 2>&1; then
                echo "osx-cpu-temp:$(command -v osx-cpu-temp)"
            else
                echo "none"
            fi
            """]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do { try process.run() } catch { return .unavailable }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return .unavailable }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return .unavailable }

        if raw.hasPrefix("istats:") {
            let path = String(raw.dropFirst(7))
            return .resolved(kind: .istats, path: path)
        } else if raw.hasPrefix("osx-cpu-temp:") {
            let path = String(raw.dropFirst(13))
            return .resolved(kind: .osxCpuTemp, path: path)
        }
        return .unavailable
    }

    private func runTemperatureCommand(kind: TemperatureToolKind, path: String) -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        switch kind {
        case .istats:
            process.arguments = ["cpu", "temp", "--value-only"]
        case .osxCpuTemp:
            process.arguments = []
        }
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        return extractTemperature(from: raw)
    }

    private func extractTemperature(from raw: String) -> Double? {
        let matches = raw.matches(of: /-?\d+(?:\.\d+)?/)
        guard let first = matches.first,
              let value = Double(first.output), value > 1, value < 120 else { return nil }
        return value
    }

    private func architectureAndTemperatureNote(temperatureAvailable: Bool, mode: TemperatureMode) -> String {
        if temperatureAvailable {
            return L10n.format("note.temperature.available", mode.title)
        }
        #if arch(arm64)
        return L10n.format("note.temperature.arm64_unavailable", mode.title)
        #elseif arch(x86_64)
        return L10n.string("note.temperature.intel_hint")
        #else
        return L10n.string("note.temperature.no_source")
        #endif
    }
}
