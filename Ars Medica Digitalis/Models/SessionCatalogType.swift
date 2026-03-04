//
//  SessionCatalogType.swift
//  Ars Medica Digitalis
//
//  Catálogo financiero de tipos de sesión definido por el profesional.
//  Se separa de la modalidad clínica para no mezclar agenda con facturación.
//

import Foundation
import SwiftData

@Model
final class SessionCatalogType {

    var id: UUID = UUID()

    /// Nombre visible del tipo facturable.
    /// Vive fuera de Session.sessionType porque ese campo sigue siendo clínico.
    var name: String = ""

    /// Identidad visual reusable para listas, agenda y reportes.
    var iconSystemName: String = SessionTypeSymbolCatalog.defaultSymbolName
    var colorToken: String = SessionTypeColorToken.blue.rawValue

    /// Permite ocultar tipos viejos sin borrar historial asociado.
    var isActive: Bool = true

    /// Orden manual para presentar el catálogo de forma estable en la UI.
    var sortOrder: Int = 0

    // Trazabilidad administrativa
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Flujo base del módulo financiero:
    // Professional -> SessionCatalogType -> SessionTypePriceVersion.
    // El catálogo pertenece al profesional, sus versiones de precio cuelgan
    // de este nodo y las sesiones lo referencian sin tocar la modalidad clínica.
    var professional: Professional? = nil

    @Relationship(deleteRule: .cascade, inverse: \SessionTypePriceVersion.sessionCatalogType)
    var priceVersions: [SessionTypePriceVersion]? = []

    @Relationship(deleteRule: .cascade, inverse: \PatientSessionDefaultPrice.sessionCatalogType)
    var patientDefaultPrices: [PatientSessionDefaultPrice]? = []

    @Relationship(deleteRule: .nullify, inverse: \Session.financialSessionType)
    var sessions: [Session]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        iconSystemName: String = SessionTypeSymbolCatalog.defaultSymbolName,
        colorToken: String = SessionTypeColorToken.blue.rawValue,
        isActive: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        professional: Professional? = nil,
        priceVersions: [SessionTypePriceVersion]? = [],
        patientDefaultPrices: [PatientSessionDefaultPrice]? = [],
        sessions: [Session]? = []
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.colorToken = colorToken
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.professional = professional
        self.priceVersions = priceVersions
        self.patientDefaultPrices = patientDefaultPrices
        self.sessions = sessions
    }
}
