import SwiftUI

struct ClinicalRiskRing: View {

    let model: ClinicalPriorityRadarModel
    let selectedBucket: ClinicalPriorityBucket?
    let onSelectBucket: (ClinicalPriorityBucket?) -> Void
    let ringSize: ClinicalRadarSize

    init(
        model: ClinicalPriorityRadarModel,
        selectedBucket: ClinicalPriorityBucket?,
        onSelectBucket: @escaping (ClinicalPriorityBucket?) -> Void,
        ringSize: ClinicalRadarSize = .compact
    ) {
        self.model = model
        self.selectedBucket = selectedBucket
        self.onSelectBucket = onSelectBucket
        self.ringSize = ringSize
    }

    var body: some View {
        HStack(spacing: 12) {
            ClinicalPriorityRadar(
                model: model,
                size: ringSize,
                selectedBucket: selectedBucket,
                onSelectBucket: onSelectBucket
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(primaryValue)")
                    .font(primaryValueFont)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)

                Text(primaryStatus)
                    .font(statusFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var primaryBucket: ClinicalPriorityBucket {
        if let selectedBucket {
            return selectedBucket
        }

        if model.criticalCount > 0 {
            return .critical
        }

        if model.attentionCount > 0 {
            return .attention
        }

        return .stable
    }

    private var primaryValue: Int {
        model.count(for: primaryBucket)
    }

    private var primaryStatus: String {
        switch primaryBucket {
        case .critical:
            L10n.tr("patient.dashboard.radar.bucket.critical")
        case .attention:
            L10n.tr("patient.dashboard.radar.bucket.attention")
        case .stable:
            L10n.tr("patient.dashboard.radar.bucket.stable")
        }
    }

    private var primaryValueFont: Font {
        switch ringSize {
        case .large, .compact:
            .system(size: 34, weight: .semibold)
        case .mini:
            .title3.weight(.semibold)
        }
    }

    private var statusFont: Font {
        switch ringSize {
        case .mini:
            .caption
        case .large, .compact:
            .subheadline
        }
    }

    private var accessibilityLabel: String {
        let distribution = L10n.tr(
            "patient.dashboard.radar.voiceover.distribution",
            model.totalCount,
            model.criticalCount,
            model.attentionCount,
            model.stableCount
        )
        return "\(primaryValue) \(primaryStatus). \(distribution)"
    }
}
