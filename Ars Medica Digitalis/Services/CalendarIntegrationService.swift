//
//  CalendarIntegrationService.swift
//  Ars Medica Digitalis
//
//  Sincroniza sesiones clínicas con el calendario nativo (EventKit)
//  usando APIs async/await y acceso serializado al EKEventStore.
//

import EventKit
import Foundation

nonisolated enum CalendarAuthorizationState: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case fullAccess

    var canWriteEvents: Bool {
        self == .writeOnly || self == .fullAccess
    }

    var isDisabled: Bool {
        self == .denied || self == .restricted
    }
}

enum CalendarIntegrationError: LocalizedError, Sendable {
    case accessDenied
    case calendarUnavailable
    case invalidEventIdentifier

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "No hay permisos para acceder al calendario."
        case .calendarUnavailable:
            return "No se encontró un calendario válido para guardar el evento."
        case .invalidEventIdentifier:
            return "No se encontró un identificador de evento válido."
        }
    }
}

/// Deep links estables para abrir sesiones desde EventKit.
enum SessionDeepLink {
    static let scheme = "arsmedicadigitalis"
    private static let host = "session"

    static func url(for sessionID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(sessionID.uuidString)"
        if let url = components.url {
            return url
        }

        return URL(string: "\(scheme)://\(host)/\(sessionID.uuidString)")!
    }

    static func sessionID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme else {
            return nil
        }

        let lowercasedHost = url.host?.lowercased()
        guard lowercasedHost == host || lowercasedHost == "sessions" else {
            return nil
        }

        let identifier = url.pathComponents
            .filter { $0 != "/" }
            .last

        guard let identifier else {
            return nil
        }

        return UUID(uuidString: identifier)
    }
}

struct SessionCalendarEventPayload: Sendable {
    let sessionID: UUID
    let calendarEventIdentifier: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String
    let deepLinkURL: URL
}

@MainActor
extension SessionCalendarEventPayload {
    init(session: Session) {
        let patientName = session.patient?.fullName.trimmed
        let resolvedPatientName: String
        if let patientName, patientName.isEmpty == false {
            resolvedPatientName = patientName
        } else {
            resolvedPatientName = "Paciente"
        }

        self.sessionID = session.id
        self.calendarEventIdentifier = session.calendarEventIdentifier
        self.title = "Session – \(resolvedPatientName)"
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.notes = Self.composeNotes(
            clinicalNotes: session.notes,
            treatmentPlan: session.treatmentPlan
        )
        self.deepLinkURL = SessionDeepLink.url(for: session.id)
    }

    private static func composeNotes(clinicalNotes: String, treatmentPlan: String) -> String {
        let cleanedNotes = clinicalNotes.trimmed
        let cleanedPlan = treatmentPlan.trimmed

        switch (cleanedNotes.isEmpty, cleanedPlan.isEmpty) {
        case (false, false):
            return "\(cleanedNotes)\n\nPlan:\n\(cleanedPlan)"
        case (false, true):
            return cleanedNotes
        case (true, false):
            return cleanedPlan
        case (true, true):
            return ""
        }
    }
}

/// Wrapper reusable para EventKit.
/// Expone métodos con `Session` para la UI y métodos con payload puro para
/// reuso futuro (sugerencias automáticas, IA y recordatorios).
final class CalendarIntegrationService {

    private static let preferredCalendarIdentifierDefaultsKey = "calendar.preferred.identifier"

    private let worker: CalendarEventStoreWorker
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedIdentifier = userDefaults.string(
            forKey: Self.preferredCalendarIdentifierDefaultsKey
        )
        self.worker = CalendarEventStoreWorker(
            preferredCalendarIdentifier: storedIdentifier
        )
    }

    func authorizationStatus() async -> CalendarAuthorizationState {
        await worker.authorizationStatus()
    }

    /// Solicita acceso full-access moderno para permitir altas/ediciones/bajas.
    @MainActor
    func requestAccess() async -> CalendarAuthorizationState {
        let currentStatus = await worker.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        let permissionStore = EKEventStore()

        do {
            _ = try await permissionStore.requestFullAccessToEvents()
        } catch {
            // Fallback defensivo para sistemas que puedan ofrecer write-only.
            do {
                _ = try await permissionStore.requestWriteOnlyAccessToEvents()
            } catch {
                // Si ambos caminos fallan, usamos el estado reportado por el sistema.
            }
        }

        // Algunos entornos reportan el cambio con demora tras cerrar el prompt.
        let updatedStatus = await worker.authorizationStatus()
        if updatedStatus == .notDetermined {
            try? await Task.sleep(for: .milliseconds(180))
            return await worker.authorizationStatus()
        }

        return updatedStatus
    }

    /// Persiste la preferencia de calendario para futuras integraciones.
    func setPreferredCalendarIdentifier(_ identifier: String?) async {
        await worker.setPreferredCalendarIdentifier(identifier)
        if let identifier, identifier.isEmpty == false {
            userDefaults.set(identifier, forKey: Self.preferredCalendarIdentifierDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: Self.preferredCalendarIdentifierDefaultsKey)
        }
    }

    /// Devuelve el calendario activo (preferido o default del sistema).
    func activeCalendarIdentifier() async -> String? {
        await worker.activeCalendarIdentifier()
    }

    /// Calendario preferido persistido para sesiones clínicas.
    func preferredCalendarIdentifier() async -> String? {
        await worker.preferredCalendarIdentifierValue()
    }

    /// Crea un calendario dedicado para la app y lo deja seleccionado.
    func createSuggestedCalendar(named name: String) async throws -> String {
        let identifier = try await worker.createCalendar(named: name)
        await setPreferredCalendarIdentifier(identifier)
        return identifier
    }

    func createEvent(for payload: SessionCalendarEventPayload) async throws -> String {
        let preferredCalendarIdentifier = await worker.preferredCalendarIdentifierValue()
        return try await worker.createEvent(
            from: payload,
            calendarIdentifier: preferredCalendarIdentifier
        )
    }

    /// Si el evento no existe, crea uno nuevo para mantener la sincronización.
    func updateEvent(for payload: SessionCalendarEventPayload) async throws -> String {
        let preferredCalendarIdentifier = await worker.preferredCalendarIdentifierValue()
        return try await worker.updateEvent(
            from: payload,
            calendarIdentifier: preferredCalendarIdentifier
        )
    }

    func deleteEvent(identifier: String) async throws {
        try await worker.deleteEvent(identifier: identifier)
    }

    @MainActor
    func createEvent(for session: Session) async throws -> String {
        try await createEvent(for: SessionCalendarEventPayload(session: session))
    }

    @MainActor
    func updateEvent(for session: Session) async throws -> String {
        try await updateEvent(for: SessionCalendarEventPayload(session: session))
    }

    @MainActor
    func deleteEvent(for session: Session) async throws {
        guard let identifier = session.calendarEventIdentifier, identifier.isEmpty == false else {
            throw CalendarIntegrationError.invalidEventIdentifier
        }

        try await deleteEvent(identifier: identifier)
    }
}

actor CalendarEventStoreWorker {

    private let eventStore = EKEventStore()
    private var preferredCalendarIdentifier: String?

    init(preferredCalendarIdentifier: String?) {
        self.preferredCalendarIdentifier = preferredCalendarIdentifier
    }

    func authorizationStatus() -> CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .authorized:
            // Compatibilidad con APIs legadas.
            return .fullAccess
        @unknown default:
            return .denied
        }
    }

    func setPreferredCalendarIdentifier(_ identifier: String?) {
        preferredCalendarIdentifier = identifier
    }

    func preferredCalendarIdentifierValue() -> String? {
        preferredCalendarIdentifier
    }

    func activeCalendarIdentifier() -> String? {
        if let preferredCalendarIdentifier,
           eventStore.calendar(withIdentifier: preferredCalendarIdentifier) != nil {
            return preferredCalendarIdentifier
        }

        return eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    }

    func createEvent(
        from payload: SessionCalendarEventPayload,
        calendarIdentifier: String?
    ) throws -> String {
        try ensureWriteAccess()
        let event = EKEvent(eventStore: eventStore)
        try apply(payload, to: event, calendarIdentifier: calendarIdentifier)
        try eventStore.save(event, span: .thisEvent, commit: true)
        guard let eventIdentifier = event.eventIdentifier else {
            throw CalendarIntegrationError.invalidEventIdentifier
        }
        return eventIdentifier
    }

    func updateEvent(
        from payload: SessionCalendarEventPayload,
        calendarIdentifier: String?
    ) throws -> String {
        try ensureWriteAccess()

        if let existingIdentifier = payload.calendarEventIdentifier,
           let existingEvent = eventStore.event(withIdentifier: existingIdentifier) {
            try apply(payload, to: existingEvent, calendarIdentifier: calendarIdentifier)
            try eventStore.save(existingEvent, span: .thisEvent, commit: true)
            guard let eventIdentifier = existingEvent.eventIdentifier else {
                throw CalendarIntegrationError.invalidEventIdentifier
            }
            return eventIdentifier
        }

        return try createEvent(from: payload, calendarIdentifier: calendarIdentifier)
    }

    func deleteEvent(identifier: String) throws {
        try ensureWriteAccess()
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return
        }

        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    func createCalendar(named name: String) throws -> String {
        try ensureWriteAccess()

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        calendar.source = try resolvedSourceForNewCalendar()

        try eventStore.saveCalendar(calendar, commit: true)
        preferredCalendarIdentifier = calendar.calendarIdentifier
        return calendar.calendarIdentifier
    }

    private func ensureWriteAccess() throws {
        guard authorizationStatus().canWriteEvents else {
            throw CalendarIntegrationError.accessDenied
        }
    }

    private func resolvedCalendar(
        calendarIdentifier: String?
    ) throws -> EKCalendar {
        let candidateIdentifier = calendarIdentifier ?? preferredCalendarIdentifier
        if let candidateIdentifier,
           let calendar = eventStore.calendar(withIdentifier: candidateIdentifier) {
            return calendar
        }

        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            throw CalendarIntegrationError.calendarUnavailable
        }

        return defaultCalendar
    }

    private func resolvedSourceForNewCalendar() throws -> EKSource {
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            return source
        }

        if let source = eventStore.sources.first(
            where: { $0.sourceType == .calDAV || $0.sourceType == .local || $0.sourceType == .exchange }
        ) {
            return source
        }

        throw CalendarIntegrationError.calendarUnavailable
    }

    private func apply(
        _ payload: SessionCalendarEventPayload,
        to event: EKEvent,
        calendarIdentifier: String?
    ) throws {
        event.title = payload.title
        event.startDate = payload.startDate
        let minimumEndDate = payload.startDate.addingTimeInterval(60)
        event.endDate = max(payload.endDate, minimumEndDate)
        event.notes = payload.notes
        event.url = payload.deepLinkURL
        event.calendar = try resolvedCalendar(calendarIdentifier: calendarIdentifier)
    }
}
