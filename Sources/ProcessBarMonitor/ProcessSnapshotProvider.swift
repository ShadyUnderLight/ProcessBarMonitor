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
    private let psArguments = ["-axo", "pid=,%cpu=,rss="]
    private let metadataRefreshInterval: TimeInterval = 30
    private let maxMetadataLookupsPerSnapshot = 48
    private let maxConcurrentMetadataLookups = 8

    struct RawProcess: Sendable {
        let pid: Int
        let command: String?
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

        // Phase 2: fetch command names for top PIDs (avoids the space-in-comm parsing problem)
        let topPIDs = Array(prioritizedPIDs)
        let fetchedCommands = await fetchCommands(for: topPIDs)

        // Fill commands back into rawProcesses so aggregate() / metadata have them
        var rawProcessesWithCommand = rawProcesses
        for i in rawProcessesWithCommand.indices {
            if let cmd = fetchedCommands[rawProcessesWithCommand[i].pid] {
                rawProcessesWithCommand[i] = RawProcess(
                    pid: rawProcessesWithCommand[i].pid,
                    command: cmd,
                    rawCPUPercent: rawProcessesWithCommand[i].rawCPUPercent,
                    memoryMB: rawProcessesWithCommand[i].memoryMB
                )
            }
        }

        // Resolve metadata off the main thread with bounded concurrency
        let now = Date()
        let resolved = await resolveMetadataBatch(
            rawProcesses: rawProcessesWithCommand,
            prioritizedPIDs: prioritizedPIDs,
            now: now,
            maxConcurrent: maxConcurrentMetadataLookups
        )

        for (pid, metadata) in resolved {
            metadataCache[pid] = CachedMetadata(metadata: metadata, updatedAt: now)
        }

        pruneMetadataCache(validPIDs: Set(rawProcessesWithCommand.map(\.pid)))
        return aggregate(rawProcessesWithCommand)
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
    private static func resolveMetadataSync(pid: Int, command: String?) -> AppMetadata {
        let cmd = command ?? ""
        if let runningApp = NSRunningApplication(processIdentifier: pid_t(pid)) {
            let appName = runningApp.localizedName ?? fallbackAppName(for: cmd)
            return AppMetadata(
                appName: appName,
                bundleIdentifier: runningApp.bundleIdentifier,
                commandKey: cmd
            )
        }

        return AppMetadata(
            appName: fallbackAppName(for: cmd),
            bundleIdentifier: nil,
            commandKey: cmd
        )
    }

    // Regex: pid (digits), cpu (float, may be negative), rss (digits) — reliable, no spaces in these fields
    private nonisolated static let psStatRegex = try! NSRegularExpression(
        pattern: #"^\s*(\d+)\s+(-?[\d.]+)\s+(\d+)"#,
        options: []
    )

    nonisolated func parsePSOutput(_ raw: String) -> [RawProcess] {
        raw
            .split(whereSeparator: { $0.isNewline })
            .compactMap { line -> RawProcess? in
                let lineStr = String(line)
                let range = NSRange(lineStr.startIndex..., in: lineStr)
                guard let match = Self.psStatRegex.firstMatch(in: lineStr, options: [], range: range),
                      let pidRange = Range(match.range(at: 1), in: lineStr),
                      let cpuRange = Range(match.range(at: 2), in: lineStr),
                      let rssRange = Range(match.range(at: 3), in: lineStr),
                      let pid = Int(lineStr[pidRange]),
                      let cpu = Double(lineStr[cpuRange]),
                      let rssKB = Double(lineStr[rssRange]) else {
                    return nil
                }

                return RawProcess(
                    pid: pid,
                    command: nil,
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
            // Fallback chain: fetched comm → cached commandKey → pid-based key.
            // The pid-based key prevents unrelated processes from collapsing into
            // the same empty-string aggregate when neither phase 2 fetch nor cache hit.
            let command = raw.command ?? metadataCache[raw.pid]?.metadata.commandKey ?? "pid:\(raw.pid)"
            let metadata = metadataCache[raw.pid]?.metadata ?? AppMetadata(
                appName: Self.fallbackAppName(for: command),
                bundleIdentifier: nil,
                commandKey: command
            )
            let key = aggregateKey(for: metadata)
            let child = ProcessChildStat(pid: raw.pid, command: command, cpuPercent: raw.rawCPUPercent, memoryMB: raw.memoryMB)

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
                    command: command,
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

    // MARK: - Test helpers (nonisolated, safe to call from tests)

    /// Test-only: simulates the command fallback chain without needing actor state.
    /// - Parameters mirror what `aggregate()` sees per RawProcess entry.
    static func aggregateKeyForTest(pid: Int, command: String?, cachedMetadata: AppMetadata?) -> String {
        let resolvedCommand = command ?? cachedMetadata?.commandKey ?? "pid:\(pid)"
        let metadata = cachedMetadata ?? AppMetadata(
            appName: fallbackAppName(for: resolvedCommand),
            bundleIdentifier: nil,
            commandKey: resolvedCommand
        )
        // Replicate aggregateKey logic
        if let bundleIdentifier = metadata.bundleIdentifier {
            return "bundle:\(bundleIdentifier)"
        }
        return "command:\(metadata.commandKey)"
    }

    /// Fetches the executable name for a single PID via `ps -p <pid> -o comm=`.
    /// Uses the basename-safe `comm=` format which avoids spaces in the path issue.
    private static func fetchCommand(for pid: Int) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "comm="]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        return raw
    }

    /// Fetches commands for a batch of PIDs concurrently.
    private func fetchCommands(for pids: [Int]) async -> [Int: String] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for pid in pids {
                group.addTask {
                    (pid, Self.fetchCommand(for: pid))
                }
            }

            var results: [Int: String] = [:]
            for await (pid, command) in group {
                if let command {
                    results[pid] = command
                }
            }
            return results
        }
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