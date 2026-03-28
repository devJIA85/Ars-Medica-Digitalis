//
//  Patient.swift
//  Ars Medica Digitalis
//
//  Sujeto central de la historia clínica.
//  Implementa borrado lógico mediante deletedAt — nunca se elimina físicamente
//  porque la historia clínica es un documento médico-legal.
//

import Foundation
import SwiftData

@Model
final class Patient: SoftDeletable {

    var id: UUID = UUID()

    // MARK: - Datos demográficos básicos

    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Date()
    var biologicalSex: String = ""      // "masculino" | "femenino" | "intersexual"
    var nationalId: String = ""         // ⚠️ CRÍTICO — dato de identidad sensible

    // MARK: - Datos personales expandidos

    /// Identidad de género — separado de sexo biológico
    /// para respetar la distinción clínica y legal
    var gender: String = ""             // "masculino" | "femenino" | "no binario" | "otro"
    var nationality: String = ""
    var residenceCountry: String = ""   // Para determinar huso horario en teleconsultas
    var occupation: String = ""
    var educationLevel: String = ""     // "primario" | "secundario" | "terciario" | "universitario" | "posgrado"
    var maritalStatus: String = ""      // "soltero/a" | "en pareja" | "casado/a" | "divorciado/a" | "viudo/a"

    // MARK: - Contacto

    var email: String = ""              // ⚠️ Sensible
    var phoneNumber: String = ""        // ⚠️ Sensible
    var address: String = ""

    // MARK: - Contacto de emergencia
    // Tres campos escalares en vez de modelo separado:
    // un solo contacto por paciente, no es un registro repetitivo.

    var emergencyContactName: String = ""
    var emergencyContactPhone: String = ""
    var emergencyContactRelation: String = ""  // "padre/madre" | "cónyuge" | "hermano/a" | "hijo/a" | "otro"

    // MARK: - Cobertura médica

    var healthInsurance: String = ""        // Obra social
    var insuranceMemberNumber: String = ""  // Número de afiliado
    var insurancePlan: String = ""          // Plan

    // MARK: - Foto de perfil
    // Thumbnail redimensionado (~200x200px, <100KB) para no exceder
    // el límite de 1MB por registro CloudKit.
    // .externalStorage le indica a SwiftData que guarde el blob
    // como archivo externo en vez de inline en SQLite.

    @Attribute(.externalStorage)
    var photoData: Data? = nil

    // MARK: - Estado clínico
    // Indicador visual del estado general del paciente.
    // Se refleja como anillo de color en el avatar:
    // verde (estable), naranja (activo), rojo (riesgo).
    var clinicalStatus: String = ClinicalStatusMapping.estable.rawValue  // "estable" | "activo" | "riesgo"

    // MARK: - Historia clínica

    /// Número autogenerado "HC-XXXXXXXX" al crear el paciente.
    /// Formato legible y único para identificar la historia clínica.
    var medicalRecordNumber: String = ""

    /// Medicación actual del paciente (texto libre)
    var currentMedication: String = ""

    /// Medicación actual seleccionada desde el vademécum local.
    @Relationship(deleteRule: .nullify, inverse: \Medication.patients)
    var currentMedications: [Medication] = []

    // MARK: - Antropometría

    var weightKg: Double = 0        // Peso en kilogramos
    var heightCm: Double = 0        // Altura en centímetros
    var waistCm: Double = 0         // Cintura en centímetros

    // MARK: - Estilo de vida

    var smokingStatus: Bool = false
    var alcoholUse: Bool = false
    var drugUse: Bool = false
    var routineCheckups: Bool = false    // Chequeos médicos de rutina

    // MARK: - Antecedentes familiares
    // Bools individuales: funcionan naturalmente con Toggle bindings,
    // no requieren parseo, y #Predicate puede filtrar por cada uno.

    var familyHistoryHTA: Bool = false
    var familyHistoryACV: Bool = false
    var familyHistoryCancer: Bool = false
    var familyHistoryDiabetes: Bool = false
    var familyHistoryHeartDisease: Bool = false
    var familyHistoryMentalHealth: Bool = false
    var familyHistoryOther: String = ""     // Texto libre para antecedentes no listados

    // MARK: - Genograma
    // PKDrawing serializado como Data. PencilKit es Codable,
    // lo que permite guardar/restaurar dibujos de forma trivial.

    @Attribute(.externalStorage)
    var genogramData: Data? = nil

    // MARK: - Borrado lógico (SoftDeletable)
    // Cuando deletedAt != nil, el paciente está inactivo.
    // El #Predicate filtra { $0.deletedAt == nil } en la vista principal.
    // CloudKit conserva el registro histórico sin excepción.

    var deletedAt: Date? = nil
    var deletedBy: String? = nil
    var deletionReason: String? = nil

    // MARK: - Trazabilidad

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Moneda vigente de compatibilidad.
    /// Se mantiene como fallback rápido mientras convive con el historial
    /// de PatientCurrencyVersion, que es la fuente principal por fecha.
    var currencyCode: String = ""

    // MARK: - Relaciones

    var professional: Professional? = nil

    @Relationship(deleteRule: .cascade, inverse: \Session.patient)
    var sessions: [Session] = []

    /// Colección persistida de TODOS los diagnósticos del paciente — activos y soft-deleted.
    /// Es el lado de navegación de la relación SwiftData/CloudKit cuya foreign key
    /// vive en Diagnosis.patient. El nombre refleja que no filtra por estado.
    ///
    /// ⚠️  ACCESO RESTRINGIDO — No leer directamente fuera de Patient.swift.
    /// Toda la lógica de UI, exportaciones y dominio debe usar `activeDiagnoses`
    /// (computed property que filtra `deletedAt == nil`) o una query con #Predicate.
    /// Acceder a `allDiagnoses` directamente es un bug silencioso: expone registros
    /// dados de baja que no deben aparecer en la historia clínica activa.
    @Relationship(deleteRule: .cascade, inverse: \Diagnosis.patient)
    private(set) var allDiagnoses: [Diagnosis] = []

    /// Antecedentes de tratamientos previos (psicoterapia, psiquiatría, etc.)
    @Relationship(deleteRule: .cascade, inverse: \PriorTreatment.patient)
    var priorTreatments: [PriorTreatment] = []

    /// Internaciones previas del paciente
    @Relationship(deleteRule: .cascade, inverse: \Hospitalization.patient)
    var hospitalizations: [Hospitalization] = []

    /// Registros históricos de antropometría para graficar evolución
    /// con Swift Charts (peso, IMC, cintura a lo largo del tiempo)
    @Relationship(deleteRule: .cascade, inverse: \AnthropometricRecord.patient)
    var anthropometricRecords: [AnthropometricRecord] = []

    // Flujo de configuración financiera del paciente:
    // Patient -> PatientCurrencyVersion para moneda vigente por fecha.
    // Patient -> PatientSessionDefaultPrice para precios por defecto por tipo.
    // Se agrega separado del dominio clínico para no alterar los formularios actuales.
    @Relationship(deleteRule: .cascade, inverse: \PatientCurrencyVersion.patient)
    var currencyVersions: [PatientCurrencyVersion] = []

    @Relationship(deleteRule: .cascade, inverse: \PatientSessionDefaultPrice.patient)
    var sessionDefaultPrices: [PatientSessionDefaultPrice] = []

    // MARK: - Computed properties (no se persisten)

    var fullName: String { "\(firstName) \(lastName)" }
    /// Resume si el paciente mantiene deuda en sesiones ya completadas.
    @MainActor
    var hasOutstandingDebt: Bool {
        debtByCurrency.isEmpty == false
    }

    /// Agrupa la deuda pendiente del paciente por moneda efectiva.
    ///
    /// El cálculo es puramente in-memory sobre la relación `sessions` ya
    /// cargada: no dispara FetchDescriptors adicionales dentro del modelo,
    /// eliminando el patrón N+1 cuando se llama sobre listas de pacientes.
    /// Prioriza snapshots congelados al completar, pero conserva compatibilidad
    /// con sesiones históricas que quedaron completadas sin snapshot final,
    /// usando `effectivePrice` y `effectiveCurrency` como fallback.
    @MainActor
    var debtByCurrency: [PatientDebtCurrencySummary] {
        let groupedDebt = sessions
            .filter { $0.sessionStatusValue == .completada }
            .reduce(into: [String: (debt: Decimal, sessionCount: Int)]()) { result, session in
                let price = session.finalPriceSnapshot ?? session.effectivePrice
                guard price > 0 else { return }

                let currency: String
                if let finalCurrency = session.finalCurrencySnapshot, !finalCurrency.isEmpty {
                    currency = finalCurrency
                } else {
                    currency = session.effectiveCurrency
                }
                guard !currency.isEmpty else { return }

                let paid = session.totalPaid
                let remaining = price - paid
                guard remaining > 0 else { return }

                let current = result[currency] ?? (0, 0)
                result[currency] = (current.debt + remaining, current.sessionCount + 1)
            }

        return groupedDebt.map { currencyCode, value in
            PatientDebtCurrencySummary(
                currencyCode: currencyCode,
                debt: value.debt,
                sessionCount: value.sessionCount
            )
        }
        .sorted { lhs, rhs in
            lhs.debt != rhs.debt ? lhs.debt > rhs.debt : lhs.currencyCode < rhs.currencyCode
        }
    }

    /// Edad calculada desde la fecha de nacimiento
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    /// Próximo cumpleaños del paciente
    var nextBirthday: Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = calendar.dateComponents([.month, .day], from: dateOfBirth)
        components.year = calendar.component(.year, from: today)
        guard let thisYearBirthday = calendar.date(from: components) else { return nil }
        if thisYearBirthday >= today {
            return thisYearBirthday
        }
        // Ya pasó este año → siguiente año
        components.year = calendar.component(.year, from: today) + 1
        return calendar.date(from: components)
    }

    /// IMC calculado automáticamente. Nil si faltan peso o altura.
    var bmi: Double? {
        calculateBMI(weightKg: weightKg, heightCm: heightCm)
    }

    /// Acceso tipado para estado clinico sin romper compatibilidad de persistencia.
    var clinicalStatusValue: ClinicalStatusMapping {
        get { ClinicalStatusMapping(clinicalStatusRawValue: clinicalStatus) ?? .estable }
        set { clinicalStatus = newValue.rawValue }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        dateOfBirth: Date = Date(),
        biologicalSex: String = "",
        gender: String = "",
        nationality: String = "",
        residenceCountry: String = "",
        occupation: String = "",
        educationLevel: String = "",
        maritalStatus: String = "",
        nationalId: String = "",
        email: String = "",
        phoneNumber: String = "",
        address: String = "",
        emergencyContactName: String = "",
        emergencyContactPhone: String = "",
        emergencyContactRelation: String = "",
        healthInsurance: String = "",
        insuranceMemberNumber: String = "",
        insurancePlan: String = "",
        photoData: Data? = nil,
        clinicalStatus: String = ClinicalStatusMapping.estable.rawValue,
        medicalRecordNumber: String = "",
        currentMedication: String = "",
        currentMedications: [Medication] = [],
        weightKg: Double = 0,
        heightCm: Double = 0,
        waistCm: Double = 0,
        smokingStatus: Bool = false,
        alcoholUse: Bool = false,
        drugUse: Bool = false,
        routineCheckups: Bool = false,
        familyHistoryHTA: Bool = false,
        familyHistoryACV: Bool = false,
        familyHistoryCancer: Bool = false,
        familyHistoryDiabetes: Bool = false,
        familyHistoryHeartDisease: Bool = false,
        familyHistoryMentalHealth: Bool = false,
        familyHistoryOther: String = "",
        genogramData: Data? = nil,
        deletedAt: Date? = nil,
        deletedBy: String? = nil,
        deletionReason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        currencyCode: String = "",
        professional: Professional? = nil,
        sessions: [Session] = [],
        allDiagnoses: [Diagnosis] = [],
        priorTreatments: [PriorTreatment] = [],
        hospitalizations: [Hospitalization] = [],
        anthropometricRecords: [AnthropometricRecord] = [],
        currencyVersions: [PatientCurrencyVersion] = [],
        sessionDefaultPrices: [PatientSessionDefaultPrice] = []
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.gender = gender
        self.nationality = nationality
        self.residenceCountry = residenceCountry
        self.occupation = occupation
        self.educationLevel = educationLevel
        self.maritalStatus = maritalStatus
        self.nationalId = nationalId
        self.email = email
        self.phoneNumber = phoneNumber
        self.address = address
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.emergencyContactRelation = emergencyContactRelation
        self.healthInsurance = healthInsurance
        self.insuranceMemberNumber = insuranceMemberNumber
        self.insurancePlan = insurancePlan
        self.photoData = photoData
        self.clinicalStatus = clinicalStatus
        self.medicalRecordNumber = medicalRecordNumber
        self.currentMedication = currentMedication
        self.currentMedications = currentMedications
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.waistCm = waistCm
        self.smokingStatus = smokingStatus
        self.alcoholUse = alcoholUse
        self.drugUse = drugUse
        self.routineCheckups = routineCheckups
        self.familyHistoryHTA = familyHistoryHTA
        self.familyHistoryACV = familyHistoryACV
        self.familyHistoryCancer = familyHistoryCancer
        self.familyHistoryDiabetes = familyHistoryDiabetes
        self.familyHistoryHeartDisease = familyHistoryHeartDisease
        self.familyHistoryMentalHealth = familyHistoryMentalHealth
        self.familyHistoryOther = familyHistoryOther
        self.genogramData = genogramData
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
        self.deletionReason = deletionReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.currencyCode = currencyCode
        self.professional = professional
        self.sessions = sessions
        self.allDiagnoses = allDiagnoses
        self.priorTreatments = priorTreatments
        self.hospitalizations = hospitalizations
        self.anthropometricRecords = anthropometricRecords
        self.currencyVersions = currencyVersions
        self.sessionDefaultPrices = sessionDefaultPrices
    }
}

// MARK: - Auditable

extension Patient: Auditable {
    var entityID: UUID { id }
    var auditEntityType: AuditEntityType { .patient }
}

extension Patient {

    // MARK: - Vistas filtradas de relaciones clínicas
    //
    // Filtros ejecutados en memoria sobre las relaciones ya cargadas por SwiftData.
    // Son correctos para listas pequeñas (diagnósticos, tratamientos, internaciones
    // por paciente) donde la relación entera está disponible en el contexto.
    //
    // Limitación: no reducen el conjunto de objetos que SwiftData trae del store —
    // todos los ítems de la relación se cargan, independientemente de `deletedAt`.
    // En el futuro, si el volumen crece, migrar a #Predicate en un FetchDescriptor
    // separado para evitar cargar registros inactivos en memoria.

    /// Diagnósticos activos del paciente — excluye soft-deleted.
    /// Usar en toda la UI, exportaciones y lógica de dominio.
    /// La relación persistida completa (incluye inactivos) es `allDiagnoses`.
    var activeDiagnoses: [Diagnosis] {
        allDiagnoses.filter { $0.isActive }
    }

    /// Tratamientos previos activos — excluye soft-deleted.
    var activePriorTreatments: [PriorTreatment] {
        priorTreatments.filter { $0.isActive }
    }

    /// Internaciones activas — excluye soft-deleted.
    var activeHospitalizations: [Hospitalization] {
        hospitalizations.filter { $0.isActive }
    }

    // MARK: - Borrado lógico
    //
    // softDelete() y restore() actualizan `updatedAt` en el propio paciente y en
    // todos los registros hijos afectados, para que el token de refresco del
    // dashboard detecte el cambio en el mismo ciclo de render.

    /// Marca el paciente como inactivo y propaga la baja a todos los registros
    /// clínicos activos: diagnósticos, tratamientos e internaciones.
    /// Los registros ya inactivos antes de esta llamada conservan su `deletedAt` original.
    /// `restore()` NO propaga la restauración — requiere acción manual por registro.
    func softDelete(by actor: String? = nil, reason: String? = nil) {
        let now = Date()
        deletedAt = now
        updatedAt = now
        deletedBy = actor
        deletionReason = reason

        // Cascada solo sobre los registros activos al momento de la baja.
        activeDiagnoses.forEach { $0.softDelete(by: actor, reason: reason) }
        activePriorTreatments.forEach { $0.softDelete(by: actor, reason: reason) }
        activeHospitalizations.forEach { $0.softDelete(by: actor, reason: reason) }
    }

    func restore() {
        deletedAt = nil
        updatedAt = Date()
        deletedBy = nil
        deletionReason = nil
        // No se restauran los registros hijos: la reactivación clínica es manual.
    }
}
