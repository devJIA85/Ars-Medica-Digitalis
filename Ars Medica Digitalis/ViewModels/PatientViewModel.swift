//
//  PatientViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para alta, edición y baja lógica de pacientes (HU-02, HU-03).
//  También gestiona los campos de historia clínica (antropometría,
//  estilo de vida, antecedentes familiares, etc.)
//

import Foundation
import SwiftData
import UIKit

@Observable
final class PatientViewModel {

    // MARK: - Datos demográficos básicos

    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Date()
    var biologicalSex: String = ""
    var nationalId: String = ""

    // MARK: - Datos personales expandidos

    var gender: String = ""
    var nationality: String = ""
    var residenceCountry: String = ""
    var occupation: String = ""
    var educationLevel: String = ""
    var maritalStatus: String = ""

    // MARK: - Contacto

    var email: String = ""
    var phoneNumber: String = ""
    var address: String = ""

    // MARK: - Contacto de emergencia

    var emergencyContactName: String = ""
    var emergencyContactPhone: String = ""
    var emergencyContactRelation: String = ""

    // MARK: - Cobertura médica

    var healthInsurance: String = ""
    var insuranceMemberNumber: String = ""
    var insurancePlan: String = ""

    // MARK: - Foto de perfil

    var photoData: Data? = nil

    // MARK: - Historia clínica

    var medicalRecordNumber: String = ""
    var currentMedication: String = ""

    // MARK: - Antropometría

    var weightKg: Double = 0
    var heightCm: Double = 0
    var waistCm: Double = 0

    // MARK: - Estilo de vida

    var smokingStatus: Bool = false
    var alcoholUse: Bool = false
    var drugUse: Bool = false
    var routineCheckups: Bool = false

    // MARK: - Antecedentes familiares

    var familyHistoryHTA: Bool = false
    var familyHistoryACV: Bool = false
    var familyHistoryCancer: Bool = false
    var familyHistoryDiabetes: Bool = false
    var familyHistoryHeartDisease: Bool = false
    var familyHistoryMentalHealth: Bool = false
    var familyHistoryOther: String = ""

    // MARK: - Genograma

    var genogramData: Data? = nil

    // MARK: - Computed

    /// IMC calculado en tiempo real mientras se edita en el form
    var bmi: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    /// Categoría del IMC para mostrar badge de color
    var bmiCategory: String {
        guard let bmi else { return "" }
        switch bmi {
        case ..<18.5: return "Bajo peso"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Sobrepeso"
        default: return "Obesidad"
        }
    }

    // Opciones para Pickers — estáticas para consistencia
    static let genderOptions: [(String, String)] = [
        ("", "Sin especificar"),
        ("masculino", "Masculino"),
        ("femenino", "Femenino"),
        ("no binario", "No binario"),
        ("otro", "Otro"),
    ]

    static let educationLevelOptions: [(String, String)] = [
        ("", "Sin especificar"),
        ("primario", "Primario"),
        ("secundario", "Secundario"),
        ("terciario", "Terciario"),
        ("universitario", "Universitario"),
        ("posgrado", "Posgrado"),
    ]

    static let maritalStatusOptions: [(String, String)] = [
        ("", "Sin especificar"),
        ("soltero/a", "Soltero/a"),
        ("en pareja", "En pareja"),
        ("casado/a", "Casado/a"),
        ("divorciado/a", "Divorciado/a"),
        ("viudo/a", "Viudo/a"),
    ]

    static let emergencyRelationOptions: [(String, String)] = [
        ("", "Sin especificar"),
        ("padre/madre", "Padre/Madre"),
        ("cónyuge", "Cónyuge"),
        ("hermano/a", "Hermano/a"),
        ("hijo/a", "Hijo/a"),
        ("amigo/a", "Amigo/a"),
        ("otro", "Otro"),
    ]

    // MARK: - Validación

    /// Validación mínima: nombre y apellido son obligatorios (HU-02)
    var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Carga desde modelo

    /// Carga datos de un Patient existente para edición
    func load(from patient: Patient) {
        // Datos básicos
        firstName = patient.firstName
        lastName = patient.lastName
        dateOfBirth = patient.dateOfBirth
        biologicalSex = patient.biologicalSex
        nationalId = patient.nationalId

        // Datos expandidos
        gender = patient.gender
        nationality = patient.nationality
        residenceCountry = patient.residenceCountry
        occupation = patient.occupation
        educationLevel = patient.educationLevel
        maritalStatus = patient.maritalStatus

        // Contacto
        email = patient.email
        phoneNumber = patient.phoneNumber
        address = patient.address

        // Contacto de emergencia
        emergencyContactName = patient.emergencyContactName
        emergencyContactPhone = patient.emergencyContactPhone
        emergencyContactRelation = patient.emergencyContactRelation

        // Cobertura médica
        healthInsurance = patient.healthInsurance
        insuranceMemberNumber = patient.insuranceMemberNumber
        insurancePlan = patient.insurancePlan

        // Foto
        photoData = patient.photoData

        // Historia clínica
        medicalRecordNumber = patient.medicalRecordNumber
        currentMedication = patient.currentMedication

        // Antropometría
        weightKg = patient.weightKg
        heightCm = patient.heightCm
        waistCm = patient.waistCm

        // Estilo de vida
        smokingStatus = patient.smokingStatus
        alcoholUse = patient.alcoholUse
        drugUse = patient.drugUse
        routineCheckups = patient.routineCheckups

        // Antecedentes familiares
        familyHistoryHTA = patient.familyHistoryHTA
        familyHistoryACV = patient.familyHistoryACV
        familyHistoryCancer = patient.familyHistoryCancer
        familyHistoryDiabetes = patient.familyHistoryDiabetes
        familyHistoryHeartDisease = patient.familyHistoryHeartDisease
        familyHistoryMentalHealth = patient.familyHistoryMentalHealth
        familyHistoryOther = patient.familyHistoryOther

        // Genograma
        genogramData = patient.genogramData
    }

    // MARK: - Creación

    /// Crea un nuevo Patient vinculado al Professional activo
    func createPatient(for professional: Professional, in context: ModelContext) {
        // Autogenerar número de historia clínica si está vacío
        let recordNumber = medicalRecordNumber.isEmpty
            ? "HC-\(UUID().uuidString.prefix(8).uppercased())"
            : medicalRecordNumber

        let patient = Patient(
            firstName: firstName.trimmed,
            lastName: lastName.trimmed,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            gender: gender,
            nationality: nationality.trimmed,
            residenceCountry: residenceCountry.trimmed,
            occupation: occupation.trimmed,
            educationLevel: educationLevel,
            maritalStatus: maritalStatus,
            nationalId: nationalId.trimmed,
            email: email.trimmed,
            phoneNumber: phoneNumber.trimmed,
            address: address.trimmed,
            emergencyContactName: emergencyContactName.trimmed,
            emergencyContactPhone: emergencyContactPhone.trimmed,
            emergencyContactRelation: emergencyContactRelation,
            healthInsurance: healthInsurance.trimmed,
            insuranceMemberNumber: insuranceMemberNumber.trimmed,
            insurancePlan: insurancePlan.trimmed,
            photoData: photoData,
            medicalRecordNumber: recordNumber,
            currentMedication: currentMedication.trimmed,
            weightKg: weightKg,
            heightCm: heightCm,
            waistCm: waistCm,
            smokingStatus: smokingStatus,
            alcoholUse: alcoholUse,
            drugUse: drugUse,
            routineCheckups: routineCheckups,
            familyHistoryHTA: familyHistoryHTA,
            familyHistoryACV: familyHistoryACV,
            familyHistoryCancer: familyHistoryCancer,
            familyHistoryDiabetes: familyHistoryDiabetes,
            familyHistoryHeartDisease: familyHistoryHeartDisease,
            familyHistoryMentalHealth: familyHistoryMentalHealth,
            familyHistoryOther: familyHistoryOther.trimmed,
            genogramData: genogramData,
            professional: professional
        )
        context.insert(patient)
    }

    // MARK: - Actualización

    /// Actualiza un Patient existente con los valores del formulario
    func update(_ patient: Patient) {
        // Datos básicos
        patient.firstName = firstName.trimmed
        patient.lastName = lastName.trimmed
        patient.dateOfBirth = dateOfBirth
        patient.biologicalSex = biologicalSex
        patient.nationalId = nationalId.trimmed

        // Datos expandidos
        patient.gender = gender
        patient.nationality = nationality.trimmed
        patient.residenceCountry = residenceCountry.trimmed
        patient.occupation = occupation.trimmed
        patient.educationLevel = educationLevel
        patient.maritalStatus = maritalStatus

        // Contacto
        patient.email = email.trimmed
        patient.phoneNumber = phoneNumber.trimmed
        patient.address = address.trimmed

        // Contacto de emergencia
        patient.emergencyContactName = emergencyContactName.trimmed
        patient.emergencyContactPhone = emergencyContactPhone.trimmed
        patient.emergencyContactRelation = emergencyContactRelation

        // Cobertura médica
        patient.healthInsurance = healthInsurance.trimmed
        patient.insuranceMemberNumber = insuranceMemberNumber.trimmed
        patient.insurancePlan = insurancePlan.trimmed

        // Foto
        patient.photoData = photoData

        // Historia clínica
        patient.currentMedication = currentMedication.trimmed

        // Antropometría
        patient.weightKg = weightKg
        patient.heightCm = heightCm
        patient.waistCm = waistCm

        // Estilo de vida
        patient.smokingStatus = smokingStatus
        patient.alcoholUse = alcoholUse
        patient.drugUse = drugUse
        patient.routineCheckups = routineCheckups

        // Antecedentes familiares
        patient.familyHistoryHTA = familyHistoryHTA
        patient.familyHistoryACV = familyHistoryACV
        patient.familyHistoryCancer = familyHistoryCancer
        patient.familyHistoryDiabetes = familyHistoryDiabetes
        patient.familyHistoryHeartDisease = familyHistoryHeartDisease
        patient.familyHistoryMentalHealth = familyHistoryMentalHealth
        patient.familyHistoryOther = familyHistoryOther.trimmed

        // Genograma
        patient.genogramData = genogramData

        patient.updatedAt = Date()
    }

    // MARK: - Baja y restauración

    /// Baja lógica: marca deletedAt con la fecha actual (HU-03).
    /// La historia clínica permanece íntegra en CloudKit.
    func softDelete(_ patient: Patient) {
        patient.deletedAt = Date()
        patient.updatedAt = Date()
    }

    /// Restaurar un paciente dado de baja
    func restore(_ patient: Patient) {
        patient.deletedAt = nil
        patient.updatedAt = Date()
    }

    // MARK: - Helpers de foto

    /// Redimensiona una imagen a thumbnail para almacenamiento eficiente.
    /// Usa UIImage.preparingThumbnail(of:) (iOS 15+) que es síncrono
    /// y adecuado para el contexto MainActor.
    func resizePhoto(_ imageData: Data, maxDimension: CGFloat = 200) -> Data? {
        guard let uiImage = UIImage(data: imageData),
              let resized = uiImage.preparingThumbnail(
                of: CGSize(width: maxDimension, height: maxDimension)
              )
        else { return nil }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Extensión privada para trimming conciso

private extension String {
    /// Atajo para .trimmingCharacters(in: .whitespaces)
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
