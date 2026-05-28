//
//  PatientDashboardView.swift
//  Ars Medica Digitalis
//
//  Vista de lista de pacientes con swipe-to-deactivate y confirmación de baja lógica.
//

import SwiftUI
import SwiftData
import OSLog

struct PatientDashboardView: View {

    let professional: Professional
    let state: PatientDashboardState
    let namespace: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.auditService) private var auditService
    @Environment(\.currentActorID) private var currentActorID

    @State private var patientToDelete: Patient?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                if state.hasPatients {
                    ForEach(state.alphabeticalRows) { row in
                        NavigationLink {
                            PatientDetailView(patient: row.patient, professional: professional)
                                .navigationTransition(.zoom(sourceID: row.id, in: namespace))
                        } label: {
                            PatientCard(model: row)
                                .equatable()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("patient.card.\(row.fullName)")
                        .matchedTransitionSource(id: row.id, in: namespace)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if row.isActive {
                                Button(L10n.tr("Baja"), role: .destructive) {
                                    patientToDelete = row.patient
                                }
                            }
                        }
                        .contextMenu {
                            if row.isActive {
                                Button(L10n.tr("Baja"), role: .destructive) {
                                    patientToDelete = row.patient
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        L10n.tr("patient.dashboard.empty.title"),
                        systemImage: "person.2.slash",
                        description: Text(L10n.tr("patient.dashboard.empty.subtitle"))
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
            .backgroundExtensionEffect()
        }
        .themedBackground()
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
        // Confirmación de baja lógica (HU-03).
        // Estado local: PatientDashboardView es la capa más cercana al origen de la acción.
        // iPhone: action sheet desde el borde inferior (comportamiento HIG estándar).
        // iPad: el sistema puede anclar la presentación al contexto del row.
        .confirmationDialog(
            "¿Dar de baja a este paciente?",
            isPresented: Binding(
                get: { patientToDelete != nil },
                set: { if !$0 { patientToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Dar de Baja", role: .destructive) {
                if let patient = patientToDelete {
                    patient.softDelete(by: currentActorID, reason: "Baja desde lista de pacientes")
                    auditService.log(
                        action: .softDelete,
                        on: patient,
                        in: modelContext,
                        performedBy: currentActorID
                    )
                    do {
                        try modelContext.save()
                    } catch {
                        Logger(subsystem: "com.arsmedica.digitalis", category: "PatientDashboardView")
                            .error("Error al persistir baja lógica: \(error, privacy: .public)")
                    }
                    patientToDelete = nil
                }
            }
            Button("Cancelar", role: .cancel) {
                patientToDelete = nil
            }
        } message: {
            Text(L10n.tr("patient.confirmation.deactivate.message"))
        }
    }
}
