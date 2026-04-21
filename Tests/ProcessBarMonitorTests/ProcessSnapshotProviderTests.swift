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
}
