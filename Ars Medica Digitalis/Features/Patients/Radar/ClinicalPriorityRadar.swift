//
//  ClinicalPriorityRadar.swift
//  Ars Medica Digitalis
//
//  Radar de prioridad clínica reutilizable en tamaño grande y mini.
//

import SwiftUI

enum ClinicalRadarSize: Sendable, Equatable {
    case large
    case compact
    case mini

    var diameter: CGFloat {
        switch self {
        case .large:
            136
        case .compact:
            80
        case .mini:
            30
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .large:
            15
        case .compact:
            9
        case .mini:
            4
        }
    }

    var segmentGapDegrees: Double {
        switch self {
        case .large:
            4
        case .compact:
            3
        case .mini:
            2
        }
    }

    var showsCenterContent: Bool {
        self == .large
    }

    var pulseBoost: CGFloat {
        switch self {
        case .large:
            1.5
        case .compact:
            1
        case .mini:
            0.7
        }
    }

    var centerWidthRatio: CGFloat {
        switch self {
        case .large:
            0.56
        case .compact:
            0
        case .mini:
            0
        }
    }
}

struct ClinicalPriorityRadar: View {

    let model: ClinicalPriorityRadarModel
    let size: ClinicalRadarSize
    let selectedBucket: ClinicalPriorityBucket?
    let onSelectBucket: (ClinicalPriorityBucket?) -> Void

    @State private var localSelection: ClinicalPriorityBucket? = nil
    @State private var animatedFractions = AnimatedFractions.zero
    @State private var hasAppeared = false

    init(
        model: ClinicalPriorityRadarModel,
        size: ClinicalRadarSize = .large,
        selectedBucket: ClinicalPriorityBucket? = nil,
        onSelectBucket: @escaping (ClinicalPriorityBucket?) -> Void = { _ in }
    ) {
        self.model = model
        self.size = size
        self.selectedBucket = selectedBucket
        self.onSelectBucket = onSelectBucket
    }

    var body: some View {
        ZStack {
            ringTrack
            ringSegments
            ringHitAreas
            if size.showsCenterContent {
                centerLabel
            }
            Circle()
                .fill(Color.clear)
                .frame(width: size.diameter, height: size.diameter)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(distributionAccessibilityLabel)
        }
        .frame(width: size.diameter, height: size.diameter)
        .contentShape(Circle())
        .contextMenu {
            Button(L10n.tr("patient.dashboard.radar.menu.show_critical")) {
                select(bucket: .critical)
            }
            Button(L10n.tr("patient.dashboard.radar.menu.show_attention")) {
                select(bucket: .attention)
            }
            Button(L10n.tr("patient.dashboard.radar.menu.show_stable")) {
                select(bucket: .stable)
            }
            Button(L10n.tr("patient.dashboard.radar.menu.show_all")) {
                select(bucket: nil)
            }
        }
        .onAppear {
            localSelection = selectedBucket
            animateFractions(to: model)
            hasAppeared = true
        }
        .onChange(of: selectedBucket) { _, newValue in
            localSelection = newValue
        }
        .onChange(of: model) { _, newValue in
            animateFractions(to: newValue)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: size)
    }

    private var ringTrack: some View {
        Circle()
            .stroke(Color.secondary.opacity(0.16), lineWidth: size.lineWidth)
    }

    private var ringSegments: some View {
        ForEach(ringSegmentGeometries) { segment in
            RingArcShape(
                startAngle: segment.startAngle,
                endAngle: segment.endAngle,
                lineWidth: lineWidth(for: segment.bucket)
            )
            .stroke(
                style: StrokeStyle(
                    lineWidth: lineWidth(for: segment.bucket),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .foregroundStyle(color(for: segment.bucket))
            .opacity(opacity(for: segment.bucket))
            .phaseAnimator([false, true]) { content, pulse in
                content.opacity(segment.bucket == .critical && model.criticalCount > 0 && pulse ? 0.65 : 1.0)
            } animation: { _ in
                segment.bucket == .critical && model.criticalCount > 0
                    ? .easeInOut(duration: 1.2) : .default
            }
        }
    }

    private var ringHitAreas: some View {
        ForEach(ringSegmentGeometries) { segment in
            RingSectorHitShape(
                startAngle: segment.startAngle,
                endAngle: segment.endAngle,
                innerRadiusFactor: innerRadiusFactor
            )
            .fill(Color.clear)
            .contentShape(
                RingSectorHitShape(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    innerRadiusFactor: innerRadiusFactor
                )
            )
            .onTapGesture {
                let next = localSelection == segment.bucket ? nil : segment.bucket
                select(bucket: next)
            }
            .accessibilityElement()
            .accessibilityHidden(localSelection != segment.bucket)
            .accessibilityLabel(
                L10n.tr(
                    "patient.dashboard.radar.voiceover.selected",
                    localizedBucketTitle(for: segment.bucket),
                    model.count(for: segment.bucket)
                )
            )
            .accessibilityHint(L10n.tr("patient.dashboard.radar.segment.selected.hint"))
            .accessibilityAddTraits(.isButton)
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text("\(model.totalCount)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.primary)

            Text(centerSubtitle)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(width: size.diameter * size.centerWidthRatio)
        .allowsHitTesting(false)
    }

    private var centerSubtitle: String {
        if model.criticalCount > 0 {
            return L10n.tr("patient.dashboard.radar.center.critical", model.criticalCount)
        }

        return L10n.tr("patient.dashboard.radar.center.stable")
    }

    private var distributionAccessibilityLabel: String {
        L10n.tr(
            "patient.dashboard.radar.voiceover.distribution",
            model.totalCount,
            model.criticalCount,
            model.attentionCount,
            model.stableCount
        )
    }

    private var ringSegmentGeometries: [SegmentGeometry] {
        let normalizedFractions = animatedFractions.normalized
        var currentPosition = 0.0
        var result: [SegmentGeometry] = []
        let minimumSpan = 0.005

        for entry in normalizedFractions where entry.fraction > 0 {
            let start = currentPosition
            let end = min(currentPosition + entry.fraction, 1)
            currentPosition = end

            let span = end - start
            guard span > minimumSpan else { continue }

            let gap = min(size.segmentGapDegrees / 360, span * 0.45)
            let adjustedStart = start + (gap * 0.5)
            let adjustedEnd = end - (gap * 0.5)

            guard adjustedEnd > adjustedStart else { continue }

            result.append(
                SegmentGeometry(
                    bucket: entry.bucket,
                    startAngle: .degrees(-90 + (adjustedStart * 360)),
                    endAngle: .degrees(-90 + (adjustedEnd * 360))
                )
            )
        }

        return result
    }

    private var innerRadiusFactor: CGFloat {
        switch size {
        case .large:
            0.62
        case .compact:
            0.6
        case .mini:
            0.46
        }
    }

    private func lineWidth(for bucket: ClinicalPriorityBucket) -> CGFloat {
        let base = size.lineWidth
        let selectionBoost: CGFloat = localSelection == bucket ? {
            switch size {
            case .large:
                2
            case .compact:
                1.5
            case .mini:
                1
            }
        }() : 0
        return base + selectionBoost
    }

    private func color(for bucket: ClinicalPriorityBucket) -> Color {
        switch bucket {
        case .critical:
            .red
        case .attention:
            .orange
        case .stable:
            .green
        }
    }

    private func opacity(for bucket: ClinicalPriorityBucket) -> Double {
        guard let localSelection else { return 1 }
        return localSelection == bucket ? 1 : 0.3
    }

    private func select(bucket: ClinicalPriorityBucket?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            localSelection = bucket
        }
        onSelectBucket(bucket)
    }

    private func animateFractions(to model: ClinicalPriorityRadarModel) {
        let target = AnimatedFractions(model: model)

        if hasAppeared {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                animatedFractions = target
            }
        } else {
            animatedFractions = target
        }
    }

    private func localizedBucketTitle(for bucket: ClinicalPriorityBucket) -> String {
        switch bucket {
        case .critical:
            L10n.tr("patient.dashboard.radar.bucket.critical")
        case .attention:
            L10n.tr("patient.dashboard.radar.bucket.attention")
        case .stable:
            L10n.tr("patient.dashboard.radar.bucket.stable")
        }
    }
}

private struct SegmentGeometry: Identifiable, Equatable {
    let bucket: ClinicalPriorityBucket
    let startAngle: Angle
    let endAngle: Angle

    var id: ClinicalPriorityBucket { bucket }
}

private struct AnimatedFractions: Equatable {
    let critical: Double
    let attention: Double
    let stable: Double

    init(critical: Double, attention: Double, stable: Double) {
        self.critical = max(critical, 0)
        self.attention = max(attention, 0)
        self.stable = max(stable, 0)
    }

    init(model: ClinicalPriorityRadarModel) {
        self.init(
            critical: model.criticalFraction,
            attention: model.attentionFraction,
            stable: model.stableFraction
        )
    }

    var normalized: [(bucket: ClinicalPriorityBucket, fraction: Double)] {
        let values: [(ClinicalPriorityBucket, Double)] = [
            (.critical, critical),
            (.attention, attention),
            (.stable, stable),
        ]

        let total = values.reduce(0) { $0 + $1.1 }
        guard total > 0 else {
            return values.map { ($0.0, 0) }
        }

        return values.map { ($0.0, $0.1 / total) }
    }

    static let zero = AnimatedFractions(critical: 0, attention: 0, stable: 0)
}

private struct RingSectorHitShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadiusFactor: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        let innerRadius = max(outerRadius * innerRadiusFactor, 0)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
