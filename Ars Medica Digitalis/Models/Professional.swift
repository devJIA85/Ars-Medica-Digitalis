//
//  Professional.swift
//  Ars Medica Digitalis
//
//  Representa al profesional de salud propietario de la cuenta.
//  Es el anchor de todos los datos: todo viaja en su zona privada de CloudKit.
//

import Foundation
import SwiftData

@Model
final class Professional {

    // UUID generado en cliente para coherencia de identidad entre dispositivos,
    // antes de que CloudKit asigne su propio recordName.
    var id: UUID = UUID()

    // Datos de identidad profesional
    var fullName: String = ""
    var licenseNumber: String = ""   // ⚠️ Sensible — protegido por zona privada iCloud
    var specialty: String = ""       // Ej: "Psicología", "Odontología"
    var email: String = ""           // ⚠️ Sensible

    // Configuración regional para la API CIE-11 (Accept-Language header)
    var preferredLanguage: String = "es"

    // Moneda administrativa sugerida para pacientes nuevos.
    // Se guarda a nivel Professional para sembrar el alta inicial sin obligar
    // a repetir la misma elección en cada paciente recién creado.
    var defaultPatientCurrencyCode: String = ""

    // Tipo facturable sugerido para nuevas sesiones.
    // Se resuelve por UUID para evitar acoplar el Professional a una relación
    // extra y poder usarlo como preferencia liviana de captura.
    var defaultFinancialSessionTypeID: UUID? = nil

    // MARK: - Avatar

    // La configuración del avatar se serializa como JSON en un único campo Data?.
    // Esto reemplaza el esquema anterior de tres campos raw/string independientes.
    //
    // Ventajas:
    //   • Type safety: la lógica de encode/decode vive en AvatarConfiguration.
    //   • Evolución sin fragmentación: agregar metadatos no requiere nuevos campos de schema.
    //   • Data? es un tipo primitivo de CKRecord — mejor base para futura sync que strings dispersos.
    //
    // ATENCIÓN — CloudKit NO queda resuelto por este campo:
    //   Usar Data? es condición necesaria pero no suficiente. Antes de activar CloudKit
    //   habrá que validar schema (Dashboard), sync behavior, evolución entre versiones de app
    //   y compatibilidad del JSON Codable entre builds distintos. Ver nota en AvatarConfiguration.swift.
    //
    // nil = usar AvatarConfiguration.defaultValue (.predefined(style: .blue)).
    var avatarConfigData: Data? = nil

    // Trazabilidad: auditoría clínica y resolución de conflictos de sincronización
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // SwiftData modela relaciones to-many como colecciones vacías, no opcionales.
    @Relationship(deleteRule: .cascade, inverse: \Patient.professional)
    var patients: [Patient]! = []

    // Flujo base del módulo financiero:
    // Professional -> SessionCatalogType -> SessionTypePriceVersion.
    // El profesional administra su catálogo facturable sin alterar la modalidad
    // clínica ya persistida en Session.sessionType.
    @Relationship(deleteRule: .cascade, inverse: \SessionCatalogType.professional)
    var sessionCatalogTypes: [SessionCatalogType]! = []

    // Política global del motor de inteligencia económica:
    // Professional -> PricingAdjustmentPolicy.
    // Se separa del catálogo para gobernar sugerencias automáticas sin mezclar
    // reglas comerciales con cada versión individual de precio.
    @Relationship(deleteRule: .cascade, inverse: \PricingAdjustmentPolicy.professional)
    var pricingAdjustmentPolicy: PricingAdjustmentPolicy? = nil

    init(
        id: UUID = UUID(),
        fullName: String = "",
        licenseNumber: String = "",
        specialty: String = "",
        email: String = "",
        preferredLanguage: String = "es",
        defaultPatientCurrencyCode: String = "",
        defaultFinancialSessionTypeID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        patients: [Patient] = [],
        sessionCatalogTypes: [SessionCatalogType] = [],
        pricingAdjustmentPolicy: PricingAdjustmentPolicy? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.licenseNumber = licenseNumber
        self.specialty = specialty
        self.email = email
        self.preferredLanguage = preferredLanguage
        self.defaultPatientCurrencyCode = defaultPatientCurrencyCode
        self.defaultFinancialSessionTypeID = defaultFinancialSessionTypeID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patients = patients
        self.sessionCatalogTypes = sessionCatalogTypes
        self.pricingAdjustmentPolicy = pricingAdjustmentPolicy
    }
}

// MARK: - Avatar (computed — no almacenado)

extension Professional {

    /// Propiedad tipada que expone y escribe `AvatarConfiguration` sobre `avatarConfigData`.
    ///
    /// Getter: decodifica el JSON almacenado; devuelve `.defaultValue` si nil o inválido.
    /// Setter: serializa y persiste la nueva configuración en `avatarConfigData`.
    ///
    /// Usar esta propiedad en lugar de `avatarConfigData` directamente para garantizar
    /// type safety y encapsular la lógica de encode/decode en un único punto.
    var avatar: AvatarConfiguration {
        get { AvatarConfiguration.from(data: avatarConfigData) }
        set { avatarConfigData = newValue.encoded() }
    }
}
