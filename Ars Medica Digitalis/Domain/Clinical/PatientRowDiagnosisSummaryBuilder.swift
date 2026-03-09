//
//  PatientRowDiagnosisSummaryBuilder.swift
//  Ars Medica Digitalis
//
//  Resume diagnósticos para badges compactos en listados de pacientes.
//

import Foundation

enum PatientRowDiagnosisSummaryBuilder {

    @MainActor
    static func primarySummary(for patient: Patient) -> String? {
        if let activeSummary = summary(from: patient.activeDiagnoses ?? []) {
            return activeSummary
        }

        let latestCompletedDiagnoses = (patient.sessions ?? [])
            .filter { SessionStatusMapping(sessionStatusRawValue: $0.status) == .completada }
            .max(by: { $0.sessionDate < $1.sessionDate })?
            .diagnoses ?? []

        return summary(from: latestCompletedDiagnoses)
    }

    @MainActor
    static func summary(from diagnoses: [Diagnosis]) -> String? {
        let validDiagnoses = diagnoses.filter {
            $0.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        guard validDiagnoses.isEmpty == false else {
            return nil
        }

        let preferredDiagnosis = validDiagnoses.first {
            $0.diagnosisType.localizedCaseInsensitiveCompare("principal") == .orderedSame
        } ?? validDiagnoses.first

        guard let preferredDiagnosis else {
            return nil
        }

        let title = abbreviatedClinicalTitle(from: preferredDiagnosis.displayTitle)
        guard title.isEmpty == false else {
            return nil
        }

        let extraCount = validDiagnoses.count - 1
        if extraCount > 0 {
            return "\(title) +\(extraCount)"
        }

        return title
    }

    private static func abbreviatedClinicalTitle(from rawTitle: String) -> String {
        let compactTitle = rawTitle
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compactTitle.isEmpty == false else {
            return ""
        }

        let separators = [",", ";", "(", "·", ":"]
        let firstClause = separators
            .compactMap { compactTitle.range(of: $0) }
            .min(by: { $0.lowerBound < $1.lowerBound })
            .map {
                String(compactTitle[..<$0.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } ?? compactTitle

        let words = firstClause.split(separator: " ")
        guard words.count > 5 else {
            return firstClause
        }

        return words.prefix(5).joined(separator: " ") + "…"
    }
}
