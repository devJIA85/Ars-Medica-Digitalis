//
//  PatientMedicalHistoryView.swift
//  Ars Medica Digitalis
//
//  Contenedor de la Historia Clínica.
//  Conserva sheets, navegación y acciones sobre SwiftData,
//  delegando el layout al dashboard clínico.
//

import SwiftUI
import SwiftData

struct PatientMedicalHistoryView: View {

    @Environment(\.modelContext) private var modelContext

    let patient: Patient
    let professional: Professional

    @State private var showingEditForm: Bool = false
    @State private var showingGenogram: Bool = false
    @State private var showingNewTreatment: Bool = false
    @State private var showingNewHospitalization: Bool = false
    @State private var infoMedication: Medication? = nil
    @State private var genogramData: Data? = nil

    var body: some View {
        ClinicalDashboardView(
            patient: patient,
            onShowMedicationInfo: { medication in
                infoMedication = medication
            },
            onShowGenogram: {
                genogramData = patient.genogramData
                showingGenogram = true
            },
            onAddTreatment: {
                showingNewTreatment = true
            },
            onDeleteTreatment: { treatment in
                modelContext.delete(treatment)
            },
            onAddHospitalization: {
                showingNewHospitalization = true
            },
            onDeleteHospitalization: { hospitalization in
                modelContext.delete(hospitalization)
            }
        )
        .navigationTitle("Historia Clínica")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditForm = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Editar historia clínica")
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                PatientMedicalHistoryFormView(patient: patient)
            }
        }
        .sheet(isPresented: $showingGenogram, onDismiss: {
            patient.genogramData = genogramData
            patient.updatedAt = Date()
        }) {
            NavigationStack {
                GenogramCanvasView(drawingData: $genogramData)
                    .navigationTitle("Genograma")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") {
                                showingGenogram = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingNewTreatment) {
            NavigationStack {
                PriorTreatmentFormView(patient: patient)
            }
        }
        .sheet(isPresented: $showingNewHospitalization) {
            NavigationStack {
                HospitalizationFormView(patient: patient)
            }
        }
        .sheet(item: $infoMedication) { medication in
            NavigationStack {
                MedicationInfoSheetView(medication: medication)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") {
                                infoMedication = nil
                            }
                        }
                    }
            }
        }
    }
}
