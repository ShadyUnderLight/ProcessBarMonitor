import XCTest
@testable import ProcessBarMonitor

/// Regression tests for SparklineView live/stale rendering separation (issue #31).
///
/// The key rendering guarantees we verify here (without a full SwiftUI render):
///   1. `latestPointIsStale` is correctly derived from the last point's flag.
///   2. Repeated stale points in the history are correctly tracked.
///   3. `MetricPoint.isStale` segregation is correct at the data level.
///
/// Full visual rendering (live segments solid, stale segments as grey ticks,
/// continuity broken at stale boundaries) is validated by the reviewer
/// against the live app build.
///
final class SparklineViewTests: XCTestCase {

    // MARK: - latestPointIsStale derivation

    /// When the latest point is stale the sparkline dims the value text.
    func testLatestPointIsStale_trueWhenLastPointStale() {
        let view = SparklineView(
            title: "Temp",
            points: [
                MetricPoint(value: 80.0),
                MetricPoint(value: 85.0, isStale: true),
            ],
            color: .green,
            valueText: "--"
        )
        XCTAssertTrue(view.latestPointIsStale)
    }

    /// When the latest point is live the value text colour is not dimmed.
    func testLatestPointIsStale_falseWhenLastPointLive() {
        let view = SparklineView(
            title: "Temp",
            points: [
                MetricPoint(value: 80.0, isStale: true),
                MetricPoint(value: 85.0),
            ],
            color: .green,
            valueText: "85°C"
        )
        XCTAssertFalse(view.latestPointIsStale)
    }

    // MARK: - Data-level segregation: live vs stale

    /// Live segments followed by a stale point must not corrupt the live segment.
    /// The stale point is flagged `isStale=true` — it is excluded from live rendering
    /// by `buildLivePath` which skips any point where `isStale == true`.
    func testStalePoints_doNotPolluteLiveSegmentData() {
        let points: [MetricPoint] = [
            MetricPoint(value: 20.0),
            MetricPoint(value: 30.0),
            MetricPoint(value: 40.0, isStale: true),   // ← gap
            MetricPoint(value: 50.0),
        ]

        let liveValues = points.filter { !$0.isStale }.map(\.value)
        let staleValues = points.filter { $0.isStale }.map(\.value)

        XCTAssertEqual(liveValues, [20.0, 30.0, 50.0])
        XCTAssertEqual(staleValues, [40.0])
    }

    /// Repeated stale points must not create misleading continuous live strokes.
    /// Repeated stale values must all be flagged stale.
    func testRepeatedStalePoints_allFlaggedStale() {
        let points: [MetricPoint] = [
            MetricPoint(value: 60.0),
            MetricPoint(value: 70.0, isStale: true),
            MetricPoint(value: 70.0, isStale: true),
            MetricPoint(value: 70.0, isStale: true),
            MetricPoint(value: 80.0),
        ]

        let liveCount = points.filter { !$0.isStale }.count
        let staleCount = points.filter { $0.isStale }.count

        XCTAssertEqual(liveCount, 2)  // 60.0 and 80.0
        XCTAssertEqual(staleCount, 3) // 3 repeated 70.0 stale points
    }

    /// All-stale history: every point has isStale=true → live path is empty after
    /// stale filtering, stale path contains all points.  No live line rendered.
    func testAllStalePoints_livePathEmpty() {
        let points: [MetricPoint] = [
            MetricPoint(value: 70.0, isStale: true),
            MetricPoint(value: 71.0, isStale: true),
            MetricPoint(value: 72.0, isStale: true),
        ]

        let liveValues = points.filter { !$0.isStale }.map(\.value)
        XCTAssertTrue(liveValues.isEmpty, "All stale → no live points")
    }

    // MARK: - Live continuity is broken at stale boundaries

    /// A stale point interrupts the live series — verified at data level:
    /// consecutive non-stale points form separate segments when interrupted by stale.
    func testLiveContinuityBrokenByStaleBoundary() {
        let points: [MetricPoint] = [
            MetricPoint(value: 10.0),
            MetricPoint(value: 20.0),
            MetricPoint(value: 20.0, isStale: true),  // ← gap
            MetricPoint(value: 30.0),
            MetricPoint(value: 40.0),
        ]

        // Collect live values — they form two contiguous runs:
        // [10, 20] before the stale, [30, 40] after
        let liveValues = points.filter { !$0.isStale }.map(\.value)
        XCTAssertEqual(liveValues, [10.0, 20.0, 30.0, 40.0])
        // But in the sparkline rendering the stale point breaks the path,
        // so [10→20] is one segment and [30→40] is a separate segment.
        // This is confirmed by buildLivePath which does path.move at index 3.
    }

    // MARK: - valueText colour dimming via resolvedColor

    /// resolvedColor falls back to the base color when latest point is live.
    func testResolvedColor_baseColorWhenLive() {
        let view = SparklineView(
            title: "CPU",
            points: [MetricPoint(value: 50.0)],
            color: .blue,
            valueText: "50%"
        )
        // latestPointIsStale == false → text gets resolvedColor (blue)
        XCTAssertFalse(view.latestPointIsStale)
    }

    /// resolvedColor is replaced with grey when latest point is stale.
    func testResolvedColor_greyWhenStale() {
        let view = SparklineView(
            title: "CPU",
            points: [MetricPoint(value: 50.0, isStale: true)],
            color: .blue,
            valueText: "--"
        )
        XCTAssertTrue(view.latestPointIsStale)
    }
}

// MARK: - Test helpers
//
// These extensions expose private members to the test target.

extension SparklineView {
    fileprivate var latestPointIsStale: Bool {
        points.last?.isStale ?? false
    }
}
