//
//  ContentView.swift
//  Ars Medica Digitalis
//
//  Created by Juan Ignacio Antolini on 18/02/2026.
//

import SwiftUI
import SwiftData

/// Vista raíz que controla el flujo principal de la app:
/// - Sin Professional → Onboarding (HU-01)
/// - Con Professional → Lista de pacientes (HU-02, HU-03)
struct ContentView: View {

    @Query private var professionals: [Professional]

    // Flag local para forzar la transición tras completar el onboarding,
    // ya que @Query puede tardar un ciclo en reflejar el insert.
    @State private var didCompleteOnboarding = false

    var body: some View {
        if let professional = professionals.first {
            mainView(for: professional)
        } else if didCompleteOnboarding {
            // Estado transitorio: el Professional se insertó pero @Query
            // aún no lo refleja. ProgressView evita flash visual.
            ProgressView()
        } else {
            OnboardingView {
                didCompleteOnboarding = true
            }
        }
    }

    // MARK: - Vista principal

    @ViewBuilder
    private func mainView(for professional: Professional) -> some View {
        NavigationStack {
            PatientListView(professional: professional)
                .navigationDestination(for: UUID.self) { patientID in
                    // Busca el Patient por UUID para la navegación tipada
                    PatientDestinationView(
                        patientID: patientID,
                        professional: professional
                    )
                }
        }
    }
}

/// Vista auxiliar que resuelve el Patient desde su UUID.
/// Necesaria porque navigationDestination(for:) recibe un valor,
/// no un objeto SwiftData directamente.
private struct PatientDestinationView: View {

    @Query private var patients: [Patient]

    let patientID: UUID
    let professional: Professional

    init(patientID: UUID, professional: Professional) {
        self.patientID = patientID
        self.professional = professional

        let id = patientID
        _patients = Query(
            filter: #Predicate<Patient> { $0.id == id }
        )
    }

    var body: some View {
        if let patient = patients.first {
            PatientDetailView(patient: patient, professional: professional)
        } else {
            ContentUnavailableView(
                "Paciente no encontrado",
                systemImage: "exclamationmark.triangle"
            )
        }
    }
}

#Preview("Sin perfil — Onboarding") {
    ContentView()
        .modelContainer(for: [
            Professional.self,
            Patient.self,
            Session.self,
            Diagnosis.self,
            Attachment.self,
        ], inMemory: true)
}

#Preview("Con perfil — Lista de Pacientes") {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let professional = Professional(
        fullName: "Dra. María López",
        licenseNumber: "MN 54321",
        specialty: "Psicología",
        email: "maria@example.com"
    )
    container.mainContext.insert(professional)

    let patients = [
        Patient(firstName: "Ana", lastName: "García", professional: professional),
        Patient(firstName: "Carlos", lastName: "Rodríguez", professional: professional),
        Patient(firstName: "María", lastName: "López", email: "maria.l@example.com", professional: professional),
    ]
    patients.forEach { container.mainContext.insert($0) }

    return ContentView()
        .modelContainer(container)
}
