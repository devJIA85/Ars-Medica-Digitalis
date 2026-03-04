//
//  ClinicalStatusSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct ClinicalStatusSection: View {

    let patient: Patient

    var body: some View {
        SectionCard(
            title: "Estado clínico",
            icon: "waveform.path.ecg.rectangle"
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

                if patient.bmi != nil || weightText != nil || heightText != nil || waistText != nil {
                    ClinicalStatusCard(
                        bmiValue: patient.bmi,
                        weightText: weightText,
                        heightText: heightText,
                        waistText: waistText,
                        lastMeasurementDate: latestMeasurementDate
                    )
                } else {
                    ClinicalEmptyState(text: "Sin datos antropométricos")
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

    private var weightText: String? {
        guard patient.weightKg > 0 else { return nil }
        return "\(Self.decimalText(patient.weightKg)) kg"
    }

    private var heightText: String? {
        guard patient.heightCm > 0 else { return nil }
        return "\(Int(patient.heightCm.rounded())) cm"
    }

    private var waistText: String? {
        guard patient.waistCm > 0 else { return nil }
        return "\(Int(patient.waistCm.rounded())) cm"
    }
}

private extension ClinicalStatusSection {
    static func decimalText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded - value) < 0.01 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }
}
