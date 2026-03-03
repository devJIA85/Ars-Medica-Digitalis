//
//  SessionPricingService.swift
//  Ars Medica Digitalis
//
//  Resuelve moneda y precio financiero de una sesión sin tocar la UI.
//  Centraliza la lógica para que los modelos lean siempre la misma fuente.
//

import Foundation
import SwiftData

@MainActor
final class SessionPricingService {

    private let modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    /// Resuelve la moneda vigente de un paciente para una fecha dada.
    /// Usa #Predicate para consultar el historial y, si no encuentra una versión,
    /// cae al currencyCode escalar para compatibilidad con datos previos.
    func resolveCurrency(for patient: Patient, at date: Date) -> String {
        let fallbackCurrency = patient.currencyCode
        guard let context = resolveContext(preferred: patient.modelContext) else {
            return resolveCurrencyInMemory(for: patient, at: date) ?? fallbackCurrency
        }

        let patientID = patient.id
        let descriptor = FetchDescriptor<PatientCurrencyVersion>(
            predicate: #Predicate<PatientCurrencyVersion> { version in
                version.patient?.id == patientID
                && version.effectiveFrom <= date
            },
            sortBy: [
                SortDescriptor(\PatientCurrencyVersion.effectiveFrom, order: .reverse),
                SortDescriptor(\PatientCurrencyVersion.updatedAt, order: .reverse),
            ]
        )

        do {
            if let currency = try context.fetch(descriptor).first?.currencyCode,
               !currency.isEmpty {
                return currency
            }
        } catch {
            return resolveCurrencyInMemory(for: patient, at: date) ?? fallbackCurrency
        }

        return fallbackCurrency
    }

    /// Resuelve el precio dinámico de una sesión mientras siga abierta.
    /// Prioriza override base del paciente y luego catálogo profesional versionado.
    /// No usa resolvedPrice persistido porque el valor debe recalcularse en vivo.
    func resolveDynamicPrice(for session: Session) -> Decimal {
        if session.isCourtesy {
            return 0
        }

        guard let patient = session.patient,
              let sessionType = session.financialSessionType else {
            return 0
        }

        let currency = resolveCurrency(for: patient, at: session.scheduledAt)
        if currency.isEmpty {
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
            scheduledAt: session.scheduledAt
        ) {
            return catalogPrice
        }

        return 0
    }

    /// Congela el snapshot financiero cuando la sesión queda completada.
    /// Es idempotente: si ya existe snapshot, no vuelve a recalcular ni reescribir.
    func finalizeSessionPricing(session: Session) {
        guard session.isCompleted else { return }
        guard session.finalPriceSnapshot == nil, session.finalCurrencySnapshot == nil else { return }

        let currency = session.patient.map { resolveCurrency(for: $0, at: session.scheduledAt) } ?? ""
        let dynamicPrice = resolveDynamicPrice(for: session)

        session.finalCurrencySnapshot = currency
        session.finalPriceSnapshot = session.isCourtesy ? 0 : dynamicPrice
    }

    /// Mantiene la compatibilidad con el flujo de cambios de precio versionado.
    /// Como el precio ahora es dinámico y sin caché persistida, no escribe nada:
    /// solo identifica la población afectada para un posible invalidation hook futuro.
    func applyPriceUpdate(for sessionCatalogType: SessionCatalogType, effectiveFrom: Date) {
        guard let context = resolveContext(preferred: sessionCatalogType.modelContext) else { return }

        let typeID = sessionCatalogType.id
        let completedStatus = SessionStatusMapping.completada.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.financialSessionType?.id == typeID
                && session.sessionDate >= effectiveFrom
            },
            sortBy: [SortDescriptor(\Session.sessionDate)]
        )

        if let sessions = try? context.fetch(descriptor) {
            _ = sessions.filter { session in
                session.status != completedStatus
                && session.priceWasManuallyOverridden == false
            }
        }
    }

    private func resolveContext(preferred: ModelContext?) -> ModelContext? {
        preferred ?? modelContext
    }

    private func resolveCurrencyInMemory(for patient: Patient, at date: Date) -> String? {
        let versions = (patient.currencyVersions ?? [])
            .filter { $0.effectiveFrom <= date && !$0.currencyCode.isEmpty }
            .sorted { lhs, rhs in
                if lhs.effectiveFrom == rhs.effectiveFrom {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.effectiveFrom > rhs.effectiveFrom
            }

        return versions.first?.currencyCode
    }

    private func resolvePatientDefaultPrice(
        patient: Patient,
        sessionType: SessionCatalogType,
        currencyCode: String
    ) -> Decimal? {
        guard let context = resolveContext(preferred: patient.modelContext ?? sessionType.modelContext) else {
            return resolvePatientDefaultPriceInMemory(
                patient: patient,
                sessionType: sessionType,
                currencyCode: currencyCode
            )
        }

        let patientID = patient.id
        let typeID = sessionType.id
        let descriptor = FetchDescriptor<PatientSessionDefaultPrice>(
            predicate: #Predicate<PatientSessionDefaultPrice> { price in
                price.patient?.id == patientID
                && price.sessionCatalogType?.id == typeID
                && price.currencyCode == currencyCode
            },
            sortBy: [
                SortDescriptor(\PatientSessionDefaultPrice.updatedAt, order: .reverse),
                SortDescriptor(\PatientSessionDefaultPrice.createdAt, order: .reverse),
            ]
        )

        do {
            return try context.fetch(descriptor).first?.price
        } catch {
            return resolvePatientDefaultPriceInMemory(
                patient: patient,
                sessionType: sessionType,
                currencyCode: currencyCode
            )
        }
    }

    private func resolvePatientDefaultPriceInMemory(
        patient: Patient,
        sessionType: SessionCatalogType,
        currencyCode: String
    ) -> Decimal? {
        (patient.sessionDefaultPrices ?? [])
            .filter {
                $0.sessionCatalogType?.id == sessionType.id
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

    private func resolveCatalogPrice(
        sessionType: SessionCatalogType,
        currencyCode: String,
        scheduledAt: Date
    ) -> Decimal? {
        guard let context = resolveContext(preferred: sessionType.modelContext) else {
            return resolveCatalogPriceInMemory(
                sessionType: sessionType,
                currencyCode: currencyCode,
                scheduledAt: scheduledAt
            )
        }

        let typeID = sessionType.id
        let descriptor = FetchDescriptor<SessionTypePriceVersion>(
            predicate: #Predicate<SessionTypePriceVersion> { version in
                version.sessionCatalogType?.id == typeID
                && version.currencyCode == currencyCode
                && version.effectiveFrom <= scheduledAt
            },
            sortBy: [
                SortDescriptor(\SessionTypePriceVersion.effectiveFrom, order: .reverse),
                SortDescriptor(\SessionTypePriceVersion.updatedAt, order: .reverse),
            ]
        )

        do {
            return try context.fetch(descriptor).first?.price
        } catch {
            return resolveCatalogPriceInMemory(
                sessionType: sessionType,
                currencyCode: currencyCode,
                scheduledAt: scheduledAt
            )
        }
    }

    private func resolveCatalogPriceInMemory(
        sessionType: SessionCatalogType,
        currencyCode: String,
        scheduledAt: Date
    ) -> Decimal? {
        (sessionType.priceVersions ?? [])
            .filter {
                $0.currencyCode == currencyCode
                && $0.effectiveFrom <= scheduledAt
            }
            .sorted { lhs, rhs in
                if lhs.effectiveFrom == rhs.effectiveFrom {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.effectiveFrom > rhs.effectiveFrom
            }
            .first?.price
    }
}
