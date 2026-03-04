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
import UIKit

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
    @State private var showingContactOptions: Bool = false
    @State private var contactAlertMessage: String = ""
    @State private var showingContactAlert: Bool = false

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
        .confirmationDialog("Contacto", isPresented: $showingContactOptions, titleVisibility: .visible) {
            if let normalizedPhoneNumber {
                Button("Llamar al paciente") {
                    startPhoneCall(with: normalizedPhoneNumber)
                }

                Button("Copiar número") {
                    copyPhoneNumberToPasteboard()
                    presentContactAlert("Se copió el número del paciente.")
                }
            }

            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(contactDialogMessage)
        }
        .alert("Contacto del paciente", isPresented: $showingContactAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactAlertMessage)
        }
    }

    private func contactPatient() {
        guard normalizedPhoneNumber != nil else {
            presentContactAlert("Este paciente no tiene un teléfono válido registrado.")
            return
        }

        showingContactOptions = true
    }

    private func startPhoneCall(with phoneNumber: String) {
        guard let phoneURL = URL(string: "tel://\(phoneNumber)") else {
            presentContactAlert("No se pudo preparar la llamada.")
            return
        }

        guard UIApplication.shared.canOpenURL(phoneURL) else {
            copyPhoneNumberToPasteboard()
            presentContactAlert("Este dispositivo no puede iniciar llamadas. Se copió el número para que puedas usarlo en otra app.")
            return
        }

        openURL(phoneURL)
    }

    private func copyPhoneNumberToPasteboard() {
        UIPasteboard.general.string = rawPhoneNumber
    }

    private func presentContactAlert(_ message: String) {
        contactAlertMessage = message
        showingContactAlert = true
    }

    private var contactDialogMessage: String {
        if let rawPhoneNumber {
            return "Número registrado: \(phoneNumberLabel(from: rawPhoneNumber))"
        }
        return "No hay teléfono registrado."
    }

    private var rawPhoneNumber: String? {
        let value = patient.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var normalizedPhoneNumber: String? {
        guard let rawPhoneNumber else { return nil }

        let allowedCharacters = CharacterSet(charactersIn: "+0123456789")
        let normalized = rawPhoneNumber.unicodeScalars.filter { scalar in
            allowedCharacters.contains(scalar)
        }

        let phoneNumber = String(String.UnicodeScalarView(normalized))
        return phoneNumber.isEmpty ? nil : phoneNumber
    }

    private func phoneNumberLabel(from rawValue: String) -> String {
        let digits = rawValue.filter(\.isNumber)
        guard digits.count >= 8 else { return rawValue }

        let suffix = digits.suffix(8)
        let prefix = digits.dropLast(8)
        let groupedSuffix = "\(suffix.prefix(4)) \(suffix.suffix(4))"
        let prefixText = prefix.isEmpty ? "" : "\(prefix) "
        return "\(prefixText)\(groupedSuffix)"
    }
}
