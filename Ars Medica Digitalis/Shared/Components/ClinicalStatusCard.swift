//
//  ClinicalStatusCard.swift
//  Ars Medica Digitalis
//
//  Resumen antropométrico con jerarquía visual centrada en IMC.
//

import SwiftUI

struct ClinicalStatusCard: View {

    let bmiValue: Double?
    let weightText: String?
    let heightText: String?
    let waistText: String?
    var lastMeasurementDate: Date? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var bmiFontSize: CGFloat = 36
    @State private var animatedFillProgress: CGFloat = 0

    private let minVisibleBMI: Double = 10
    private let maxVisibleBMI: Double = 45
    private let thresholds: [Double] = [18.5, 25, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            bmiBar
            metricsGrid
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .onAppear {
            animateBar()
        }
        .onChange(of: bmiValue) { _, _ in
            animateBar()
        }
    }

    private var header: some View {
        ViewThatFits(in: .vertical) {
            headerLayout(horizontal: true)
            headerLayout(horizontal: false)
        }
    }

    private var bmiBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)

                ZStack(alignment: .leading) {
                    segmentedTrack(width: width)

                    Capsule()
                        .fill(.primary.opacity(0.06))
                        .frame(width: width * animatedFillProgress, height: 12)

                    if bmiValue != nil {
                        Circle()
                            .fill(classificationColor)
                            .frame(width: 16, height: 16)
                            .shadow(color: classificationColor.opacity(0.24), radius: 5, y: 2)
                            .offset(x: markerOffset(totalWidth: width))
                    }
                }
            }
            .frame(height: 16)

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)

                ZStack(alignment: .topLeading) {
                    HStack {
                        Text(formatThreshold(minVisibleBMI))
                        Spacer(minLength: 0)
                        Text(formatThreshold(maxVisibleBMI))
                    }

                    ForEach(thresholds, id: \.self) { threshold in
                        Text(formatThreshold(threshold))
                            .position(
                                x: width * CGFloat((threshold - minVisibleBMI) / (maxVisibleBMI - minVisibleBMI)),
                                y: 8
                            )
                    }
                }
            }
            .frame(height: 16)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Escala de índice de masa corporal")
        .accessibilityValue(bmiAccessibilityValue)
        .accessibilityHint("Muestra la posición del IMC actual dentro de los rangos clínicos")
    }

    private func segmentedTrack(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                segment(color: BMICategory.underweight.color.opacity(0.24), start: minVisibleBMI, end: 18.5, totalWidth: width)
                segment(color: BMICategory.normal.color.opacity(0.22), start: 18.5, end: 25, totalWidth: width)
                segment(color: BMICategory.overweight.color.opacity(0.24), start: 25, end: 30, totalWidth: width)
                segment(color: BMICategory.obesity.color.opacity(0.22), start: 30, end: maxVisibleBMI, totalWidth: width)
            }
            .clipShape(Capsule())

            ForEach(thresholds, id: \.self) { threshold in
                Rectangle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 1, height: 12)
                    .offset(x: width * CGFloat((threshold - minVisibleBMI) / (maxVisibleBMI - minVisibleBMI)))
            }
        }
    }

    private func segment(color: Color, start: Double, end: Double, totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(
                width: totalWidth * CGFloat((end - start) / (maxVisibleBMI - minVisibleBMI)),
                height: 12
            )
    }

    private var metricsGrid: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: AppSpacing.sm) {
                ClinicalMetric(title: "Peso", value: weightText ?? "Sin dato", density: .compact)
                ClinicalMetric(title: "Altura", value: heightText ?? "Sin dato", density: .compact)
                ClinicalMetric(title: "Cintura", value: waistText ?? "Sin dato", density: .compact)
            }

            VStack(spacing: AppSpacing.sm) {
                ClinicalMetric(title: "Peso", value: weightText ?? "Sin dato", density: .compact)
                ClinicalMetric(title: "Altura", value: heightText ?? "Sin dato", density: .compact)
                ClinicalMetric(title: "Cintura", value: waistText ?? "Sin dato", density: .compact)
            }
        }
    }

    private func markerOffset(totalWidth: CGFloat) -> CGFloat {
        let markerX = totalWidth * CGFloat(clampedNormalizedBMI)
        let dotSize: CGFloat = 16
        return min(max(markerX - (dotSize / 2), 0), max(totalWidth - dotSize, 0))
    }

    private var formattedBMI: String? {
        guard let bmiValue else { return nil }
        return String(format: "%.1f", bmiValue)
    }

    private var classificationLabel: String {
        guard let bmiValue else { return "IMC no disponible" }
        return BMICategory(bmi: bmiValue)?.label ?? "Sin categoría"
    }

    private var classificationColor: Color {
        guard let bmiValue else { return .secondary }
        return BMICategory(bmi: bmiValue)?.color ?? .secondary
    }

    private var clampedNormalizedBMI: Double {
        guard let bmiValue else { return 0 }
        let clampedValue = min(max(bmiValue, minVisibleBMI), maxVisibleBMI)
        return (clampedValue - minVisibleBMI) / (maxVisibleBMI - minVisibleBMI)
    }

    private var lastMeasurementLabel: String {
        guard let lastMeasurementDate else { return "Sin registro" }
        return lastMeasurementDate.esShortDateAbbrev()
    }

    @ViewBuilder
    private func headerLayout(horizontal: Bool) -> some View {
        if horizontal && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                bmiSummary
                Spacer(minLength: 0)
                measurementSummary(alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                bmiSummary
                measurementSummary(alignment: .leading)
            }
        }
    }

    private var bmiSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("IMC")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if let formattedBMI {
                Text(formattedBMI)
                    .font(.system(size: bmiFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("Sin dato")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(classificationLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(classificationColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Índice de masa corporal")
        .accessibilityValue(formattedBMI.map { "\($0), \(classificationLabel)" } ?? "Sin dato")
    }

    private func measurementSummary(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("Última medición")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(lastMeasurementLabel)
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Última medición")
        .accessibilityValue(lastMeasurementLabel)
    }

    private var bmiAccessibilityValue: String {
        guard let formattedBMI else {
            return "Sin dato. \(classificationLabel)"
        }
        return "\(formattedBMI). \(classificationLabel). Última medición \(lastMeasurementLabel)"
    }

    private func formatThreshold(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func animateBar() {
        animatedFillProgress = 0
        withAnimation(.easeOut(duration: 0.4)) {
            animatedFillProgress = CGFloat(clampedNormalizedBMI)
        }
    }
}

#Preview("ClinicalStatusCard") {
    ClinicalStatusCard(
        bmiValue: 24.6,
        weightText: "72 kg",
        heightText: "171 cm",
        waistText: "88 cm",
        lastMeasurementDate: .now
    )
    .padding()
}
