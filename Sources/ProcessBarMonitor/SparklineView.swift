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
        guard let latest = points.last?.value else { return color }
        if latest.isNaN || latest.isInfinite { return color }
        if let criticalThreshold, latest >= criticalThreshold { return .red }
        if let warningThreshold, latest >= warningThreshold { return .orange }
        return color
    }

    private var latestPointIsStale: Bool {
        points.last?.isStale ?? false
    }

    private var backgroundTint: Color {
        guard let latest = points.last?.value else { return Color.secondary.opacity(0.08) }
        if latest.isNaN || latest.isInfinite { return Color.secondary.opacity(0.08) }
        if let criticalThreshold, latest >= criticalThreshold { return Color.red.opacity(0.12) }
        if let warningThreshold, latest >= warningThreshold { return Color.orange.opacity(0.10) }
        return Color.secondary.opacity(0.08)
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

                    Path { path in
                        guard points.count > 1 else { return }
                        let values = points.map(\.value)
                        let minValue = values.filter { !$0.isNaN && !$0.isInfinite }.min() ?? 0
                        let maxValue = fixedMax ?? max(values.filter { !$0.isNaN && !$0.isInfinite }.max() ?? 1, minValue + 1)
                        let range = max(maxValue - minValue, 1)
                        let stepX = proxy.size.width / CGFloat(max(points.count - 1, 1))

                        // Draw one segment at a time.  A stale point breaks the line:
                        // the next non-stale point starts a fresh path.move.
                        var segmentStart: Int? = nil

                        for (index, point) in points.enumerated() {
                            if point.isStale {
                                // Close the current segment if one is open
                                segmentStart = nil
                                continue
                            }

                            let x = CGFloat(index) * stepX
                            let normalized = (point.value - minValue) / range
                            let y = proxy.size.height - CGFloat(normalized) * proxy.size.height

                            if segmentStart == nil {
                                // Fresh segment — start with a move
                                path.move(to: CGPoint(x: x, y: y))
                                segmentStart = index
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        latestPointIsStale ? staleColor : resolvedColor,
                        style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: latestPointIsStale ? [4, 3] : []
                        )
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
