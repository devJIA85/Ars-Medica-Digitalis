//
//  ClinicalStatusSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct ClinicalStatusSection: View {

    let patient: Patient

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md, alignment: .leading),
        GridItem(.flexible(), spacing: AppSpacing.md, alignment: .leading),
        GridItem(.flexible(), spacing: AppSpacing.md, alignment: .leading)
    ]

    var body: some View {
        CardContainer(
            title: "Estado clínico",
            systemImage: "waveform.path.ecg.rectangle",
            style: .elevated
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    StatusBadge(
                        label: patient.clinicalStatusValue.label,
                        variant: statusVariant,
                        systemImage: "heart.text.square"
                    )

                    if let latestMeasurementDate {
                        StatusBadge(
                            label: "Control \(latestMeasurementDate.esDayMonthAbbrev())",
                            variant: .custom(.blue),
                            systemImage: "calendar"
                        )
                    }
                }

                if metricItems.isEmpty {
                    ClinicalEmptyState(text: "Sin datos antropométricos")
                } else {
                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(metricItems, id: \.title) { item in
                            ClinicalMetricTile(title: item.title, value: item.value)
                        }
                    }
                }

                if let bmi = patient.bmi {
                    BMIGaugeView(
                        bmiValue: bmi,
                        lastMeasurementDate: latestMeasurementDate
                    )
                }

                if records.count >= 2 {
                    WeightTrendChartView(records: records)
                } else if records.count == 1 {
                    ClinicalEmptyState(text: "Guardá mediciones en diferentes fechas para ver la tendencia")
                }
            }
        }
    }

    private var statusVariant: StatusBadge.Variant {
        switch patient.clinicalStatusValue {
        case .estable:
            return .success
        case .activo:
            return .warning
        case .riesgo:
            return .danger
        }
    }

    private var records: [AnthropometricRecord] {
        patient.anthropometricRecords ?? []
    }

    private var latestMeasurementDate: Date? {
        records.map(\.recordDate).max()
    }

    private var metricItems: [(title: String, value: String)] {
        var items: [(String, String)] = []

        if patient.weightKg > 0 {
            items.append(("Peso", "\(Self.decimalText(patient.weightKg)) kg"))
        }
        if patient.heightCm > 0 {
            items.append(("Altura", "\(Int(patient.heightCm.rounded())) cm"))
        }
        if patient.waistCm > 0 {
            items.append(("Cintura", "\(Int(patient.waistCm.rounded())) cm"))
        }

        return items
    }

    private static func decimalText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded - value) < 0.01 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }
}
