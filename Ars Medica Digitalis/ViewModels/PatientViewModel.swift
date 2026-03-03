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

    /// Carga datos de un Patient existente para edición
    func load(from patient: Patient) {
        PatientFormData(patient: patient).apply(to: self)
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

    // MARK: - Creación

    /// Crea un nuevo Patient vinculado al Professional activo
    @discardableResult
    func createPatient(for professional: Professional, in context: ModelContext) -> Patient {
        applyCreationDefaults(from: professional)
        let data = PatientFormData(viewModel: self)

        // Autogenerar número de historia clínica si está vacío
        let recordNumber = data.medicalRecordNumber.isEmpty
            ? "HC-\(UUID().uuidString.prefix(8).uppercased())"
            : data.medicalRecordNumber

        let patient = data.makePatient(recordNumber: recordNumber, professional: professional)
        context.insert(patient)
        syncCurrencyVersionIfNeeded(for: patient, in: context)
        return patient
    }

    // MARK: - Actualización

    /// Actualiza un Patient existente con los valores del formulario
    func update(_ patient: Patient, in context: ModelContext? = nil) {
        PatientFormData(viewModel: self).apply(to: patient)
        if let context {
            syncCurrencyVersionIfNeeded(for: patient, in: context)
        }
        patient.updatedAt = Date()
    }

    // MARK: - Form Mapping

    /// Snapshot intermedio para evitar mapeos manuales repetidos
    /// entre ViewModel y modelo Patient.
    private struct PatientFormData {
        // Datos básicos
        let firstName: String
        let lastName: String
        let dateOfBirth: Date
        let biologicalSex: String
        let nationalId: String

        // Datos expandidos
        let gender: String
        let nationality: String
        let residenceCountry: String
        let occupation: String
        let educationLevel: String
        let maritalStatus: String

        // Contacto
        let email: String
        let phoneNumber: String
        let address: String

        // Emergencia
        let emergencyContactName: String
        let emergencyContactPhone: String
        let emergencyContactRelation: String

        // Cobertura
        let healthInsurance: String
        let insuranceMemberNumber: String
        let insurancePlan: String

        // Finanzas
        let currencyCode: String

        // Clínica
        let photoData: Data?
        let clinicalStatus: String
        let medicalRecordNumber: String
        let currentMedication: String

        // Antropometría
        let weightKg: Double
        let heightCm: Double
        let waistCm: Double

        // Hábitos
        let smokingStatus: Bool
        let alcoholUse: Bool
        let drugUse: Bool
        let routineCheckups: Bool

        // Familiares
        let familyHistoryHTA: Bool
        let familyHistoryACV: Bool
        let familyHistoryCancer: Bool
        let familyHistoryDiabetes: Bool
        let familyHistoryHeartDisease: Bool
        let familyHistoryMentalHealth: Bool
        let familyHistoryOther: String

        // Genograma
        let genogramData: Data?

        init(viewModel: PatientViewModel) {
            firstName = viewModel.firstName.trimmed
            lastName = viewModel.lastName.trimmed
            dateOfBirth = viewModel.dateOfBirth
            biologicalSex = viewModel.biologicalSex
            nationalId = viewModel.nationalId.trimmed

            gender = viewModel.gender
            nationality = viewModel.nationality.trimmed
            residenceCountry = viewModel.residenceCountry.trimmed
            occupation = viewModel.occupation.trimmed
            educationLevel = viewModel.educationLevel
            maritalStatus = viewModel.maritalStatus

            email = viewModel.email.trimmed
            phoneNumber = viewModel.phoneNumber.trimmed
            address = viewModel.address.trimmed

            emergencyContactName = viewModel.emergencyContactName.trimmed
            emergencyContactPhone = viewModel.emergencyContactPhone.trimmed
            emergencyContactRelation = viewModel.emergencyContactRelation

            healthInsurance = viewModel.healthInsurance.trimmed
            insuranceMemberNumber = viewModel.insuranceMemberNumber.trimmed
            insurancePlan = viewModel.insurancePlan.trimmed
            currencyCode = viewModel.currencyCode

            photoData = viewModel.photoData
            clinicalStatus = viewModel.clinicalStatus
            medicalRecordNumber = viewModel.medicalRecordNumber
            currentMedication = viewModel.currentMedication.trimmed

            weightKg = viewModel.weightKg
            heightCm = viewModel.heightCm
            waistCm = viewModel.waistCm

            smokingStatus = viewModel.smokingStatus
            alcoholUse = viewModel.alcoholUse
            drugUse = viewModel.drugUse
            routineCheckups = viewModel.routineCheckups

            familyHistoryHTA = viewModel.familyHistoryHTA
            familyHistoryACV = viewModel.familyHistoryACV
            familyHistoryCancer = viewModel.familyHistoryCancer
            familyHistoryDiabetes = viewModel.familyHistoryDiabetes
            familyHistoryHeartDisease = viewModel.familyHistoryHeartDisease
            familyHistoryMentalHealth = viewModel.familyHistoryMentalHealth
            familyHistoryOther = viewModel.familyHistoryOther.trimmed

            genogramData = viewModel.genogramData
        }

        init(patient: Patient) {
            firstName = patient.firstName
            lastName = patient.lastName
            dateOfBirth = patient.dateOfBirth
            biologicalSex = patient.biologicalSex
            nationalId = patient.nationalId

            gender = patient.gender
            nationality = patient.nationality
            residenceCountry = patient.residenceCountry
            occupation = patient.occupation
            educationLevel = patient.educationLevel
            maritalStatus = patient.maritalStatus

            email = patient.email
            phoneNumber = patient.phoneNumber
            address = patient.address

            emergencyContactName = patient.emergencyContactName
            emergencyContactPhone = patient.emergencyContactPhone
            emergencyContactRelation = patient.emergencyContactRelation

            healthInsurance = patient.healthInsurance
            insuranceMemberNumber = patient.insuranceMemberNumber
            insurancePlan = patient.insurancePlan
            currencyCode = patient.currencyCode

            photoData = patient.photoData
            clinicalStatus = patient.clinicalStatus
            medicalRecordNumber = patient.medicalRecordNumber
            currentMedication = patient.currentMedication

            weightKg = patient.weightKg
            heightCm = patient.heightCm
            waistCm = patient.waistCm

            smokingStatus = patient.smokingStatus
            alcoholUse = patient.alcoholUse
            drugUse = patient.drugUse
            routineCheckups = patient.routineCheckups

            familyHistoryHTA = patient.familyHistoryHTA
            familyHistoryACV = patient.familyHistoryACV
            familyHistoryCancer = patient.familyHistoryCancer
            familyHistoryDiabetes = patient.familyHistoryDiabetes
            familyHistoryHeartDisease = patient.familyHistoryHeartDisease
            familyHistoryMentalHealth = patient.familyHistoryMentalHealth
            familyHistoryOther = patient.familyHistoryOther

            genogramData = patient.genogramData
        }

        func apply(to viewModel: PatientViewModel) {
            viewModel.firstName = firstName
            viewModel.lastName = lastName
            viewModel.dateOfBirth = dateOfBirth
            viewModel.biologicalSex = biologicalSex
            viewModel.nationalId = nationalId

            viewModel.gender = gender
            viewModel.nationality = nationality
            viewModel.residenceCountry = residenceCountry
            viewModel.occupation = occupation
            viewModel.educationLevel = educationLevel
            viewModel.maritalStatus = maritalStatus

            viewModel.email = email
            viewModel.phoneNumber = phoneNumber
            viewModel.address = address

            viewModel.emergencyContactName = emergencyContactName
            viewModel.emergencyContactPhone = emergencyContactPhone
            viewModel.emergencyContactRelation = emergencyContactRelation

            viewModel.healthInsurance = healthInsurance
            viewModel.insuranceMemberNumber = insuranceMemberNumber
            viewModel.insurancePlan = insurancePlan
            viewModel.currencyCode = currencyCode

            viewModel.photoData = photoData
            viewModel.clinicalStatus = clinicalStatus
            viewModel.medicalRecordNumber = medicalRecordNumber
            viewModel.currentMedication = currentMedication

            viewModel.weightKg = weightKg
            viewModel.heightCm = heightCm
            viewModel.waistCm = waistCm

            viewModel.smokingStatus = smokingStatus
            viewModel.alcoholUse = alcoholUse
            viewModel.drugUse = drugUse
            viewModel.routineCheckups = routineCheckups

            viewModel.familyHistoryHTA = familyHistoryHTA
            viewModel.familyHistoryACV = familyHistoryACV
            viewModel.familyHistoryCancer = familyHistoryCancer
            viewModel.familyHistoryDiabetes = familyHistoryDiabetes
            viewModel.familyHistoryHeartDisease = familyHistoryHeartDisease
            viewModel.familyHistoryMentalHealth = familyHistoryMentalHealth
            viewModel.familyHistoryOther = familyHistoryOther

            viewModel.genogramData = genogramData
        }

        func apply(to patient: Patient, includeMedicalRecordNumber: Bool = false) {
            patient.firstName = firstName
            patient.lastName = lastName
            patient.dateOfBirth = dateOfBirth
            patient.biologicalSex = biologicalSex
            patient.nationalId = nationalId

            patient.gender = gender
            patient.nationality = nationality
            patient.residenceCountry = residenceCountry
            patient.occupation = occupation
            patient.educationLevel = educationLevel
            patient.maritalStatus = maritalStatus

            patient.email = email
            patient.phoneNumber = phoneNumber
            patient.address = address

            patient.emergencyContactName = emergencyContactName
            patient.emergencyContactPhone = emergencyContactPhone
            patient.emergencyContactRelation = emergencyContactRelation

            patient.healthInsurance = healthInsurance
            patient.insuranceMemberNumber = insuranceMemberNumber
            patient.insurancePlan = insurancePlan
            patient.currencyCode = currencyCode

            patient.photoData = photoData
            patient.clinicalStatus = clinicalStatus
            if includeMedicalRecordNumber {
                patient.medicalRecordNumber = medicalRecordNumber
            }
            patient.currentMedication = currentMedication

            patient.weightKg = weightKg
            patient.heightCm = heightCm
            patient.waistCm = waistCm

            patient.smokingStatus = smokingStatus
            patient.alcoholUse = alcoholUse
            patient.drugUse = drugUse
            patient.routineCheckups = routineCheckups

            patient.familyHistoryHTA = familyHistoryHTA
            patient.familyHistoryACV = familyHistoryACV
            patient.familyHistoryCancer = familyHistoryCancer
            patient.familyHistoryDiabetes = familyHistoryDiabetes
            patient.familyHistoryHeartDisease = familyHistoryHeartDisease
            patient.familyHistoryMentalHealth = familyHistoryMentalHealth
            patient.familyHistoryOther = familyHistoryOther

            patient.genogramData = genogramData
        }

        func makePatient(recordNumber: String, professional: Professional) -> Patient {
            let patient = Patient()
            apply(to: patient, includeMedicalRecordNumber: true)
            patient.medicalRecordNumber = recordNumber
            patient.professional = professional
            return patient
        }
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

        let latestVersion = (patient.currencyVersions ?? [])
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
