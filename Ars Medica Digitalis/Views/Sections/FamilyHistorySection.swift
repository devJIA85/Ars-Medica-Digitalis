//
//  FamilyHistorySection.swift
//  Ars Medica Digitalis
//

import SwiftUI
import PencilKit

struct FamilyHistorySection: View {

    let patient: Patient
    let onShowGenogram: () -> Void

    var body: some View {
        CardContainer(
            title: "Antecedentes familiares",
            systemImage: "person.3.sequence",
            style: .flat
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if activeHistory.isEmpty && patient.familyHistoryOther.trimmed.isEmpty {
                    ClinicalEmptyState(text: "Sin antecedentes familiares registrados")
                } else {
                    ForEach(activeHistory, id: \.self) { item in
                        Label(item, systemImage: "exclamationmark.triangle")
                    }

                    if !patient.familyHistoryOther.trimmed.isEmpty {
                        ClinicalMetricTile(title: "Otros antecedentes", value: patient.familyHistoryOther)
                    }
                }

                Divider()

                if let data = patient.genogramData,
                   let drawing = try? PKDrawing(data: data) {
                    Button(action: onShowGenogram) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Genograma")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Image(uiImage: drawing.image(from: drawing.bounds, scale: 2.0))
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))

                            Text("Abrir genograma")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onShowGenogram) {
                        Label("Crear genograma", systemImage: "pencil.and.scribble")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }

    private var activeHistory: [String] {
        var items: [String] = []
        if patient.familyHistoryHTA { items.append("Hipertensión arterial") }
        if patient.familyHistoryACV { items.append("ACV") }
        if patient.familyHistoryCancer { items.append("Cáncer") }
        if patient.familyHistoryDiabetes { items.append("Diabetes") }
        if patient.familyHistoryHeartDisease { items.append("Enfermedad cardíaca") }
        if patient.familyHistoryMentalHealth { items.append("Salud mental") }
        return items
    }
}
