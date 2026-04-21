import XCTest
@testable import ProcessBarMonitor

/// Regression tests for legacy settings migration via savedValue initialisers
/// on TemperatureMode and MenuBarDisplayMode (issue #30).
///
/// These initialisers bridge old display-name strings (e.g. "Hottest CPU")
/// stored in UserDefaults with the new rawValue strings (e.g. "hottestCPU"),
/// ensuring users' existing preferences are preserved after UI rename.
///
final class EnumSavedValueTests: XCTestCase {

    // MARK: - TemperatureMode — modern rawValue strings

    func testTemperatureMode_modernHottestCPU() {
        XCTAssertEqual(TemperatureMode(savedValue: "hottestCPU"), .hottestCPU)
    }

    func testTemperatureMode_modernAverageCPU() {
        XCTAssertEqual(TemperatureMode(savedValue: "averageCPU"), .averageCPU)
    }

    func testTemperatureMode_modernHottestSoC() {
        XCTAssertEqual(TemperatureMode(savedValue: "hottestSoC"), .hottestSoC)
    }

    // MARK: - TemperatureMode — legacy display-name strings

    func testTemperatureMode_legacyHottestCPU() {
        XCTAssertEqual(TemperatureMode(savedValue: "Hottest CPU"), .hottestCPU)
    }

    func testTemperatureMode_legacyAverageCPU() {
        XCTAssertEqual(TemperatureMode(savedValue: "Average CPU"), .averageCPU)
    }

    func testTemperatureMode_legacyHottestSoC() {
        XCTAssertEqual(TemperatureMode(savedValue: "Hottest SoC"), .hottestSoC)
    }

    // MARK: - TemperatureMode — invalid / unknown strings

    func testTemperatureMode_invalidString() {
        XCTAssertNil(TemperatureMode(savedValue: "not a mode"))
    }

    func testTemperatureMode_emptyString() {
        XCTAssertNil(TemperatureMode(savedValue: ""))
    }

    func testTemperatureMode_caseSensitive() {
        // Modern rawValue is lowercase-first camel.
        XCTAssertNil(TemperatureMode(savedValue: "HottestCPU"))
        XCTAssertNil(TemperatureMode(savedValue: "HOTTESTCPU"))
    }

    // MARK: - MenuBarDisplayMode — modern rawValue strings

    func testMenuBarDisplayMode_modernCompact() {
        XCTAssertEqual(MenuBarDisplayMode(savedValue: "compact"), .compact)
    }

    func testMenuBarDisplayMode_modernLabeled() {
        XCTAssertEqual(MenuBarDisplayMode(savedValue: "labeled"), .labeled)
    }

    func testMenuBarDisplayMode_modernTemperatureFirst() {
        XCTAssertEqual(MenuBarDisplayMode(savedValue: "temperatureFirst"), .temperatureFirst)
    }

    // MARK: - MenuBarDisplayMode — legacy display-name strings

    func testMenuBarDisplayMode_legacyCompact() {
        XCTAssertEqual(MenuBarDisplayMode(savedValue: "Compact"), .compact)
    }

    func testMenuBarDisplayMode_legacyLabeled() {
        XCTAssertEqual(MenuBarDisplayMode(savedValue: "Labeled"), .labeled)
    }

    func testMenuBarDisplayMode_legacyTemperatureFirst() {
        XCTAssertEqual(MenuBarDisplayMode(savedValue: "Temperature First"), .temperatureFirst)
    }

    // MARK: - MenuBarDisplayMode — invalid / unknown strings

    func testMenuBarDisplayMode_invalidString() {
        XCTAssertNil(MenuBarDisplayMode(savedValue: "foobar"))
    }

    func testMenuBarDisplayMode_emptyString() {
        XCTAssertNil(MenuBarDisplayMode(savedValue: ""))
    }

    func testMenuBarDisplayMode_caseSensitive() {
        XCTAssertNil(MenuBarDisplayMode(savedValue: "compact "))
        XCTAssertNil(MenuBarDisplayMode(savedValue: "COMPACT"))
    }
}
