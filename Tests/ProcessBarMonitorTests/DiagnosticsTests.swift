import XCTest
@testable import ProcessBarMonitor

/// Regression tests for ProcessSnapshotDiagnostics state machine (issue #30).
/// Verifies that each mutating method produces the expected side-effects
/// without interfering with other fields.
final class DiagnosticsTests: XCTestCase {

    private var diagnostics: ProcessSnapshotDiagnostics!
    private let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)

    override func setUp() {
        super.setUp()
        diagnostics = ProcessSnapshotDiagnostics()
    }

    override func tearDown() {
        diagnostics = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialState_allCountersZero() {
        XCTAssertEqual(diagnostics.attemptCount, 0)
        XCTAssertEqual(diagnostics.successCount, 0)
        XCTAssertEqual(diagnostics.failureCount, 0)
    }

    func testInitialState_allDatesNil() {
        XCTAssertNil(diagnostics.lastAttemptAt)
        XCTAssertNil(diagnostics.lastSuccessAt)
        XCTAssertNil(diagnostics.lastFailureAt)
    }

    func testInitialState_noErrorMessage() {
        XCTAssertNil(diagnostics.lastFailureMessage)
        XCTAssertNil(diagnostics.lastFailureDetails)
    }

    func testInitialState_zeroProcessCounts() {
        XCTAssertEqual(diagnostics.lastSnapshotProcessCount, 0)
        XCTAssertEqual(diagnostics.lastTopCPUCount, 0)
        XCTAssertEqual(diagnostics.lastTopMemoryCount, 0)
    }

    // MARK: - markAttempt

    func testMarkAttempt_incrementsAttemptCount() {
        diagnostics.markAttempt(at: fixedDate)
        XCTAssertEqual(diagnostics.attemptCount, 1)
        XCTAssertEqual(diagnostics.lastAttemptAt, fixedDate)
    }

    func testMarkAttempt_multipleCallsAccumulate() {
        let d1 = Date(timeIntervalSince1970: 1)
        let d2 = Date(timeIntervalSince1970: 2)
        let d3 = Date(timeIntervalSince1970: 3)
        diagnostics.markAttempt(at: d1)
        diagnostics.markAttempt(at: d2)
        diagnostics.markAttempt(at: d3)
        XCTAssertEqual(diagnostics.attemptCount, 3)
        XCTAssertEqual(diagnostics.lastAttemptAt, d3)
    }

    func testMarkAttempt_doesNotAffectSuccessFailureCounts() {
        diagnostics.markAttempt(at: fixedDate)
        XCTAssertEqual(diagnostics.successCount, 0)
        XCTAssertEqual(diagnostics.failureCount, 0)
    }

    // MARK: - markSuccess

    func testMarkSuccess_incrementsSuccessCount() {
        diagnostics.markSuccess(processCount: 42, topCPUCount: 5, topMemoryCount: 5, at: fixedDate)
        XCTAssertEqual(diagnostics.successCount, 1)
    }

    func testMarkSuccess_setsLastSuccessAt() {
        diagnostics.markSuccess(processCount: 42, topCPUCount: 5, topMemoryCount: 5, at: fixedDate)
        XCTAssertEqual(diagnostics.lastSuccessAt, fixedDate)
    }

    func testMarkSuccess_capturesProcessCounts() {
        diagnostics.markSuccess(processCount: 42, topCPUCount: 8, topMemoryCount: 12, at: fixedDate)
        XCTAssertEqual(diagnostics.lastSnapshotProcessCount, 42)
        XCTAssertEqual(diagnostics.lastTopCPUCount, 8)
        XCTAssertEqual(diagnostics.lastTopMemoryCount, 12)
    }

    func testMarkSuccess_doesNotAffectAttemptOrFailureCount() {
        diagnostics.markSuccess(processCount: 1, topCPUCount: 1, topMemoryCount: 1, at: fixedDate)
        XCTAssertEqual(diagnostics.attemptCount, 0)
        XCTAssertEqual(diagnostics.failureCount, 0)
    }

    // MARK: - markFailure

    func testMarkFailure_incrementsFailureCount() {
        diagnostics.markFailure(message: "ps exited 1", details: "signal 9", at: fixedDate)
        XCTAssertEqual(diagnostics.failureCount, 1)
    }

    func testMarkFailure_setsLastFailureAt() {
        diagnostics.markFailure(message: "ps exited 1", details: "signal 9", at: fixedDate)
        XCTAssertEqual(diagnostics.lastFailureAt, fixedDate)
    }

    func testMarkFailure_capturesMessageAndDetails() {
        diagnostics.markFailure(message: "access denied", details: "PermissionError", at: fixedDate)
        XCTAssertEqual(diagnostics.lastFailureMessage, "access denied")
        XCTAssertEqual(diagnostics.lastFailureDetails, "PermissionError")
    }

    func testMarkFailure_doesNotAffectAttemptOrSuccessCount() {
        diagnostics.markFailure(message: "err", details: "detail", at: fixedDate)
        XCTAssertEqual(diagnostics.attemptCount, 0)
        XCTAssertEqual(diagnostics.successCount, 0)
    }

    // MARK: - Full lifecycle

    func testFullLifecycle_attemptThenSuccess() {
        let d1 = Date(timeIntervalSince1970: 10)
        let d2 = Date(timeIntervalSince1970: 20)
        diagnostics.markAttempt(at: d1)
        diagnostics.markSuccess(processCount: 10, topCPUCount: 5, topMemoryCount: 5, at: d2)

        XCTAssertEqual(diagnostics.attemptCount, 1)
        XCTAssertEqual(diagnostics.successCount, 1)
        XCTAssertEqual(diagnostics.failureCount, 0)
        XCTAssertEqual(diagnostics.lastAttemptAt, d1)
        XCTAssertEqual(diagnostics.lastSuccessAt, d2)
    }

    func testFullLifecycle_attemptThenFailure() {
        let d1 = Date(timeIntervalSince1970: 10)
        let d2 = Date(timeIntervalSince1970: 20)
        diagnostics.markAttempt(at: d1)
        diagnostics.markFailure(message: "err", details: "det", at: d2)

        XCTAssertEqual(diagnostics.attemptCount, 1)
        XCTAssertEqual(diagnostics.successCount, 0)
        XCTAssertEqual(diagnostics.failureCount, 1)
        XCTAssertEqual(diagnostics.lastAttemptAt, d1)
        XCTAssertEqual(diagnostics.lastFailureAt, d2)
        XCTAssertEqual(diagnostics.lastFailureMessage, "err")
    }
}
