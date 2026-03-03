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
    private let calendar: Calendar

    init(modelContext: ModelContext? = nil, calendar: Calendar = .current) {
        self.modelContext = modelContext
        self.calendar = calendar
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
        let draft = SessionFinancialDraft(
            scheduledAt: session.scheduledAt,
            patient: session.patient,
            financialSessionType: session.financialSessionType,
            isCourtesy: session.isCourtesy,
            isCompleted: session.isCompleted
        )
        return resolveDynamicPrice(for: draft)
    }

    /// Resuelve el precio dinámico de un borrador puro sin instanciar Session.
    /// Esto evita que SwiftData interprete previews y validaciones como datos
    /// persistibles cuando el formulario recalcula estados financieros.
    func resolveDynamicPrice(for draft: SessionFinancialDraft) -> Decimal {
        if draft.isCourtesy {
            return 0
        }

        guard let patient = draft.patient,
              let sessionType = draft.financialSessionType else {
            return 0
        }

        let currency = resolveEffectiveCurrency(for: draft)
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
            scheduledAt: draft.scheduledAt
        ) {
            return catalogPrice
        }

        if let siblingCatalogPrice = resolveSiblingCatalogPrice(
            sessionType: sessionType,
            currencyCode: currency,
            scheduledAt: draft.scheduledAt
        ) {
            return siblingCatalogPrice
        }

        return 0
    }

    /// Resuelve la moneda efectiva de un borrador financiero puro.
    /// Mantener esta API separada evita usar Session @Model para previews.
    func resolveEffectiveCurrency(for draft: SessionFinancialDraft) -> String {
        guard let patient = draft.patient else {
            return ""
        }

        return resolveCurrency(for: patient, at: draft.scheduledAt)
    }

    /// Indica si un tipo facturable tiene algún honorario resoluble para la
    /// moneda vigente del paciente en la fecha de la sesión. Se usa para que
    /// la UI no ofrezca opciones incompatibles que después terminan en error.
    func canResolvePrice(for draft: SessionFinancialDraft) -> Bool {
        let currency = resolveEffectiveCurrency(for: draft)
        guard currency.isEmpty == false else {
            return false
        }

        return resolveDynamicPrice(for: draft) > 0
    }

    /// Compatibilidad con el contrato actual del ViewModel.
    /// Internamente se delega al borrador puro para no crear Session temporales.
    func canResolvePrice(
        for patient: Patient,
        sessionType: SessionCatalogType,
        scheduledAt: Date
    ) -> Bool {
        let draft = SessionFinancialDraft(
            scheduledAt: scheduledAt,
            patient: patient,
            financialSessionType: sessionType,
            isCourtesy: false,
            isCompleted: false
        )

        return canResolvePrice(for: draft)
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
            },
            sortBy: [
                SortDescriptor(\SessionTypePriceVersion.effectiveFrom, order: .reverse),
                SortDescriptor(\SessionTypePriceVersion.updatedAt, order: .reverse),
            ]
        )

        do {
            let versions = try context.fetch(descriptor)
            return resolveCatalogPriceVersion(
                from: versions,
                scheduledAt: scheduledAt
            )?.price
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
        let versions = (sessionType.priceVersions ?? [])
            .filter { $0.currencyCode == currencyCode }

        return resolveCatalogPriceVersion(
            from: versions,
            scheduledAt: scheduledAt
        )?.price
    }

    /// Compatibiliza catálogos ya duplicados por nombre.
    /// Si el tipo seleccionado no tiene precio en la moneda del paciente,
    /// buscamos un tipo hermano del mismo profesional con el mismo nombre
    /// lógico para reutilizar su versión y no bloquear el cobro.
    private func resolveSiblingCatalogPrice(
        sessionType: SessionCatalogType,
        currencyCode: String,
        scheduledAt: Date
    ) -> Decimal? {
        guard let professional = sessionType.professional else {
            return nil
        }

        let normalizedName = normalizedSessionTypeName(sessionType.name)
        let siblingTypes = fetchSessionCatalogTypes(for: professional)
            .filter { candidate in
                candidate.id != sessionType.id
                && candidate.isActive
                && normalizedSessionTypeName(candidate.name) == normalizedName
            }

        for siblingType in siblingTypes {
            if let siblingPrice = resolveCatalogPrice(
                sessionType: siblingType,
                currencyCode: currencyCode,
                scheduledAt: scheduledAt
            ) {
                return siblingPrice
            }
        }

        return nil
    }

    /// Resuelve la versión de honorario que corresponde a la sesión.
    /// Primero respeta la versión vigente para la fecha programada y, si no existe
    /// una anterior, cae al primer honorario disponible de esa moneda. Ese fallback
    /// evita dejar sesiones históricas sin cobrar cuando el profesional configuró
    /// su primer precio después de haber atendido al paciente.
    private func resolveCatalogPriceVersion(
        from versions: [SessionTypePriceVersion],
        scheduledAt: Date
    ) -> SessionTypePriceVersion? {
        guard versions.isEmpty == false else {
            return nil
        }

        let scheduledDay = scheduledAt.startOfDayDate(calendar: calendar)
        let sortedByEffectiveDateDescending = versions.sorted { lhs, rhs in
            if lhs.effectiveFrom == rhs.effectiveFrom {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.effectiveFrom > rhs.effectiveFrom
        }

        if let currentVersion = sortedByEffectiveDateDescending.first(where: { version in
            version.effectiveFrom.startOfDayDate(calendar: calendar) <= scheduledDay
        }) {
            return currentVersion
        }

        return versions.min { lhs, rhs in
            let lhsDay = lhs.effectiveFrom.startOfDayDate(calendar: calendar)
            let rhsDay = rhs.effectiveFrom.startOfDayDate(calendar: calendar)

            if lhsDay == rhsDay {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhsDay < rhsDay
        }
    }

    /// Lee el catálogo desde SwiftData para no depender de que la relación
    /// del Professional ya esté materializada en memoria al momento de cobrar.
    private func fetchSessionCatalogTypes(for professional: Professional) -> [SessionCatalogType] {
        guard let context = resolveContext(preferred: professional.modelContext) else {
            return professional.sessionCatalogTypes ?? []
        }

        let professionalID = professional.id
        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.professional?.id == professionalID
            },
            sortBy: [
                SortDescriptor(\SessionCatalogType.sortOrder),
                SortDescriptor(\SessionCatalogType.createdAt),
            ]
        )

        return (try? context.fetch(descriptor)) ?? (professional.sessionCatalogTypes ?? [])
    }

    private func normalizedSessionTypeName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
