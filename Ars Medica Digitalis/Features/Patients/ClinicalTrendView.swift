import SwiftUI

struct ClinicalTrendView: View {

    let trends: [ClinicalTrend]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(trends) { trend in
                    trendIndicator(trend)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func trendIndicator(_ trend: ClinicalTrend) -> some View {
        HStack(spacing: 4) {
            Image(systemName: directionSymbol(for: trend))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(toneColor(for: trend.tone))

            Text(trendLabel(for: trend))
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend.accessibilityLabel)
    }

    private func toneColor(for tone: ClinicalTrendTone) -> Color {
        switch tone {
        case .positive:
            .green
        case .caution:
            .orange
        case .neutral:
            .gray
        }
    }

    private func directionSymbol(for trend: ClinicalTrend) -> String {
        let trimmed = trend.displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = trimmed.first else { return "arrow.right" }

        switch prefix {
        case "↑":
            return "arrow.up"
        case "↓":
            return "arrow.down"
        default:
            return "arrow.right"
        }
    }

    private func trendLabel(for trend: ClinicalTrend) -> String {
        var trimmed = trend.displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first, first == "↑" || first == "↓" || first == "→" {
            trimmed = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
