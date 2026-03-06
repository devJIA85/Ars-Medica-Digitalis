//
//  ClinicalSnapshotBuilder.swift
//  Ars Medica Digitalis
//
//  Construye snapshots clínicos puros para evitar recomputar métricas
//  derivadas dentro de filas SwiftUI.
//

import Foundation

enum ClinicalSnapshotBuilder {

    @MainActor
    static func buildSnapshots(patients: [Patient]) -> ClinicalSnapshotCache {
        buildSnapshots(
            patients: patients,
            referenceDate: Date(),
            calendar: .current
        )
    }

    @MainActor
    static func buildSnapshots(
        patients: [Patient],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> ClinicalSnapshotCache {
        let sources = patients.map(PatientClinicalSource.init)
        return buildSnapshots(
            sources: sources,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private static func buildSnapshots(
        sources: [PatientClinicalSource],
        referenceDate: Date,
        calendar: Calendar
    ) -> ClinicalSnapshotCache {
        sources.reduce(into: ClinicalSnapshotCache()) { partialResult, patient in
            partialResult[patient.patientID] = snapshot(
                for: patient,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    private static func snapshot(
        for patient: PatientClinicalSource,
        referenceDate: Date,
        calendar: Calendar
    ) -> PatientClinicalSnapshot {
        let completedSessions = patient.sessions.filter { $0.status == .completed }
        let cancelledSessions = patient.sessions.filter { $0.status == .cancelled }
        let today = calendar.startOfDay(for: referenceDate)

        let lastSessionDate = completedSessions
            .map(\.sessionDate)
            .max()

        let nextSessionDate = patient.sessions
            .filter { $0.status == .scheduled && $0.sessionDate >= today }
            .map(\.sessionDate)
            .min()

        return PatientClinicalSnapshot(
            patientID: patient.patientID,
            lastSessionDate: lastSessionDate,
            nextSessionDate: nextSessionDate,
            sessionCount: patient.sessions.count,
            completedSessions: completedSessions.count,
            cancelledSessions: cancelledSessions.count,
            adherence: adherence(
                completedSessions: completedSessions.count,
                cancelledSessions: cancelledSessions.count
            ),
            daysSinceLastSession: daysSinceLastSession(
                lastSessionDate: lastSessionDate,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            diagnosisSummary: diagnosisSummary(for: patient, completedSessions: completedSessions),
            hasDebt: hasDebt(for: patient, calendar: calendar)
        )
    }

    private static func adherence(
        completedSessions: Int,
        cancelledSessions: Int
    ) -> Double {
        let closedSessions = completedSessions + cancelledSessions
        guard closedSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(closedSessions)
    }

    private static func daysSinceLastSession(
        lastSessionDate: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int? {
        guard let lastSessionDate else { return nil }

        let sessionDay = calendar.startOfDay(for: lastSessionDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let dayCount = calendar.dateComponents(
            [.day],
            from: sessionDay,
            to: referenceDay
        ).day ?? 0

        return max(dayCount, 0)
    }

    private static func diagnosisSummary(
        for patient: PatientClinicalSource,
        completedSessions: [SessionClinicalSource]
    ) -> String? {
        if let activeSummary = diagnosisSummary(from: patient.activeDiagnoses) {
            return activeSummary
        }

        let latestCompletedDiagnoses = completedSessions
            .max(by: { $0.sessionDate < $1.sessionDate })?
            .diagnoses

        return diagnosisSummary(from: latestCompletedDiagnoses)
    }

    private static func diagnosisSummary(
        from diagnoses: [DiagnosisClinicalSource]?
    ) -> String? {
        let validDiagnoses = (diagnoses ?? []).filter {
            $0.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        guard validDiagnoses.isEmpty == false else { return nil }

        let preferredDiagnosis = validDiagnoses.first {
            $0.diagnosisType.localizedCaseInsensitiveCompare("principal") == .orderedSame
        } ?? validDiagnoses.first

        guard let preferredDiagnosis else { return nil }

        let title = abbreviatedClinicalTitle(from: preferredDiagnosis.displayTitle)
        guard title.isEmpty == false else { return nil }

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

        guard compactTitle.isEmpty == false else { return "" }

        let separators = [",", ";", "(", "·", ":"]
        let firstClause = separators
            .compactMap { compactTitle.range(of: $0) }
            .min(by: { $0.lowerBound < $1.lowerBound })
            .map {
                String(compactTitle[..<$0.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } ?? compactTitle

        let words = firstClause.split(separator: " ")
        guard words.count > 5 else { return firstClause }

        return words.prefix(5).joined(separator: " ") + "…"
    }

    private static func hasDebt(
        for patient: PatientClinicalSource,
        calendar: Calendar
    ) -> Bool {
        patient.sessions.contains { session in
            guard session.status == .completed else { return false }

            let currency = resolvedCurrency(
                for: session,
                patient: patient
            )
            guard currency.isEmpty == false else { return false }

            return resolvedDebt(
                for: session,
                patient: patient,
                calendar: calendar
            ) > 0
        }
    }

    private static func resolvedDebt(
        for session: SessionClinicalSource,
        patient: PatientClinicalSource,
        calendar: Calendar
    ) -> Decimal {
        let remaining = resolvedPrice(
            for: session,
            patient: patient,
            calendar: calendar
        ) - session.totalPaid

        return remaining > 0 ? remaining : 0
    }

    private static func resolvedPrice(
        for session: SessionClinicalSource,
        patient: PatientClinicalSource,
        calendar: Calendar
    ) -> Decimal {
        if session.isCourtesy {
            return 0
        }

        if let finalPriceSnapshot = session.finalPriceSnapshot {
            return finalPriceSnapshot
        }

        if session.resolvedPrice > 0 {
            return session.resolvedPrice
        }

        guard let sessionType = session.financialSessionType else {
            return 0
        }

        let currency = resolvedCurrency(for: session, patient: patient)
        guard currency.isEmpty == false else {
            return 0
        }

        if let defaultPrice = resolvePatientDefaultPrice(
            patient: patient,
            sessionType: sessionType,
            currencyCode: currency
        ) {
            return defaultPrice
        }

        if let catalogPrice = resolveCatalogPrice(
            sessionType: sessionType,
            currencyCode: currency,
            scheduledAt: session.sessionDate,
            calendar: calendar
        ) {
            return catalogPrice
        }

        let normalizedName = normalizedSessionTypeName(sessionType.name)
        for sibling in patient.professionalSessionTypes {
            guard sibling.id != sessionType.id else { continue }
            guard sibling.isActive else { continue }
            guard normalizedSessionTypeName(sibling.name) == normalizedName else { continue }

            if let siblingPrice = resolveCatalogPrice(
                sessionType: sibling,
                currencyCode: currency,
                scheduledAt: session.sessionDate,
                calendar: calendar
            ) {
                return siblingPrice
            }
        }

        return 0
    }

    private static func resolvedCurrency(
        for session: SessionClinicalSource,
        patient: PatientClinicalSource
    ) -> String {
        if let finalCurrencySnapshot = session.finalCurrencySnapshot,
           finalCurrencySnapshot.isEmpty == false {
            return finalCurrencySnapshot
        }

        return resolveCurrency(for: patient, at: session.sessionDate)
    }

    private static func resolveCurrency(
        for patient: PatientClinicalSource,
        at date: Date
    ) -> String {
        let versions = patient.currencyVersions
            .filter { $0.effectiveFrom <= date && $0.currencyCode.isEmpty == false }
            .sorted { lhs, rhs in
                if lhs.effectiveFrom == rhs.effectiveFrom {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.effectiveFrom > rhs.effectiveFrom
            }

        return versions.first?.currencyCode ?? patient.fallbackCurrencyCode
    }

    private static func resolvePatientDefaultPrice(
        patient: PatientClinicalSource,
        sessionType: SessionCatalogTypeSource,
        currencyCode: String
    ) -> Decimal? {
        patient.sessionDefaultPrices
            .filter {
                $0.sessionCatalogTypeID == sessionType.id
                && $0.currencyCode == currencyCode
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .first?.price
    }

    private static func resolveCatalogPrice(
        sessionType: SessionCatalogTypeSource,
        currencyCode: String,
        scheduledAt: Date,
        calendar: Calendar
    ) -> Decimal? {
        let versions = sessionType.priceVersions
            .filter { $0.currencyCode == currencyCode }

        return resolveCatalogPriceVersion(
            from: versions,
            scheduledAt: scheduledAt,
            calendar: calendar
        )?.price
    }

    private static func resolveCatalogPriceVersion(
        from versions: [SessionTypePriceVersionSource],
        scheduledAt: Date,
        calendar: Calendar
    ) -> SessionTypePriceVersionSource? {
        guard versions.isEmpty == false else { return nil }

        let scheduledDay = calendar.startOfDay(for: scheduledAt)
        let sortedByEffectiveDateDescending = versions.sorted { lhs, rhs in
            if lhs.effectiveFrom == rhs.effectiveFrom {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.effectiveFrom > rhs.effectiveFrom
        }

        if let currentVersion = sortedByEffectiveDateDescending.first(where: { version in
            calendar.startOfDay(for: version.effectiveFrom) <= scheduledDay
        }) {
            return currentVersion
        }

        return versions.min { lhs, rhs in
            let lhsDay = calendar.startOfDay(for: lhs.effectiveFrom)
            let rhsDay = calendar.startOfDay(for: rhs.effectiveFrom)

            if lhsDay == rhsDay {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhsDay < rhsDay
        }
    }

    private static func normalizedSessionTypeName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

private struct PatientClinicalSource: Sendable {
    let patientID: UUID
    let fallbackCurrencyCode: String
    let sessions: [SessionClinicalSource]
    let activeDiagnoses: [DiagnosisClinicalSource]
    let sessionDefaultPrices: [PatientSessionDefaultPriceSource]
    let currencyVersions: [PatientCurrencyVersionSource]
    let professionalSessionTypes: [SessionCatalogTypeSource]

    @MainActor
    init(_ patient: Patient) {
        patientID = patient.id
        fallbackCurrencyCode = patient.currencyCode
        sessions = (patient.sessions ?? []).map(SessionClinicalSource.init)
        activeDiagnoses = (patient.activeDiagnoses ?? []).map(DiagnosisClinicalSource.init)
        sessionDefaultPrices = (patient.sessionDefaultPrices ?? []).map(PatientSessionDefaultPriceSource.init)
        currencyVersions = (patient.currencyVersions ?? []).map(PatientCurrencyVersionSource.init)
        professionalSessionTypes = (patient.professional?.sessionCatalogTypes ?? []).map(SessionCatalogTypeSource.init)
    }
}

private struct SessionClinicalSource: Sendable {
    let sessionDate: Date
    let status: SessionClinicalStatus
    let diagnoses: [DiagnosisClinicalSource]
    let finalPriceSnapshot: Decimal?
    let finalCurrencySnapshot: String?
    let resolvedPrice: Decimal
    let isCourtesy: Bool
    let totalPaid: Decimal
    let financialSessionType: SessionCatalogTypeSource?

    @MainActor
    init(_ session: Session) {
        sessionDate = session.sessionDate
        status = SessionClinicalStatus(rawValue: session.status)
        diagnoses = (session.diagnoses ?? []).map(DiagnosisClinicalSource.init)
        finalPriceSnapshot = session.finalPriceSnapshot
        finalCurrencySnapshot = session.finalCurrencySnapshot
        resolvedPrice = session.resolvedPrice
        isCourtesy = session.isCourtesy
        totalPaid = (session.payments ?? []).reduce(0) { partialResult, payment in
            partialResult + payment.amount
        }
        financialSessionType = session.financialSessionType.map(SessionCatalogTypeSource.init)
    }
}

private enum SessionClinicalStatus: Sendable {
    case scheduled
    case completed
    case cancelled

    init(rawValue: String) {
        switch SessionStatusMapping(sessionStatusRawValue: rawValue) {
        case .programada:
            self = .scheduled
        case .cancelada:
            self = .cancelled
        case .completada, .none:
            self = .completed
        }
    }
}

private struct DiagnosisClinicalSource: Sendable {
    let displayTitle: String
    let diagnosisType: String

    @MainActor
    init(_ diagnosis: Diagnosis) {
        displayTitle = diagnosis.displayTitle
        diagnosisType = diagnosis.diagnosisType
    }
}

private struct PatientSessionDefaultPriceSource: Sendable {
    let sessionCatalogTypeID: UUID?
    let price: Decimal
    let currencyCode: String
    let createdAt: Date
    let updatedAt: Date

    @MainActor
    init(_ price: PatientSessionDefaultPrice) {
        sessionCatalogTypeID = price.sessionCatalogType?.id
        self.price = price.price
        currencyCode = price.currencyCode
        createdAt = price.createdAt
        updatedAt = price.updatedAt
    }
}

private struct PatientCurrencyVersionSource: Sendable {
    let currencyCode: String
    let effectiveFrom: Date
    let updatedAt: Date

    @MainActor
    init(_ version: PatientCurrencyVersion) {
        currencyCode = version.currencyCode
        effectiveFrom = version.effectiveFrom
        updatedAt = version.updatedAt
    }
}

private struct SessionCatalogTypeSource: Sendable {
    let id: UUID
    let name: String
    let isActive: Bool
    let priceVersions: [SessionTypePriceVersionSource]

    @MainActor
    init(_ sessionType: SessionCatalogType) {
        id = sessionType.id
        name = sessionType.name
        isActive = sessionType.isActive
        priceVersions = (sessionType.priceVersions ?? []).map(SessionTypePriceVersionSource.init)
    }
}

private struct SessionTypePriceVersionSource: Sendable {
    let effectiveFrom: Date
    let price: Decimal
    let currencyCode: String
    let updatedAt: Date

    @MainActor
    init(_ version: SessionTypePriceVersion) {
        effectiveFrom = version.effectiveFrom
        price = version.price
        currencyCode = version.currencyCode
        updatedAt = version.updatedAt
    }
}
