//
//  BMIGaugeView.swift
//  Ars Medica Digitalis
//
//  Visualización de IMC con jerarquía fuerte y barra refinada.
//

import SwiftUI

struct BMIGaugeView: View {

    private struct BMISegment: Identifiable {
        let id: String
        let start: Double
        let end: Double
        let color: Color
    }

    let bmiValue: Double
    var lastMeasurementDate: Date? = nil

    private let minVisibleBMI: Double = 10
    private let maxVisibleBMI: Double = 45
    private let thresholds: [Double] = [18.5, 25, 30]

    private var segments: [BMISegment] {
        [
            BMISegment(
                id: "underweight",
                start: 10,
                end: 18.5,
                color: .orange.opacity(0.24)
            ),
            BMISegment(
                id: "normal",
                start: 18.5,
                end: 25,
                color: .mint.opacity(0.24)
            ),
            BMISegment(
                id: "overweight",
                start: 25,
                end: 30,
                color: .yellow.opacity(0.22)
            ),
            BMISegment(
                id: "obesity",
                start: 30,
                end: 45,
                color: .red.opacity(0.20)
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            refinedBar
            thresholdScale
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.8)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("IMC")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Text(String(format: "%.1f", bmiValue))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(bmiCategory)
                        .font(.headline)
                        .foregroundStyle(markerColor)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Última medición")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(lastMeasurementLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var refinedBar: some View {
        GeometryReader { proxy in
            let totalWidth = max(proxy.size.width, 1)
            let markerX = markerPosition(totalWidth: totalWidth)

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(
                                width: segmentWidth(segment, totalWidth: totalWidth),
                                height: 12
                            )
                    }
                }
                .clipShape(Capsule())

                ForEach(thresholds, id: \.self) { threshold in
                    Rectangle()
                        .fill(.white.opacity(0.35))
                        .frame(width: 1, height: 12)
                        .offset(x: thresholdOffset(threshold, totalWidth: totalWidth))
                }

                Circle()
                    .fill(.background)
                    .overlay(
                        Circle()
                            .stroke(markerColor, lineWidth: 2)
                    )
                    .frame(width: 14, height: 14)
                    .offset(
                        x: clamped(
                            markerX - 7,
                            lower: 0,
                            upper: max(totalWidth - 14, 0)
                        )
                    )
                    .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            }
        }
        .frame(height: 14)
    }

    private var thresholdScale: some View {
        GeometryReader { proxy in
            let totalWidth = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                ForEach(thresholds, id: \.self) { threshold in
                    Text(String(format: threshold == floor(threshold) ? "%.0f" : "%.1f", threshold))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .position(
                            x: thresholdOffset(threshold, totalWidth: totalWidth),
                            y: 8
                        )
                }
            }
        }
        .frame(height: 14)
    }

    private func segmentWidth(_ segment: BMISegment, totalWidth: CGFloat) -> CGFloat {
        let span = maxVisibleBMI - minVisibleBMI
        let segmentSpan = max(segment.end - segment.start, 0.1)
        return totalWidth * CGFloat(segmentSpan / span)
    }

    private func thresholdOffset(_ threshold: Double, totalWidth: CGFloat) -> CGFloat {
        let normalized = (threshold - minVisibleBMI) / (maxVisibleBMI - minVisibleBMI)
        return totalWidth * CGFloat(normalized)
    }

    private func markerPosition(totalWidth: CGFloat) -> CGFloat {
        let normalized = (clampedBMI - minVisibleBMI) / (maxVisibleBMI - minVisibleBMI)
        return totalWidth * CGFloat(normalized)
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private var clampedBMI: Double {
        min(max(bmiValue, minVisibleBMI), maxVisibleBMI)
    }

    private var markerColor: Color {
        switch BMICategory(bmi: bmiValue) {
        case .underweight:
            return .orange.opacity(0.75)
        case .normal:
            return .mint.opacity(0.80)
        case .overweight:
            return .yellow.opacity(0.80)
        case .obesity:
            return .red.opacity(0.70)
        case .none:
            return .secondary
        }
    }

    private var bmiCategory: String {
        BMICategory(bmi: bmiValue)?.label ?? "Sin categoría"
    }

    private var lastMeasurementLabel: String {
        guard let lastMeasurementDate else { return "Sin registro" }
        return lastMeasurementDate.esShortDateAbbrev()
    }
}

#Preview("Rangos IMC") {
    VStack(spacing: AppSpacing.lg) {
        BMIGaugeView(bmiValue: 17.0, lastMeasurementDate: .now)
        BMIGaugeView(bmiValue: 22.5, lastMeasurementDate: .now.addingTimeInterval(-86_400 * 9))
        BMIGaugeView(bmiValue: 27.3)
        BMIGaugeView(bmiValue: 35.0, lastMeasurementDate: .now.addingTimeInterval(-86_400 * 33))
    }
    .padding()
}
