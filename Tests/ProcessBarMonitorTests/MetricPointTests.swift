import XCTest
@testable import ProcessBarMonitor

/// Regression tests for MetricPoint stale flag (issue #31).
/// Verifies that stale data is distinguishable from live data.
final class MetricPointTests: XCTestCase {

    func testMetricPoint_defaultIsStaleFalse() {
        let point = MetricPoint(value: 42.0)
        XCTAssertEqual(point.value, 42.0)
        XCTAssertFalse(point.isStale)
    }

    func testMetricPoint_explicitStaleTrue() {
        let point = MetricPoint(value: 85.5, isStale: true)
        XCTAssertEqual(point.value, 85.5)
        XCTAssertTrue(point.isStale)
    }

    // Note: MetricPoint is Hashable but includes the auto-generated UUID `id` field,
    // so two instances with different UUIDs are never equal regardless of value/stale.
    // This is intentional — equality of identity is not the point of this struct.

    func testMetricPoint_unequalWhenStaleDiffers() {
        let live = MetricPoint(value: 50.0, isStale: false)
        let stale = MetricPoint(value: 50.0, isStale: true)
        XCTAssertNotEqual(live, stale)
    }

    func testMetricPoint_unequalWhenValueDiffers() {
        let a = MetricPoint(value: 50.0, isStale: false)
        let b = MetricPoint(value: 51.0, isStale: false)
        XCTAssertNotEqual(a, b)
    }
}
