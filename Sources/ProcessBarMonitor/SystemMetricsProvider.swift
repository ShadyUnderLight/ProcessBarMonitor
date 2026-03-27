import Foundation
import Darwin

final class SystemMetricsProvider {
    private var previousCPUInfo: host_cpu_load_info?
    private var cachedTemperature: Double?
    private var lastTemperatureRefresh = Date.distantPast
    private var lastTemperatureMode: TemperatureMode = .hottestCPU
    private let appleSiliconProvider = AppleSiliconTemperatureProvider()

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

        cachedTemperature = commandTemperature(
            "/bin/zsh",
            ["-lc", "if command -v istats >/dev/null 2>&1; then istats cpu temp --value-only; elif command -v osx-cpu-temp >/dev/null 2>&1; then osx-cpu-temp; else exit 1; fi"]
        )
        return cachedTemperature
    }

    private func commandTemperature(_ launchPath: String, _ arguments: [String]) -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
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
            return "Temperature mode: \(mode.rawValue). Source: Apple Silicon HID sensors first, helper fallback second."
        }
        #if arch(arm64)
        return "Apple Silicon HID sensors were checked for \(mode.rawValue), but no valid value was exposed right now."
        #elseif arch(x86_64)
        return "Intel: install osx-cpu-temp or istats to show a real CPU temperature."
        #else
        return "No valid CPU temperature source found."
        #endif
    }
}
