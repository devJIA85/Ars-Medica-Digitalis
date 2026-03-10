//
//  SessionPhantomRepairService.swift
//  Ars Medica Digitalis
//
//  Repara sesiones fantasma creadas por borradores financieros
//  que nunca debieron persistirse en SwiftData.
//

import Foundation
import SwiftData

/// Heurísticas compartidas para detectar sesiones internas que no fueron
/// creadas por el profesional sino por borradores de cálculo del formulario.
enum SessionPhantomHeuristics {

    /// Una sesión fantasma de este bug queda vacía clínicamente, sin cobros
    /// y en estado abierto. Con la UI actual eso no puede surgir de un guardado
    /// legítimo del usuario porque chiefComplaint es obligatorio.
    static func isPhantomCandidate(_ session: Session) -> Bool {
        session.chiefComplaint.trimmed.isEmpty
        && session.notes.trimmed.isEmpty
        && session.treatmentPlan.trimmed.isEmpty
        && session.sessionStatusValue == .programada
        && session.completedAt == nil
        && (session.payments ?? []).isEmpty
        && (session.diagnoses ?? []).isEmpty
        && (session.attachments ?? []).isEmpty
    }
}

struct SessionRepairResult: Sendable {
    let removedCount: Int
    let skippedCount: Int
}

@MainActor
struct SessionPhantomRepairService {

    /// Ejecuta una limpieza conservadora de sesiones fantasma.
    /// Solo elimina registros imposibles de haber sido creados desde la UI
    /// real para no tocar sesiones clínicas legítimas.
    func repairIfNeeded(in context: ModelContext) async throws -> SessionRepairResult {
        let descriptor = FetchDescriptor<Session>()
        let allSessions = try context.fetch(descriptor)
        let calendarService = CalendarIntegrationService()

        let phantomSessions = allSessions.filter(SessionPhantomHeuristics.isPhantomCandidate)
        guard phantomSessions.isEmpty == false else {
            print("SessionPhantomRepairService: no se encontraron sesiones fantasma.")
            return SessionRepairResult(removedCount: 0, skippedCount: allSessions.count)
        }

        for session in phantomSessions {
            if session.calendarEventIdentifier?.isEmpty == false {
                do {
                    try await calendarService.deleteEvent(for: session)
                } catch {
                    print("SessionPhantomRepairService calendar cleanup failed: \(error.localizedDescription)")
                }
            }
            context.delete(session)
        }

        try context.save()

        print(
            "SessionPhantomRepairService: se eliminaron \(phantomSessions.count) sesiones fantasma y se conservaron \(allSessions.count - phantomSessions.count)."
        )

        return SessionRepairResult(
            removedCount: phantomSessions.count,
            skippedCount: allSessions.count - phantomSessions.count
        )
    }
}
