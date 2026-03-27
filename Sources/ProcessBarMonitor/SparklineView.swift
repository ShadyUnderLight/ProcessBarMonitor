import SwiftUI

struct SparklineView: View {
    let title: String
    let points: [MetricPoint]
    let color: Color
    let valueText: String
    var fixedMax: Double? = nil
    var warningThreshold: Double? = nil
    var criticalThreshold: Double? = nil

    private var resolvedColor: Color {
        guard let latest = points.last?.value else { return color }
        if let criticalThreshold, latest >= criticalThreshold { return .red }
        if let warningThreshold, latest >= warningThreshold { return .orange }
        return color
    }

    private var backgroundTint: Color {
        guard let latest = points.last?.value else { return Color.secondary.opacity(0.08) }
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
                    .foregroundStyle(resolvedColor)
            }

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundTint)

                    Path { path in
                        guard points.count > 1 else { return }
                        let values = points.map(\.value)
                        let minValue = values.min() ?? 0
                        let maxValue = fixedMax ?? max(values.max() ?? 1, minValue + 1)
                        let range = max(maxValue - minValue, 1)
                        let stepX = proxy.size.width / CGFloat(max(points.count - 1, 1))

                        for (index, point) in points.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalized = (point.value - minValue) / range
                            let y = proxy.size.height - CGFloat(normalized) * proxy.size.height
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(resolvedColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
                        .stroke(resolvedColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
