//
//  PatientPickerView.swift
//  Ars Medica Digitalis
//
//  Selector de paciente para crear una sesión desde el calendario.
//  Muestra una lista buscable de pacientes activos; al seleccionar uno,
//  navega (push) a SessionFormView dentro del mismo NavigationStack.
//  Así se evita el problema de sheets encadenados.
//

import SwiftUI
import SwiftData

struct PatientPickerView: View {

    let professional: Professional

    /// Fecha preseleccionada desde el calendario.
    /// Se propaga a SessionFormView para que la sesión nueva
    /// arranque con esa fecha por defecto.
    let initialDate: Date?

    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    init(professional: Professional, initialDate: Date? = nil) {
        self.professional = professional
        self.initialDate = initialDate
    }

    var body: some View {
        PatientPickerFilteredList(searchText: searchText, initialDate: initialDate)
        .searchable(text: $searchText, prompt: "Buscar paciente")
        .navigationTitle("Seleccionar Paciente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
    }
}

// MARK: - Lista filtrada para el picker

/// Subvista con @Query dinámico que filtra pacientes activos por nombre.
/// Patrón idéntico a PatientFilteredList de PatientListView,
/// pero simplificado: sin swipe actions, solo pacientes activos,
/// y cada fila navega a SessionFormView.
private struct PatientPickerFilteredList: View {

    @Query private var patients: [Patient]

    let initialDate: Date?

    init(searchText: String, initialDate: Date? = nil) {
        self.initialDate = initialDate
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        if trimmed.isEmpty {
            _patients = Query(
                filter: #Predicate<Patient> { patient in
                    patient.deletedAt == nil
                },
                sort: \Patient.lastName
            )
        } else {
            _patients = Query(
                filter: #Predicate<Patient> { patient in
                    patient.deletedAt == nil
                    && (patient.firstName.localizedStandardContains(trimmed)
                        || patient.lastName.localizedStandardContains(trimmed))
                },
                sort: \Patient.lastName
            )
        }
    }

    var body: some View {
        List {
            if patients.isEmpty {
                ContentUnavailableView(
                    "Sin pacientes",
                    systemImage: "person.slash",
                    description: Text("No se encontraron pacientes activos.")
                )
            } else {
                ForEach(patients) { patient in
                    NavigationLink {
                        SessionFormView(patient: patient, initialDate: initialDate)
                    } label: {
                        PatientPickerRow(patient: patient)
                    }
                }
            }
        }
    }
}

// MARK: - Fila de paciente en el picker

private struct PatientPickerRow: View {

    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(patient.fullName)
                .font(.body)
                .fontWeight(.medium)

            Text(patient.dateOfBirth.formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let professional = Professional(
        fullName: "Dr. Test",
        licenseNumber: "MN 999",
        specialty: "Psicología"
    )
    container.mainContext.insert(professional)

    let patient = Patient(
        firstName: "Ana",
        lastName: "García",
        professional: professional
    )
    container.mainContext.insert(patient)

    return NavigationStack {
        PatientPickerView(professional: professional)
    }
    .modelContainer(container)
}
