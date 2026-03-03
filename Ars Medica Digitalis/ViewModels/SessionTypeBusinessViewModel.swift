//
//  SessionTypeBusinessViewModel.swift
//  Ars Medica Digitalis
//
//  Puente estructural entre la UI futura y el motor económico.
//  Expone snapshots ya calculados sin duplicar reglas de negocio.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SessionTypeBusinessViewModel {

    /// Contexto de SwiftData inyectado desde la capa superior.
    /// Se conserva en el ViewModel para que cada refresh lea el mismo grafo
    /// persistido que está usando la pantalla anfitriona.
    private let context: ModelContext

    /// Servicio de negocio sin estado interno.
    /// Toda la inteligencia económica vive ahí para que el ViewModel solo
    /// coordine carga async y publicación de resultados.
    private let service: SessionTypeBusinessService

    /// Profesional explícito dueño del tablero económico.
    /// Lo recibimos desde la capa superior para eliminar la suposición de
    /// "un profesional por contexto" y dejar la arquitectura lista para crecer.
    private let professional: Professional

    /// Fecha de referencia opcional de evaluación.
    /// En app real queda nil para usar "ahora" en cada refresh y evitar que
    /// una versión recién creada quede invisible por una fecha capturada antes.
    /// En tests se puede fijar para mantener escenarios determinísticos.
    private let referenceDate: Date?

    /// Snapshots listos para consumo de UI.
    /// Son DTOs ya resueltos para evitar cálculos repetidos en la capa visual.
    var snapshots: [SessionTypeBusinessSnapshot] = []

    init(
        professional: Professional,
        context: ModelContext,
        service: SessionTypeBusinessService? = nil,
        referenceDate: Date? = nil
    ) {
        self.professional = professional
        self.context = context
        self.service = service ?? SessionTypeBusinessService()
        self.referenceDate = referenceDate
    }

    /// Refresca los snapshots económicos del profesional explícito.
    /// No usa cache interno para que cada ejecución refleje cambios recientes
    /// de política, IPC mock o versionado de honorarios sin depender de
    /// búsquedas implícitas dentro del contexto.
    func refresh() async throws {
        let evaluationDate = referenceDate ?? Date()
        snapshots = try await service.businessSnapshots(
            for: professional,
            context: context,
            at: evaluationDate
        )
    }
}
