//
//  ClinicalDashboardRefreshTokenBuilder.swift
//  Ars Medica Digitalis
//
//  Construye un token determinístico para refrescar el dashboard clínico
//  sin depender del orden interno de relaciones SwiftData.
//

import Foundation

enum ClinicalDashboardRefreshTokenBuilder {

    struct EntityStamp: Sendable, Hashable {
        let id: UUID
        let timestampBits: UInt64

        init(id: UUID, date: Date) {
            self.id = id
            self.timestampBits = date.timeIntervalSinceReferenceDate.bitPattern
        }

        init(id: UUID, timestampBits: UInt64) {
            self.id = id
            self.timestampBits = timestampBits
        }
    }

    @MainActor
    static func token(from patients: [Patient]) -> String {
        let patientStamps = patients.map { EntityStamp(id: $0.id, date: $0.updatedAt) }

        let sessions = patients.flatMap { $0.sessions ?? [] }
        let sessionStamps = sessions.map { EntityStamp(id: $0.id, date: $0.updatedAt) }

        let payments = sessions.flatMap { $0.payments ?? [] }
        let paymentStamps = payments.map { EntityStamp(id: $0.id, date: $0.updatedAt) }

        let diagnoses = patients.flatMap { $0.activeDiagnoses ?? [] }
        let diagnosisStamps = diagnoses.map { EntityStamp(id: $0.id, date: $0.diagnosedAt) }

        return token(
            patients: patientStamps,
            sessions: sessionStamps,
            payments: paymentStamps,
            diagnoses: diagnosisStamps
        )
    }

    static func token(
        patients: [EntityStamp],
        sessions: [EntityStamp],
        payments: [EntityStamp],
        diagnoses: [EntityStamp]
    ) -> String {
        [
            segment(prefix: "p", entities: patients),
            segment(prefix: "s", entities: sessions),
            segment(prefix: "pay", entities: payments),
            segment(prefix: "dx", entities: diagnoses),
        ].joined(separator: "|")
    }

    private static func segment(prefix: String, entities: [EntityStamp]) -> String {
        let sorted = entities.sorted { lhs, rhs in
            lhs.id.uuidString < rhs.id.uuidString
        }

        let payload = sorted.map { entity in
            "\(entity.id.uuidString):\(entity.timestampBits)"
        }.joined(separator: ",")

        return "\(prefix)[\(entities.count)]{\(payload)}"
    }
}
