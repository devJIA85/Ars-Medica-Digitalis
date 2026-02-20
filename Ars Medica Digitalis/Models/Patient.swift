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
final class Patient {

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
    var clinicalStatus: String = "estable"  // "estable" | "activo" | "riesgo"

    // MARK: - Historia clínica

    /// Número autogenerado "HC-XXXXXXXX" al crear el paciente.
    /// Formato legible y único para identificar la historia clínica.
    var medicalRecordNumber: String = ""

    /// Medicación actual del paciente (texto libre)
    var currentMedication: String = ""

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

    // MARK: - Borrado lógico
    // Cuando deletedAt != nil, el paciente está inactivo.
    // El #Predicate filtra { $0.deletedAt == nil } en la vista principal.
    // CloudKit conserva el registro histórico sin excepción.

    var deletedAt: Date? = nil

    // MARK: - Trazabilidad

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relaciones

    var professional: Professional? = nil

    @Relationship(deleteRule: .cascade, inverse: \Session.patient)
    var sessions: [Session]? = []

    /// Diagnósticos vigentes del paciente, editables directamente desde el perfil.
    /// Independientes de las sesiones — permiten agregar/quitar diagnósticos
    /// sin necesidad de crear una nueva sesión clínica.
    @Relationship(deleteRule: .cascade, inverse: \Diagnosis.patient)
    var activeDiagnoses: [Diagnosis]? = []

    /// Antecedentes de tratamientos previos (psicoterapia, psiquiatría, etc.)
    @Relationship(deleteRule: .cascade, inverse: \PriorTreatment.patient)
    var priorTreatments: [PriorTreatment]? = []

    /// Internaciones previas del paciente
    @Relationship(deleteRule: .cascade, inverse: \Hospitalization.patient)
    var hospitalizations: [Hospitalization]? = []

    /// Registros históricos de antropometría para graficar evolución
    /// con Swift Charts (peso, IMC, cintura a lo largo del tiempo)
    @Relationship(deleteRule: .cascade, inverse: \AnthropometricRecord.patient)
    var anthropometricRecords: [AnthropometricRecord]? = []

    // MARK: - Computed properties (no se persisten)

    var fullName: String { "\(firstName) \(lastName)" }
    var isActive: Bool { deletedAt == nil }

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
        guard heightCm > 0, weightKg > 0 else { return nil }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
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
        clinicalStatus: String = "estable",
        medicalRecordNumber: String = "",
        currentMedication: String = "",
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
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        professional: Professional? = nil,
        sessions: [Session]? = [],
        activeDiagnoses: [Diagnosis]? = [],
        priorTreatments: [PriorTreatment]? = [],
        hospitalizations: [Hospitalization]? = [],
        anthropometricRecords: [AnthropometricRecord]? = []
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.professional = professional
        self.sessions = sessions
        self.activeDiagnoses = activeDiagnoses
        self.priorTreatments = priorTreatments
        self.hospitalizations = hospitalizations
        self.anthropometricRecords = anthropometricRecords
    }
}
