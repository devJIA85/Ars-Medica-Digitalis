//
//  ClinicalPriorityRadar.swift
//  Ars Medica Digitalis
//
//  Radar de prioridad clínica para filtrar pacientes por bucket.
//

import SwiftUI

struct ClinicalPriorityRadar: View {

    let model: ClinicalPriorityRadarModel
    let selectedBucket: ClinicalPriorityBucket?
    let onSelectBucket: (ClinicalPriorityBucket?) -> Void

    @State private var localSelection: ClinicalPriorityBucket? = nil
    @State private var animatedFractions = AnimatedFractions.zero
    @State private var hasAppeared = false
    @State private var shouldPulseCritical = false
    @State private var lastPulseToken = ""
    @ScaledMetric(relativeTo: .title2) private var ringDiameter: CGFloat = 162

    private let ringLineWidth: CGFloat = 18
    private let segmentGapDegrees: Double = 4

    init(
        model: ClinicalPriorityRadarModel,
        selectedBucket: ClinicalPriorityBucket? = nil,
        onSelectBucket: @escaping (ClinicalPriorityBucket?) -> Void = { _ in }
    ) {
        self.model = model
        self.selectedBucket = selectedBucket
        self.onSelectBucket = onSelectBucket
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            titleRow

            ZStack {
                ringTrack
                ringSegments
                ringHitAreas
                centerLabel
                Circle()
                    .fill(Color.clear)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(distributionAccessibilityLabel)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ringDiameter)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
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
            triggerCriticalPulseIfNeeded(using: model)
            hasAppeared = true
        }
        .onChange(of: selectedBucket) { _, newValue in
            localSelection = newValue
        }
        .onChange(of: model) { _, newValue in
            animateFractions(to: newValue)
            triggerCriticalPulseIfNeeded(using: newValue)
        }
    }

    private var titleRow: some View {
        Label {
            Text(L10n.tr("patient.dashboard.radar.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "scope")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
    }

    private var ringTrack: some View {
        Circle()
            .stroke(Color.secondary.opacity(0.16), lineWidth: ringLineWidth)
            .frame(width: ringDiameter, height: ringDiameter)
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
            .frame(width: ringDiameter, height: ringDiameter)
        }
    }

    private var ringHitAreas: some View {
        ForEach(ringSegmentGeometries) { segment in
            RingSectorHitShape(
                startAngle: segment.startAngle,
                endAngle: segment.endAngle,
                innerRadiusFactor: 0.62
            )
            .fill(Color.clear)
            .contentShape(
                RingSectorHitShape(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    innerRadiusFactor: 0.62
                )
            )
            .frame(width: ringDiameter, height: ringDiameter)
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
        .frame(width: ringDiameter * 0.56)
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

            let gap = min(segmentGapDegrees / 360, span * 0.45)
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

    private func lineWidth(for bucket: ClinicalPriorityBucket) -> CGFloat {
        let base = ringLineWidth
        let selectionBoost = localSelection == bucket ? 2.0 : 0
        let pulseBoost = bucket == .critical && shouldPulseCritical ? 1.5 : 0
        return base + selectionBoost + pulseBoost
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
        return localSelection == bucket ? 1 : 0.28
    }

    private func select(bucket: ClinicalPriorityBucket?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            localSelection = bucket
        }
        onSelectBucket(bucket)
    }

    private func animateFractions(to model: ClinicalPriorityRadarModel) {
        let applyAnimation = hasAppeared
        let target = AnimatedFractions(model: model)

        if applyAnimation {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                animatedFractions = target
            }
        } else {
            animatedFractions = target
        }
    }

    private func triggerCriticalPulseIfNeeded(using model: ClinicalPriorityRadarModel) {
        guard model.criticalCount > 0 else {
            shouldPulseCritical = false
            lastPulseToken = ""
            return
        }

        let token = "\(model.totalCount)-\(model.criticalCount)-\(model.attentionCount)-\(model.stableCount)"
        guard token != lastPulseToken else { return }
        lastPulseToken = token

        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.18).delay(0.14).repeatCount(1, autoreverses: true)) {
                shouldPulseCritical = true
            }
            try? await Task.sleep(nanoseconds: 480_000_000)
            shouldPulseCritical = false
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
