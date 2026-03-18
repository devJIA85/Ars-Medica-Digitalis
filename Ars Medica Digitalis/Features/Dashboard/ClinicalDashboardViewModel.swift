//
//  ClinicalDashboardViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel del dashboard clínico. Extrae el cálculo de estado del body
//  de ClinicalDashboardView para que no se recompute en cada re-render,
//  evitando trabajo innecesario con listas grandes de pacientes.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class ClinicalDashboardViewModel {

    // MARK: - Estado observable

    private(set) var state: ClinicalDashboardViewState = .empty

    // MARK: - Carga

    /// Recalcula el estado del dashboard a partir de los pacientes y el contexto.
    /// Es `async` para no bloquear el MainActor durante la construcción de snapshots
    /// con listas grandes. `.task(id:)` en la vista la cancela si cambian los datos
    /// antes de que termine, evitando actualizaciones sobre estado obsoleto.
    func reload(patients: [Patient], context: ModelContext) async {
        // Cede el hilo al render loop antes de hacer trabajo pesado,
        // de modo que la UI muestre el skeleton/spinner antes del cálculo.
        await Task.yield()
        guard !Task.isCancelled else { return }
        state = buildState(from: patients, context: context)
    }

    // MARK: - Builder privado

    private func buildState(
        from patients: [Patient],
        context: ModelContext
    ) -> ClinicalDashboardViewState {
        let snapshotCache = ClinicalSnapshotBuilder.buildSnapshots(
            patients: patients,
            context: context
        )
        let insightEngine = PatientInsightEngine()

        let rows = patients.compactMap { patient -> ClinicalDashboardPatientRowModel? in
            guard let snapshot = snapshotCache[patient.id] else { return nil }
            let insight = insightEngine.buildInsight(snapshot: snapshot)
            return ClinicalDashboardPatientRowModel(
                patient: patient,
                snapshot: snapshot,
                insight: insight
            )
        }

        let groupedRows = Dictionary(grouping: rows, by: \.sectionKind)
        let sections = ClinicalDashboardSection.Kind.displayOrder.compactMap { kind -> ClinicalDashboardSection? in
            guard let sectionRows = groupedRows[kind], !sectionRows.isEmpty else { return nil }
            return ClinicalDashboardSection(
                kind: kind,
                rows: sectionRows.sorted { lhs, rhs in
                    lhs.riskScore != rhs.riskScore
                        ? lhs.riskScore > rhs.riskScore
                        : lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
                }
            )
        }

        let totalAdherence = rows.reduce(0) { $0 + $1.adherence }
        let averageAdherence = rows.isEmpty ? 0 : totalAdherence / Double(rows.count)

        return ClinicalDashboardViewState(
            criticalPatients: rows.filter { $0.sectionKind == .critical }.count,
            riskPatients: rows.filter { $0.sectionKind != .stable }.count,
            averageAdherence: averageAdherence,
            patientsWithoutSession30Days: rows.filter { ($0.daysSinceLastSession ?? 0) >= 30 }.count,
            sections: sections
        )
    }
}

// MARK: - State value type (interna al feature)

struct ClinicalDashboardViewState {
    let criticalPatients: Int
    let riskPatients: Int
    let averageAdherence: Double
    let patientsWithoutSession30Days: Int
    let sections: [ClinicalDashboardSection]

    static let empty = ClinicalDashboardViewState(
        criticalPatients: 0,
        riskPatients: 0,
        averageAdherence: 0,
        patientsWithoutSession30Days: 0,
        sections: []
    )
}
