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
}
