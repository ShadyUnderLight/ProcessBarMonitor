import XCTest
@testable import ProcessBarMonitor

/// Regression tests for temperature extraction logic (issue #30).
/// Verifies the contract of the private extractTemperature method via the
/// test-only extractTemperatureTest wrapper (see TestExpose.swift).
final class TemperatureParsingTests: XCTestCase {

    private var provider: SystemMetricsProvider!

    override func setUp() {
        super.setUp()
        provider = SystemMetricsProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Valid inputs → parsed value

    func testExtractTemperature_validDecimal() {
        XCTAssertEqual(provider.extractTemperatureTest(from: "42.5"), 42.5)
    }

    func testExtractTemperature_validInteger() {
        XCTAssertEqual(provider.extractTemperatureTest(from: "85"), 85.0)
    }

    func testExtractTemperature_withUnitSuffix() {
        XCTAssertEqual(provider.extractTemperatureTest(from: "CPU: 55.3 C"), 55.3)
    }

    func testExtractTemperature_leadingWhitespace() {
        XCTAssertEqual(provider.extractTemperatureTest(from: "   67.0"), 67.0)
    }

    // MARK: - Out-of-range → nil

    func testExtractTemperature_negativeRejected() {
        XCTAssertNil(provider.extractTemperatureTest(from: "-5.2"))
    }

    func testExtractTemperature_zeroRejected() {
        XCTAssertNil(provider.extractTemperatureTest(from: "0"))
    }

    func testExtractTemperature_justBelowMinimum() {
        XCTAssertNil(provider.extractTemperatureTest(from: "0.9"))
    }

    func testExtractTemperature_justAboveMinimum() {
        // Guard is value > 1 (strictly), so 1.0 is rejected.
        XCTAssertNil(provider.extractTemperatureTest(from: "1.0"))
    }

    func testExtractTemperature_justBelowMaximum() {
        XCTAssertEqual(provider.extractTemperatureTest(from: "119.9"), 119.9)
    }

    func testExtractTemperature_justAboveMaximum() {
        XCTAssertNil(provider.extractTemperatureTest(from: "120.0"))
    }

    func testExtractTemperature_wayAboveMaximum() {
        XCTAssertNil(provider.extractTemperatureTest(from: "500"))
    }

    // MARK: - Invalid inputs → nil

    func testExtractTemperature_emptyString() {
        XCTAssertNil(provider.extractTemperatureTest(from: ""))
    }

    func testExtractTemperature_garbageOnly() {
        XCTAssertNil(provider.extractTemperatureTest(from: "no numbers here"))
    }

    // MARK: - Multiple numbers → first wins

    func testExtractTemperature_multipleNumbersFirstWins() {
        // Multiple temperature-like numbers: first is returned if valid.
        XCTAssertEqual(provider.extractTemperatureTest(from: "42.5 38.2 99.0"), 42.5)
    }

    func testExtractTemperature_firstInvalidSecondValid() {
        // First number is invalid (out of range), provider returns nil.
        XCTAssertNil(provider.extractTemperatureTest(from: "0.5 55.0"))
    }

    // MARK: - Realistic tool output samples

    func testExtractTemperature_realisticCsensorsOutput() {
        // Typical output format: just the temperature number.
        XCTAssertEqual(provider.extractTemperatureTest(from: "68.125"), 68.125)
    }

    func testExtractTemperature_realisticFloat_format() {
        XCTAssertEqual(provider.extractTemperatureTest(from: "temperature: 72.5°C"), 72.5)
    }
}
