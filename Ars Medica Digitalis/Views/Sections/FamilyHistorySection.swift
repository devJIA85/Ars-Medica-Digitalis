//
//  FamilyHistorySection.swift
//  Ars Medica Digitalis
//
//  Sección colapsable (TERTIARY) — collapsed por defecto.
//  Card visual delegada a ClinicalSectionCard.
//

import SwiftUI
import PencilKit

struct FamilyHistorySection: View {

    let patient: Patient
    let onEditMedicalHistory: () -> Void
    let onShowGenogram: () -> Void

    @State private var isExpanded = false

    var body: some View {
        ClinicalSectionCard {
            DisclosureGroup(isExpanded: $isExpanded.animation(.easeInOut(duration: 0.2))) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if activeHistory.isEmpty && patient.familyHistoryOther.trimmed.isEmpty {
                        ClinicalEmptyState(text: "Sin antecedentes familiares registrados")
                    } else {
                        ForEach(activeHistory, id: \.label) { item in
                            ClinicalListRow(
                                icon: "exclamationmark.triangle",
                                title: item.label,
                                value: "Registrado",
                                onTap: onEditMedicalHistory,
                                onDelete: {
                                    deleteFamilyHistory(item.kind)
                                },
                                onEdit: onEditMedicalHistory
                            )
                        }

                        if !patient.familyHistoryOther.trimmed.isEmpty {
                            ClinicalListRow(
                                icon: "text.justify",
                                title: "Otros antecedentes",
                                value: patient.familyHistoryOther,
                                onTap: onEditMedicalHistory,
                                onDelete: deleteOtherFamilyHistory,
                                onEdit: onEditMedicalHistory
                            )
                        }
                    }

                    Divider()

                    if let data = patient.genogramData,
                       let drawing = try? PKDrawing(data: data) {
                        Button(action: onShowGenogram) {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label("Genograma", systemImage: "point.3.connected.trianglepath.dotted")
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
                .padding(.top, AppSpacing.sm)
            } label: {
                Label {
                    Text("Antecedentes familiares")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "person.3.sequence")
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Data

    private var activeHistory: [(label: String, kind: FamilyHistoryKind)] {
        var items: [(String, FamilyHistoryKind)] = []
        if patient.familyHistoryHTA { items.append(("Hipertensión arterial", .hta)) }
        if patient.familyHistoryACV { items.append(("ACV", .acv)) }
        if patient.familyHistoryCancer { items.append(("Cáncer", .cancer)) }
        if patient.familyHistoryDiabetes { items.append(("Diabetes", .diabetes)) }
        if patient.familyHistoryHeartDisease { items.append(("Enfermedad cardíaca", .heartDisease)) }
        if patient.familyHistoryMentalHealth { items.append(("Salud mental", .mentalHealth)) }
        return items
    }

    private func deleteFamilyHistory(_ kind: FamilyHistoryKind) {
        switch kind {
        case .hta:    patient.familyHistoryHTA = false
        case .acv:    patient.familyHistoryACV = false
        case .cancer: patient.familyHistoryCancer = false
        case .diabetes: patient.familyHistoryDiabetes = false
        case .heartDisease: patient.familyHistoryHeartDisease = false
        case .mentalHealth: patient.familyHistoryMentalHealth = false
        }
        patient.updatedAt = Date()
    }

    private func deleteOtherFamilyHistory() {
        patient.familyHistoryOther = ""
        patient.updatedAt = Date()
    }
}

private enum FamilyHistoryKind {
    case hta, acv, cancer, diabetes, heartDisease, mentalHealth
}
