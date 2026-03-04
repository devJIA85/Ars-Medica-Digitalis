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
    @Environment(\.openURL) private var openURL

    let patient: Patient
    let professional: Professional

    @State private var showingEditForm: Bool = false
    @State private var showingNewSession: Bool = false
    @State private var showingGenogram: Bool = false
    @State private var showingNewTreatment: Bool = false
    @State private var showingNewHospitalization: Bool = false
    @State private var infoMedication: Medication? = nil
    @State private var genogramData: Data? = nil

    var body: some View {
        ClinicalDashboardView(
            patient: patient,
            onContact: contactPatient,
            onNewSession: {
                showingNewSession = true
            },
            onEditMedicalHistory: {
                showingEditForm = true
            },
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
        .sheet(isPresented: $showingNewSession) {
            NavigationStack {
                SessionFormView(patient: patient)
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

    private func contactPatient() {
        guard let phoneURL else { return }
        openURL(phoneURL)
    }

    private var phoneURL: URL? {
        let rawValue = patient.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.isEmpty == false else { return nil }

        let allowedCharacters = CharacterSet(charactersIn: "+0123456789")
        let normalized = rawValue.unicodeScalars.filter { scalar in
            allowedCharacters.contains(scalar)
        }

        let phoneNumber = String(String.UnicodeScalarView(normalized))
        guard phoneNumber.isEmpty == false else { return nil }
        return URL(string: "tel://\(phoneNumber)")
    }
}
