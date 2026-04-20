import Foundation
import AppKit

actor ProcessSnapshotProvider {
    static let shared = ProcessSnapshotProvider()

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

    struct AppMetadata: Sendable {
        let appName: String
        let bundleIdentifier: String?
        let commandKey: String
    }

    private let psPath = "/bin/ps"
    private let psArguments = ["-axo", "pid=,comm=,%cpu=,rss="]
    private let metadataRefreshInterval: TimeInterval = 30
    private let maxMetadataLookupsPerSnapshot = 48
    private let maxConcurrentMetadataLookups = 8

    private struct RawProcess: Sendable {
        let pid: Int
        let command: String
        let rawCPUPercent: Double
        let memoryMB: Double
    }

    private struct CachedMetadata: Sendable {
        let metadata: AppMetadata
        let updatedAt: Date
    }

    private var metadataCache: [Int: CachedMetadata] = [:]

    func snapshot() async throws -> [ProcessStat] {
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

        // Resolve metadata off the main thread with bounded concurrency
        let now = Date()
        let resolved = await resolveMetadataBatch(
            rawProcesses: rawProcesses,
            prioritizedPIDs: prioritizedPIDs,
            now: now,
            maxConcurrent: maxConcurrentMetadataLookups
        )

        for (pid, metadata) in resolved {
            metadataCache[pid] = CachedMetadata(metadata: metadata, updatedAt: now)
        }

        pruneMetadataCache(validPIDs: Set(rawProcesses.map(\.pid)))
        return aggregate(rawProcesses)
    }

    /// Resolves metadata for prioritized PIDs in parallel via TaskGroup with bounded concurrency.
    /// Each resolution runs in a detached task, off the actor's thread.
    private func resolveMetadataBatch(
        rawProcesses: [RawProcess],
        prioritizedPIDs: Set<Int>,
        now: Date,
        maxConcurrent: Int
    ) async -> [Int: AppMetadata] {
        let needsRefresh = rawProcesses.filter { prioritizedPIDs.contains($0.pid) && !isCacheValid(pid: $0.pid, now: now) }

        guard !needsRefresh.isEmpty else { return [:] }

        var results: [Int: AppMetadata] = [:]
        let throttle = Throttle(maxActive: maxConcurrent)

        await withTaskGroup(of: (Int, AppMetadata?).self) { group in
            for raw in needsRefresh {
                group.addTask {
                    await throttle.enter()
                    let metadata = Self.resolveMetadataSync(pid: raw.pid, command: raw.command)
                    await throttle.exit()
                    return (raw.pid, metadata)
                }
            }

            for await (pid, metadata) in group {
                if let metadata {
                    results[pid] = metadata
                }
            }
        }

        return results
    }

    private func isCacheValid(pid: Int, now: Date) -> Bool {
        if let cached = metadataCache[pid] {
            return now.timeIntervalSince(cached.updatedAt) < metadataRefreshInterval
        }
        return false
    }

    /// Performs NSRunningApplication lookup off the main thread via Task.detached.
    /// Called from background tasks spawned by the TaskGroup in resolveMetadataBatch.
    private static func resolveMetadataSync(pid: Int, command: String) -> AppMetadata {
        if let runningApp = NSRunningApplication(processIdentifier: pid_t(pid)) {
            let appName = runningApp.localizedName ?? fallbackAppName(for: command)
            return AppMetadata(
                appName: appName,
                bundleIdentifier: runningApp.bundleIdentifier,
                commandKey: command
            )
        }

        return AppMetadata(
            appName: fallbackAppName(for: command),
            bundleIdentifier: nil,
            commandKey: command
        )
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

    private func pruneMetadataCache(validPIDs: Set<Int>) {
        metadataCache = metadataCache.filter { validPIDs.contains($0.key) }
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
                appName: Self.fallbackAppName(for: raw.command),
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

    private static func fallbackAppName(for command: String) -> String {
        let last = URL(fileURLWithPath: command).lastPathComponent
        return last.isEmpty ? command : last
    }
}

/// Actor-based throttle limiting concurrent background operations.
actor Throttle {
    private let maxActive: Int
    private var activeCount = 0
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    init(maxActive: Int) {
        self.maxActive = maxActive
    }

    func enter() async {
        if activeCount < maxActive {
            activeCount += 1
        } else {
            await withCheckedContinuation { continuation in
                waitQueue.append(continuation)
            }
        }
    }

    func exit() {
        if !waitQueue.isEmpty {
            let cont = waitQueue.removeFirst()
            cont.resume()
        } else {
            activeCount -= 1
        }
    }
}