import SwiftUI

struct SparklineView: View {
    let title: String
    let points: [MetricPoint]
    let color: Color
    let valueText: String
    var fixedMax: Double? = nil
    var warningThreshold: Double? = nil
    var criticalThreshold: Double? = nil

    /// Colour for stale/gap segments — dimmed so unavailable data is clearly
    /// visually distinct from live data.
    private let staleColor = Color.gray

    private var resolvedColor: Color {
        guard let latest = points.last?.value, !latest.isNaN, !latest.isInfinite else { return color }
        if let criticalThreshold, latest >= criticalThreshold { return .red }
        if let warningThreshold, latest >= warningThreshold { return .orange }
        return color
    }

    private var latestPointIsStale: Bool {
        points.last?.isStale ?? false
    }

    private var backgroundTint: Color {
        guard let latest = points.last?.value, !latest.isNaN, !latest.isInfinite else { return Color.secondary.opacity(0.08) }
        if let criticalThreshold, latest >= criticalThreshold { return Color.red.opacity(0.12) }
        if let warningThreshold, latest >= warningThreshold { return Color.orange.opacity(0.10) }
        return Color.secondary.opacity(0.08)
    }

    // MARK: - Path builders (fileprivate for test access)

    /// Builds a Path containing only non-stale segments, broken at stale boundaries.
    /// Each continuous run of non-stale points gets its own move-to start.
    fileprivate func buildLivePath(in proxy: GeometryProxy) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            let validValues = points.map(\.value).filter { !$0.isNaN && !$0.isInfinite }
            guard !validValues.isEmpty else { return }
            let minValue = validValues.min()!
            let maxValue = fixedMax ?? max(validValues.max()!, minValue + 1)
            let range = max(maxValue - minValue, 1)
            let stepX = proxy.size.width / CGFloat(max(points.count - 1, 1))

            var segmentStart: Int? = nil

            for (index, point) in points.enumerated() {
                if point.isStale {
                    segmentStart = nil
                    continue
                }

                let x = CGFloat(index) * stepX
                let normalized = (point.value - minValue) / range
                let y = proxy.size.height - CGFloat(normalized) * proxy.size.height

                if segmentStart == nil {
                    path.move(to: CGPoint(x: x, y: y))
                    segmentStart = index
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    /// Builds a Path containing stale points rendered as individual grey dots
    /// with no connecting lines between them.
    fileprivate func buildStalePath(in proxy: GeometryProxy) -> Path {
        Path { path in
            guard points.count > 0 else { return }
            let validValues = points.map(\.value).filter { !$0.isNaN && !$0.isInfinite }
            guard !validValues.isEmpty else { return }
            let minValue = validValues.min()!
            let maxValue = fixedMax ?? max(validValues.max()!, minValue + 1)
            let range = max(maxValue - minValue, 1)
            let stepX = proxy.size.width / CGFloat(max(points.count - 1, 1))

            for (index, point) in points.enumerated() {
                guard point.isStale else { continue }
                let x = CGFloat(index) * stepX
                // Stale points show as a dot at the last known live value height,
                // signalling a gap without falsely implying continuity.
                let staleY: CGFloat
                if point.value.isNaN || point.value.isInfinite {
                    staleY = proxy.size.height / 2
                } else {
                    let normalized = (point.value - minValue) / range
                    staleY = proxy.size.height - CGFloat(normalized) * proxy.size.height
                }
                // Small vertical tick to mark the gap — not a full connecting line
                path.move(to: CGPoint(x: x, y: staleY - 2))
                path.addLine(to: CGPoint(x: x, y: staleY + 2))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(latestPointIsStale ? staleColor : resolvedColor)
            }

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundTint)

                    // Live segments: solid, threshold-coloured, unbroken at stale gaps
                    buildLivePath(in: proxy)
                        .stroke(
                            resolvedColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                    // Stale gaps: grey vertical ticks at each stale sample point,
                    // no connecting line — visually distinct from live data
                    buildStalePath(in: proxy)
                        .stroke(
                            staleColor,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                }
            }
            .frame(height: 44)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke((latestPointIsStale ? staleColor : resolvedColor).opacity(0.25), lineWidth: 1)
                )
        )
    }
}
