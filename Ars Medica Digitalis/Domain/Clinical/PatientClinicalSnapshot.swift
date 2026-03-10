//
//  PatientClinicalSnapshot.swift
//  Ars Medica Digitalis
//
//  Snapshot clínico precalculado por paciente para listas y prefetch.
//

import Foundation

typealias ClinicalSnapshotCache = [UUID: PatientClinicalSnapshot]

struct PatientClinicalSnapshot: Sendable, Equatable {
    let patientID: UUID
    let lastSessionDate: Date?
    let nextSessionDate: Date?
    let sessionCount: Int
    let completedSessions: Int
    let cancelledSessions: Int
    let adherence: Double
    let daysSinceLastSession: Int?
    let diagnosisSummary: String?
    let hasDebt: Bool
    
    // Instrumentos clínicos (ej. escalas psicométricas)
    let bdiScore: Int?
    let bdiSeverity: String?
    let lastBDIDate: Date?
    
    init(
        patientID: UUID,
        lastSessionDate: Date?,
        nextSessionDate: Date?,
        sessionCount: Int,
        completedSessions: Int,
        cancelledSessions: Int,
        adherence: Double,
        daysSinceLastSession: Int?,
        diagnosisSummary: String?,
        hasDebt: Bool,
        bdiScore: Int? = nil,
        bdiSeverity: String? = nil,
        lastBDIDate: Date? = nil
    ) {
        self.patientID = patientID
        self.lastSessionDate = lastSessionDate
        self.nextSessionDate = nextSessionDate
        self.sessionCount = sessionCount
        self.completedSessions = completedSessions
        self.cancelledSessions = cancelledSessions
        self.adherence = adherence
        self.daysSinceLastSession = daysSinceLastSession
        self.diagnosisSummary = diagnosisSummary
        self.hasDebt = hasDebt
        self.bdiScore = bdiScore
        self.bdiSeverity = bdiSeverity
        self.lastBDIDate = lastBDIDate
    }
}
