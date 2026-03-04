//
//  RiskFactorsSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct RiskFactorsSection: View {

    let patient: Patient
    let onEditMedicalHistory: () -> Void

    var body: some View {
        SectionCard(
            title: "Factores de riesgo",
            icon: "exclamationmark.shield"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(riskFactors.enumerated()), id: \.element.title) { index, factor in
                    ClinicalListRow(
                        icon: factor.systemImage,
                        title: factor.title,
                        value: factor.isActive ? "Sí" : "No",
                        onTap: onEditMedicalHistory,
                        onDelete: {
                            deleteRiskFactor(factor.kind)
                        },
                        onEdit: onEditMedicalHistory
                    )

                    if index < riskFactors.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var riskFactors: [(title: String, systemImage: String, isActive: Bool, kind: RiskFactorKind)] {
        [
            ("Tabaquismo", "smoke", patient.smokingStatus, .smoking),
            ("Consumo de alcohol", "wineglass", patient.alcoholUse, .alcohol),
            ("Consumo de drogas", "pill", patient.drugUse, .drugs),
            ("Chequeos de rutina", "heart.text.clipboard", patient.routineCheckups, .routineCheckups)
        ]
    }

    private func deleteRiskFactor(_ factor: RiskFactorKind) {
        switch factor {
        case .smoking:
            patient.smokingStatus = false
        case .alcohol:
            patient.alcoholUse = false
        case .drugs:
            patient.drugUse = false
        case .routineCheckups:
            patient.routineCheckups = false
        }
        patient.updatedAt = Date()
    }
}

private enum RiskFactorKind {
    case smoking
    case alcohol
    case drugs
    case routineCheckups
}
