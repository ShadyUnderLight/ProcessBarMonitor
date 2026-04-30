import XCTest
@testable import ProcessBarMonitor

/// Tests for PowerSourceInfo and BatteryStatus parsing and formatting.
final class PowerSourceTests: XCTestCase {

    // MARK: - PowerSourceInfo.timeRemainingText

    func testTimeRemainingText_withSeconds_returnsFormatted() {
        let info = PowerSourceInfo(
            batteryPercent: 50,
            status: .discharging,
            isPluggedIn: false,
            timeRemaining: 3661, // 1h 1m 1s
            hasBattery: true
        )
        let expected = L10n.format("battery.time_remaining_format", 1, 1)
        XCTAssertEqual(info.timeRemainingText, expected)
    }

    func testTimeRemainingText_withZeroSeconds_returnsUnavailable() {
        let info = PowerSourceInfo(
            batteryPercent: 50,
            status: .discharging,
            isPluggedIn: false,
            timeRemaining: 0,
            hasBattery: true
        )
        XCTAssertEqual(info.timeRemainingText, L10n.string("battery.time_remaining_unavailable"))
    }

    func testTimeRemainingText_withNil_returnsUnavailable() {
        let info = PowerSourceInfo(
            batteryPercent: 50,
            status: .discharging,
            isPluggedIn: false,
            timeRemaining: nil,
            hasBattery: true
        )
        XCTAssertEqual(info.timeRemainingText, L10n.string("battery.time_remaining_unavailable"))
    }

    func testTimeRemainingText_fullCharge_returnsUnavailable() {
        let info = PowerSourceInfo(
            batteryPercent: 100,
            status: .full,
            isPluggedIn: true,
            timeRemaining: 0,
            hasBattery: true
        )
        XCTAssertEqual(info.timeRemainingText, L10n.string("battery.time_remaining_unavailable"))
    }

    // MARK: - PowerSourceInfo.unavailable

    func testUnavailable_hasBatteryFalse() {
        XCTAssertFalse(PowerSourceInfo.unavailable.hasBattery)
        XCTAssertEqual(PowerSourceInfo.unavailable.status, .noBattery)
    }

    // MARK: - BatteryStatus.title localization smoke test

    func testBatteryStatus_title_notEmpty() {
        XCTAssertFalse(BatteryStatus.charging.title.isEmpty)
        XCTAssertFalse(BatteryStatus.discharging.title.isEmpty)
        XCTAssertFalse(BatteryStatus.full.title.isEmpty)
        XCTAssertFalse(BatteryStatus.noBattery.title.isEmpty)
    }
}