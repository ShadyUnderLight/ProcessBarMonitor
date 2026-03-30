import Foundation
import AppKit

actor ProcessSnapshotProvider {
    enum SnapshotError: LocalizedError {
        case launchFailed(Error)
        case commandFailed(status: Int32, stderr: String)
        case invalidOutputEncoding
        case noProcessesParsed(lineCount: Int)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let error):
                return L10n.format("error.ps.launch_failed", error.localizedDescription)
            case .commandFailed(let status, let stderr):
                let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return L10n.format("error.ps.command_failed_no_stderr", status)
                }
                return L10n.format("error.ps.command_failed", status, trimmed)
            case .invalidOutputEncoding:
                return L10n.string("error.ps.invalid_utf8")
            case .noProcessesParsed(let lineCount):
                return L10n.format("error.ps.no_processes_parsed", lineCount)
            }
        }
    }

    private let psPath = "/bin/ps"
    private let psArguments = ["-axo", "pid=,comm=,%cpu=,rss="]
    private let metadataRefreshInterval: TimeInterval = 30
    private let maxMetadataLookupsPerSnapshot = 48

    private struct RawProcess {
        let pid: Int
        let command: String
        let rawCPUPercent: Double
        let memoryMB: Double
    }

    private struct AppMetadata {
        let appName: String
        let bundleIdentifier: String?
        let commandKey: String
    }

    private struct CachedMetadata {
        let metadata: AppMetadata
        let updatedAt: Date
    }

    private var metadataCache: [Int: CachedMetadata] = [:]

    func snapshot() throws -> [ProcessStat] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: psPath)
        process.arguments = psArguments

        let output = Pipe()
        let errorOutput = Pipe()
        process.standardOutput = output
        process.standardError = errorOutput

        do {
            try process.run()
        } catch {
            throw SnapshotError.launchFailed(error)
        }

        process.waitUntilExit()
        let stderrData = errorOutput.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SnapshotError.commandFailed(status: process.terminationStatus, stderr: stderr)
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8) else {
            throw SnapshotError.invalidOutputEncoding
        }
        let rawProcesses = parsePSOutput(raw)
        if rawProcesses.isEmpty {
            let lineCount = raw.split(whereSeparator: { $0.isNewline }).count
            throw SnapshotError.noProcessesParsed(lineCount: lineCount)
        }
        let prioritizedPIDs = prioritizedMetadataPIDs(from: rawProcesses)
        refreshMetadataCache(for: rawProcesses, prioritizedPIDs: prioritizedPIDs)
        pruneMetadataCache(validPIDs: Set(rawProcesses.map(\.pid)))
        return aggregate(rawProcesses)
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
                    rawCPUPercent: max(cpu, 0),
                    memoryMB: rssKB / 1024
                )
            }
    }

    private func prioritizedMetadataPIDs(from rawProcesses: [RawProcess]) -> Set<Int> {
        let topCPU = rawProcesses.sorted { $0.rawCPUPercent > $1.rawCPUPercent }.prefix(maxMetadataLookupsPerSnapshot)
        let topMemory = rawProcesses.sorted { $0.memoryMB > $1.memoryMB }.prefix(maxMetadataLookupsPerSnapshot)
        return Set(topCPU.map(\.pid)).union(topMemory.map(\.pid))
    }

    private func refreshMetadataCache(for rawProcesses: [RawProcess], prioritizedPIDs: Set<Int>) {
        let now = Date()

        for raw in rawProcesses where prioritizedPIDs.contains(raw.pid) {
            if let cached = metadataCache[raw.pid], now.timeIntervalSince(cached.updatedAt) < metadataRefreshInterval {
                continue
            }

            let metadata = resolveMetadata(for: raw)
            metadataCache[raw.pid] = CachedMetadata(metadata: metadata, updatedAt: now)
        }
    }

    private func pruneMetadataCache(validPIDs: Set<Int>) {
        metadataCache = metadataCache.filter { validPIDs.contains($0.key) }
    }

    private func resolveMetadata(for raw: RawProcess) -> AppMetadata {
        if let runningApp = NSRunningApplication(processIdentifier: pid_t(raw.pid)) {
            let appName = runningApp.localizedName ?? fallbackAppName(for: raw.command)
            return AppMetadata(
                appName: appName,
                bundleIdentifier: runningApp.bundleIdentifier,
                commandKey: raw.command
            )
        }

        return AppMetadata(
            appName: fallbackAppName(for: raw.command),
            bundleIdentifier: nil,
            commandKey: raw.command
        )
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
            let metadata = metadataCache[raw.pid]?.metadata ?? AppMetadata(
                appName: fallbackAppName(for: raw.command),
                bundleIdentifier: nil,
                commandKey: raw.command
            )
            let key = aggregateKey(for: metadata)
            let child = ProcessChildStat(pid: raw.pid, command: raw.command, cpuPercent: raw.rawCPUPercent, memoryMB: raw.memoryMB)

            if var existing = aggregates[key] {
                existing.cpuPercent += raw.rawCPUPercent
                existing.memoryMB += raw.memoryMB
                existing.processCount += 1
                existing.childProcesses.append(child)
                if existing.pid > raw.pid { existing.pid = raw.pid }
                aggregates[key] = existing
            } else {
                aggregates[key] = Aggregate(
                    pid: raw.pid,
                    command: raw.command,
                    appName: metadata.appName,
                    bundleIdentifier: metadata.bundleIdentifier,
                    cpuPercent: raw.rawCPUPercent,
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
                cpuPercent: $0.cpuPercent,
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

    private func aggregateKey(for metadata: AppMetadata) -> String {
        if let bundleIdentifier = metadata.bundleIdentifier {
            return "bundle:\(bundleIdentifier)"
        }

        return "command:\(metadata.commandKey)"
    }

    private func fallbackAppName(for command: String) -> String {
        let last = URL(fileURLWithPath: command).lastPathComponent
        return last.isEmpty ? command : last
    }
}
