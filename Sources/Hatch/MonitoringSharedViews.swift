import SwiftUI

struct StatsPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 36, weight: .bold))
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ServerGridCardChrome: ViewModifier {
    @Binding var isHovered: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color(.windowBackgroundColor))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isHovered ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.15 : 0.1),
                radius: isHovered ? 3 : 2,
                x: 0,
                y: isHovered ? 2 : 1
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func serverGridCardChrome(isHovered: Binding<Bool>, cornerRadius: CGFloat = 12) -> some View {
        modifier(ServerGridCardChrome(isHovered: isHovered, cornerRadius: cornerRadius))
    }
}

struct CircularGaugeView: View {
    let label: String
    let percent: Int?

    private var progress: CGFloat {
        guard let percent else { return 0 }
        return CGFloat(min(max(percent, 0), 100)) / 100
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: progress)
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(width: 76, height: 76)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MonitoringMetricPairRow: View {
    let uploadLabel: String
    let uploadValue: String
    let downloadLabel: String
    let downloadValue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            metricColumn(label: uploadLabel, value: uploadValue, icon: "arrow.up")
            metricColumn(label: downloadLabel, value: downloadValue, icon: "arrow.down")
        }
    }

    @ViewBuilder
    private func metricColumn(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(label)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

struct MonitoringMetricLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
