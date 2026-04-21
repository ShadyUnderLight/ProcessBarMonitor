import XCTest
@testable import ProcessBarMonitor

/// Regression tests for ps output parsing (issue #29).
/// The fix uses regex to reliably extract pid/cpu/rss regardless of spaces in the command field.
final class ProcessSnapshotProviderTests: XCTestCase {

    // MARK: - parsePSOutput Regression Tests

    /// Normal ps output: pid, cpu, rss separated by spaces.
    func testParsePSOutput_normal() async throws {
        let raw = """
        1  0.2  14288
        323  0.8  13920
        325  0.0  4032
        """

        let provider = ProcessSnapshotProvider.shared
        let results = await provider.parsePSOutput(raw)

        XCTAssertEqual(results.count, 3)

        XCTAssertEqual(results[0].pid, 1)
        XCTAssertEqual(results[0].rawCPUPercent, 0.2)
        XCTAssertEqual(results[0].memoryMB, 14288.0 / 1024, accuracy: 0.001)

        XCTAssertEqual(results[1].pid, 323)
        XCTAssertEqual(results[1].rawCPUPercent, 0.8)
        XCTAssertEqual(results[1].memoryMB, 13920.0 / 1024, accuracy: 0.001)

        XCTAssertEqual(results[2].pid, 325)
        XCTAssertEqual(results[2].rawCPUPercent, 0.0)
        XCTAssertEqual(results[2].memoryMB, 4032.0 / 1024, accuracy: 0.001)
    }

    /// Extra whitespace between fields must not break parsing.
    func testParsePSOutput_extraWhitespace() async throws {
        let raw = """
           1    0.2    14288
        323    0.8    13920
        """

        let provider = ProcessSnapshotProvider.shared
        let results = await provider.parsePSOutput(raw)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].pid, 1)
        XCTAssertEqual(results[1].pid, 323)
    }

    /// Lines with invalid numeric fields must be skipped and not affect valid lines.
    func testParsePSOutput_invalidLinesSkipped() async throws {
        let raw = """
        1  0.2  14288
        not-a-pid  0.5  5000
        323  0.8  13920
        456  NaN  9999
        789  1.0  abc
        999  2.0  12345
        """

        let provider = ProcessSnapshotProvider.shared
        let results = await provider.parsePSOutput(raw)

        // Only the two valid lines should be returned
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].pid, 1)
        XCTAssertEqual(results[1].pid, 323)
        XCTAssertEqual(results[2].pid, 999)
    }

    /// All invalid lines → no crash, empty result.
    func testParsePSOutput_allInvalid() async throws {
        let raw = """
        invalid line here
        another bad line
        """

        let provider = ProcessSnapshotProvider.shared
        let results = await provider.parsePSOutput(raw)

        XCTAssertEqual(results.count, 0)
    }

    /// Negative CPU values must be normalised to 0.
    func testParsePSOutput_negativeCPUNormalised() async throws {
        let raw = """
        1  -0.5  14288
        2  0.0  5000
        """

        let provider = ProcessSnapshotProvider.shared
        let results = await provider.parsePSOutput(raw)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].rawCPUPercent, 0.0) // negative → 0
        XCTAssertEqual(results[1].rawCPUPercent, 0.0)
    }

    /// Large whitespace between fields (tab-like spacing from ps output variations).
    func testParsePSOutput_variableSpacing() async throws {
        let raw = "100\t\t0.1\t\t20000\n200\t\t1.2\t\t40000\n"

        let provider = ProcessSnapshotProvider.shared
        let results = await provider.parsePSOutput(raw)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].pid, 100)
        XCTAssertEqual(results[0].rawCPUPercent, 0.1)
        XCTAssertEqual(results[0].memoryMB, 20000.0 / 1024, accuracy: 0.001)
        XCTAssertEqual(results[1].pid, 200)
        XCTAssertEqual(results[1].rawCPUPercent, 1.2)
        XCTAssertEqual(results[1].memoryMB, 40000.0 / 1024, accuracy: 0.001)
    }

    // MARK: - Aggregation Regression Tests (issue #29)

    /// Multiple non-prioritized processes with nil command and no cached metadata
    /// must NOT collapse into the same empty-key aggregate.
    /// Each must receive a distinct grouping key via the pid-based fallback.
    func testAggregate_noCommandNoCache_oneProcessPerBucket() async throws {
        // Simulate three unrelated processes with no command resolved and no cache entry.
        // Each must get a unique aggregate key — none should collide.
        let p1 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 100, command: nil, cachedMetadata: nil)
        let p2 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 200, command: nil, cachedMetadata: nil)
        let p3 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 300, command: nil, cachedMetadata: nil)

        XCTAssertNotEqual(p1, p2)
        XCTAssertNotEqual(p2, p3)
        XCTAssertNotEqual(p1, p3)

        // Each key must contain the pid so it's stable and unique per process
        XCTAssertEqual(p1, "command:pid:100")
        XCTAssertEqual(p2, "command:pid:200")
        XCTAssertEqual(p3, "command:pid:300")
    }

    /// A prioritized PID whose fetchCommand fails and has no cache entry
    /// must not be grouped with unrelated nil-command processes.
    func testAggregate_prioritizedPIDCommandFetchFails_noCollisionWithOtherProcesses() async throws {
        // Two different PIDs, both with nil command and nil cache.
        // The original bug would give both the same "" key — fixed by pid-based fallback.
        let keyPID1 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 1, command: nil, cachedMetadata: nil)
        let keyPID2 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 2, command: nil, cachedMetadata: nil)

        XCTAssertNotEqual(keyPID1, keyPID2,
            "Two unrelated processes with unavailable command must not share an aggregate key")

        // Ensure the key does NOT look like the old buggy empty-string fallback
        XCTAssertFalse(keyPID1 == "command:" || keyPID1.isEmpty,
            "Aggregate key must never be the empty string")
        XCTAssertFalse(keyPID2 == "command:" || keyPID2.isEmpty,
            "Aggregate key must never be the empty string")
    }

    /// Processes whose command is successfully resolved must still group correctly
    /// by their resolved command key (not pid-based fallback).
    func testAggregate_resolvedCommand_oneAggregatePerCommand() async throws {
        // Two PIDs with the same resolved command → same aggregate (same app, different threads/processes)
        let keyA = ProcessSnapshotProvider.aggregateKeyForTest(
            pid: 999,
            command: "/usr/libexec/cups/scheduler",
            cachedMetadata: nil
        )
        let keyB = ProcessSnapshotProvider.aggregateKeyForTest(
            pid: 888,
            command: "/usr/libexec/cups/scheduler",
            cachedMetadata: nil
        )

        XCTAssertEqual(keyA, keyB, "Same resolved command → same aggregate key")

        // And they must differ from a third distinct process
        let keyC = ProcessSnapshotProvider.aggregateKeyForTest(
            pid: 777,
            command: "/usr/sbin/syslogd",
            cachedMetadata: nil
        )
        XCTAssertNotEqual(keyA, keyC)
    }

    /// Parsing with spaces in command paths: the two-phase approach resolves
    /// commands via `ps -p <pid> -o comm=` which uses comm= (no spaces).
    /// This test verifies the command fallback chain produces correct distinct keys
    /// when the same "spaced path" process appears multiple times.
    func testAggregate_spacedCommandPath_resolvedCorrectly() async throws {
        let spacedCommand = "/Application Utilities/Some App.app/Contents/MacOS/Helper Tool"

        let key1 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 1, command: spacedCommand, cachedMetadata: nil)
        let key2 = ProcessSnapshotProvider.aggregateKeyForTest(pid: 2, command: spacedCommand, cachedMetadata: nil)

        // Same command string → same aggregate (they are the same app)
        XCTAssertEqual(key1, key2)
        XCTAssertFalse(key1.hasPrefix("command:pid:"),
            "A resolved command should NOT fall back to pid-based key")

        // Distinct command → distinct key
        let keyOther = ProcessSnapshotProvider.aggregateKeyForTest(
            pid: 3,
            command: "/Another App/script with spaces",
            cachedMetadata: nil
        )
        XCTAssertNotEqual(key1, keyOther)
    }
}
