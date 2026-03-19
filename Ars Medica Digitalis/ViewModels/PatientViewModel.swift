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
    var hasManuallyEditedDateOfBirth: Bool = false
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

    // MARK: - Finanzas básicas

    /// Moneda administrativa vigente del paciente.
    /// Se edita desde el formulario para que el flujo de cobro pueda resolver
    /// una divisa válida sin pedirla al momento de completar cada sesión.
    var currencyCode: String = ""

    // MARK: - Foto de perfil

    var photoData: Data? = nil

    // MARK: - Estado clínico

    var clinicalStatus: String = ClinicalStatusMapping.estable.rawValue

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
        calculateBMI(weightKg: weightKg, heightCm: heightCm)
    }

    /// Categoría del IMC para mostrar badge de color
    var bmiCategory: String {
        guard let bmi, let category = BMICategory(bmi: bmi) else { return "" }
        return category.label
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

    static let clinicalStatusOptions: [(String, String)] = [
        (ClinicalStatusMapping.estable.rawValue, ClinicalStatusMapping.estable.label),
        (ClinicalStatusMapping.activo.rawValue, ClinicalStatusMapping.activo.label),
        (ClinicalStatusMapping.riesgo.rawValue, ClinicalStatusMapping.riesgo.label),
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

    static let supportedCurrencies: [SupportedCurrency] = CurrencyCatalog.common

    // MARK: - Validación

    /// Validación mínima: nombre y apellido son obligatorios (HU-02)
    var canSave: Bool {
        !firstName.trimmed.isEmpty
        && !lastName.trimmed.isEmpty
    }

    // MARK: - Carga desde modelo

    /// Carga datos de un Patient existente para edición.
    func load(from patient: Patient) {
        firstName                  = patient.firstName
        lastName                   = patient.lastName
        dateOfBirth                = patient.dateOfBirth
        biologicalSex              = patient.biologicalSex
        nationalId                 = patient.nationalId
        gender                     = patient.gender
        nationality                = patient.nationality
        residenceCountry           = patient.residenceCountry
        occupation                 = patient.occupation
        educationLevel             = patient.educationLevel
        maritalStatus              = patient.maritalStatus
        email                      = patient.email
        phoneNumber                = patient.phoneNumber
        address                    = patient.address
        emergencyContactName       = patient.emergencyContactName
        emergencyContactPhone      = patient.emergencyContactPhone
        emergencyContactRelation   = patient.emergencyContactRelation
        healthInsurance            = patient.healthInsurance
        insuranceMemberNumber      = patient.insuranceMemberNumber
        insurancePlan              = patient.insurancePlan
        currencyCode               = patient.currencyCode
        photoData                  = patient.photoData
        clinicalStatus             = patient.clinicalStatus
        medicalRecordNumber        = patient.medicalRecordNumber
        currentMedication          = patient.currentMedication
        weightKg                   = patient.weightKg
        heightCm                   = patient.heightCm
        waistCm                    = patient.waistCm
        smokingStatus              = patient.smokingStatus
        alcoholUse                 = patient.alcoholUse
        drugUse                    = patient.drugUse
        routineCheckups            = patient.routineCheckups
        familyHistoryHTA           = patient.familyHistoryHTA
        familyHistoryACV           = patient.familyHistoryACV
        familyHistoryCancer        = patient.familyHistoryCancer
        familyHistoryDiabetes      = patient.familyHistoryDiabetes
        familyHistoryHeartDisease  = patient.familyHistoryHeartDisease
        familyHistoryMentalHealth  = patient.familyHistoryMentalHealth
        familyHistoryOther         = patient.familyHistoryOther
        genogramData               = patient.genogramData
        hasManuallyEditedDateOfBirth = true
    }

    /// Si el profesional tiene una moneda base, la sembramos al crear
    /// pacientes nuevos para reducir fricción y mantener consistencia
    /// administrativa desde el primer guardado.
    func applyCreationDefaults(from professional: Professional) {
        guard currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        currencyCode = professional.defaultPatientCurrencyCode
    }

    func markDateOfBirthAsEdited() {
        hasManuallyEditedDateOfBirth = true
    }

    // MARK: - Creación

    /// Crea un nuevo Patient vinculado al Professional activo.
    @discardableResult
    func createPatient(for professional: Professional, in context: ModelContext) -> Patient {
        applyCreationDefaults(from: professional)
        let recordNumber = PatientMedicalRecordNumberService()
            .resolvedRecordNumber(from: medicalRecordNumber)
        let patient = Patient()
        applyFields(to: patient, includeRecordNumber: true, recordNumber: recordNumber)
        patient.professional = professional
        context.insert(patient)
        syncCurrencyVersionIfNeeded(for: patient, in: context)
        return patient
    }

    // MARK: - Actualización

    /// Actualiza un Patient existente con los valores del formulario.
    func update(_ patient: Patient, in context: ModelContext? = nil) {
        applyFields(to: patient)
        patient.medicalRecordNumber = PatientMedicalRecordNumberService()
            .resolvedRecordNumber(from: patient.medicalRecordNumber)
        if let context {
            syncCurrencyVersionIfNeeded(for: patient, in: context)
        }
        patient.updatedAt = Date()
    }

    // MARK: - Mapeo ViewModel → Patient

    private func applyFields(
        to patient: Patient,
        includeRecordNumber: Bool = false,
        recordNumber: String = ""
    ) {
        patient.firstName                 = firstName.trimmed
        patient.lastName                  = lastName.trimmed
        patient.dateOfBirth               = dateOfBirth
        patient.biologicalSex             = biologicalSex
        patient.nationalId                = nationalId.trimmed
        patient.gender                    = gender
        patient.nationality               = nationality.trimmed
        patient.residenceCountry          = residenceCountry.trimmed
        patient.occupation                = occupation.trimmed
        patient.educationLevel            = educationLevel
        patient.maritalStatus             = maritalStatus
        patient.email                     = email.trimmed
        patient.phoneNumber               = phoneNumber.trimmed
        patient.address                   = address.trimmed
        patient.emergencyContactName      = emergencyContactName.trimmed
        patient.emergencyContactPhone     = emergencyContactPhone.trimmed
        patient.emergencyContactRelation  = emergencyContactRelation
        patient.healthInsurance           = healthInsurance.trimmed
        patient.insuranceMemberNumber     = insuranceMemberNumber.trimmed
        patient.insurancePlan             = insurancePlan.trimmed
        patient.currencyCode              = currencyCode
        patient.photoData                 = photoData
        patient.clinicalStatus            = clinicalStatus
        patient.currentMedication         = currentMedication.trimmed
        patient.weightKg                  = weightKg
        patient.heightCm                  = heightCm
        patient.waistCm                   = waistCm
        patient.smokingStatus             = smokingStatus
        patient.alcoholUse                = alcoholUse
        patient.drugUse                   = drugUse
        patient.routineCheckups           = routineCheckups
        patient.familyHistoryHTA          = familyHistoryHTA
        patient.familyHistoryACV          = familyHistoryACV
        patient.familyHistoryCancer       = familyHistoryCancer
        patient.familyHistoryDiabetes     = familyHistoryDiabetes
        patient.familyHistoryHeartDisease = familyHistoryHeartDisease
        patient.familyHistoryMentalHealth = familyHistoryMentalHealth
        patient.familyHistoryOther        = familyHistoryOther.trimmed
        patient.genogramData              = genogramData
        if includeRecordNumber {
            patient.medicalRecordNumber   = recordNumber
        }
    }

    // MARK: - Baja y restauración

    /// Baja lógica: marca deletedAt con la fecha actual (HU-03).
    /// La historia clínica permanece íntegra en CloudKit.
    func softDelete(_ patient: Patient) {
        patient.softDelete()
    }

    /// Restaurar un paciente dado de baja
    func restore(_ patient: Patient) {
        patient.restore()
    }

    /// Mantiene el scalar de compatibilidad y el historial temporal alineados.
    /// Solo crea una nueva versión cuando la moneda efectivamente cambió para
    /// preservar el histórico sin duplicar entradas idénticas.
    private func syncCurrencyVersionIfNeeded(for patient: Patient, in context: ModelContext) {
        let normalizedCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        patient.currencyCode = normalizedCode

        guard normalizedCode.isEmpty == false else {
            return
        }

        let latestVersion = patient.currencyVersions
            .sorted(by: sortCurrencyVersionsDescending)
            .first

        guard latestVersion?.currencyCode != normalizedCode else {
            return
        }

        let version = PatientCurrencyVersion(
            currencyCode: normalizedCode,
            effectiveFrom: Date(),
            patient: patient
        )
        context.insert(version)
    }

    private func sortCurrencyVersionsDescending(
        _ lhs: PatientCurrencyVersion,
        _ rhs: PatientCurrencyVersion
    ) -> Bool {
        if lhs.effectiveFrom == rhs.effectiveFrom {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.effectiveFrom > rhs.effectiveFrom
    }

    // MARK: - Registro antropométrico histórico

    /// Crea un snapshot inmutable de los datos antropométricos si cambiaron.
    /// Debe llamarse ANTES de update() porque compara los valores del VM
    /// contra los valores actuales del paciente para detectar cambios.
    func createAnthropometricRecordIfNeeded(for patient: Patient, in context: ModelContext) {
        // Solo crear registro si hay datos relevantes
        guard weightKg > 0 || heightCm > 0 else { return }

        // Detectar si algo cambió respecto al paciente (epsilon para doubles)
        let weightChanged = abs(weightKg - patient.weightKg) > 0.01
        let heightChanged = abs(heightCm - patient.heightCm) > 0.01
        let waistChanged = abs(waistCm - patient.waistCm) > 0.01

        guard weightChanged || heightChanged || waistChanged else { return }

        let record = AnthropometricRecord(
            recordDate: Date(),
            weightKg: weightKg,
            heightCm: heightCm,
            waistCm: waistCm,
            patient: patient
        )
        context.insert(record)
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
