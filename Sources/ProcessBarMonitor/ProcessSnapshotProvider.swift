import Foundation
import AppKit

final class ProcessSnapshotProvider {
    private let shellPath = "/bin/zsh"
    private let psCommand = "/bin/ps -axo pid=,comm=,%cpu=,rss="
    private let processorCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)

    private struct RawProcess {
        let pid: Int
        let command: String
        let rawCPUPercent: Double
        let memoryMB: Double
    }

    func snapshot() -> [ProcessStat] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-lc", psCommand]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8) else { return [] }
        return aggregate(parsePSOutput(raw))
    }

    private func parsePSOutput(_ raw: String) -> [RawProcess] {
        raw
            .split(whereSeparator: { $0.isNewline })
            .compactMap { line -> RawProcess? in
                let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                guard parts.count == 4,
                      let pid = Int(parts[0]),
                      let cpu = Double(parts[2]),
                      let rssKB = Double(parts[3]) else {
                    return nil
                }

                return RawProcess(
                    pid: pid,
                    command: String(parts[1]),
                    rawCPUPercent: cpu,
                    memoryMB: rssKB / 1024
                )
            }
    }

    private func aggregate(_ rawProcesses: [RawProcess]) -> [ProcessStat] {
        struct Aggregate {
            var pid: Int
            var command: String
            var appName: String
            var bundleIdentifier: String?
            var cpuPercent: Double
            var memoryMB: Double
            var processCount: Int
            var childProcesses: [ProcessChildStat]
        }

        var aggregates: [String: Aggregate] = [:]

        for raw in rawProcesses {
            let runningApp = NSRunningApplication(processIdentifier: pid_t(raw.pid))
            let bundleIdentifier = runningApp?.bundleIdentifier
            let appName = runningApp?.localizedName ?? fallbackAppName(for: raw.command)
            let key = bundleIdentifier ?? appName
            let normalizedCPU = min(max(raw.rawCPUPercent / Double(processorCount), 0), 100)
            let child = ProcessChildStat(pid: raw.pid, command: raw.command, cpuPercent: normalizedCPU, memoryMB: raw.memoryMB)

            if var existing = aggregates[key] {
                existing.cpuPercent += normalizedCPU
                existing.memoryMB += raw.memoryMB
                existing.processCount += 1
                existing.childProcesses.append(child)
                if existing.pid > raw.pid { existing.pid = raw.pid }
                aggregates[key] = existing
            } else {
                aggregates[key] = Aggregate(
                    pid: raw.pid,
                    command: raw.command,
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    cpuPercent: normalizedCPU,
                    memoryMB: raw.memoryMB,
                    processCount: 1,
                    childProcesses: [child]
                )
            }
        }

        return aggregates.values.map {
            ProcessStat(
                pid: $0.pid,
                command: $0.command,
                appName: $0.appName,
                bundleIdentifier: $0.bundleIdentifier,
                cpuPercent: min($0.cpuPercent, 100),
                memoryMB: $0.memoryMB,
                processCount: $0.processCount,
                childProcesses: $0.childProcesses.sorted {
                    if $0.cpuPercent == $1.cpuPercent {
                        return $0.memoryMB > $1.memoryMB
                    }
                    return $0.cpuPercent > $1.cpuPercent
                }
            )
        }
    }

    private func fallbackAppName(for command: String) -> String {
        let last = URL(fileURLWithPath: command).lastPathComponent
        return last.isEmpty ? command : last
    }
}
