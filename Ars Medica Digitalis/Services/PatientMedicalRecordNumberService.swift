//
//  PatientMedicalRecordNumberService.swift
//  Ars Medica Digitalis
//
//  Normaliza y repara números de historia clínica faltantes.
//

import Foundation
import OSLog
import SwiftData

struct PatientMedicalRecordRepairResult: Sendable {
    let generatedCount: Int
    let normalizedCount: Int
    let skippedCount: Int
}

struct PatientMedicalRecordNumberService {

    private let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "RecordRepair")

    func resolvedRecordNumber(from rawValue: String) -> String {
        Self.normalizedRecordNumber(from: rawValue) ?? Self.generateRecordNumber()
    }

    @discardableResult
    func repairMissingRecordNumbers(in context: ModelContext) throws -> PatientMedicalRecordRepairResult {
        let descriptor = FetchDescriptor<Patient>()
        let patients = try context.fetch(descriptor)

        var generatedCount = 0
        var normalizedCount = 0

        for patient in patients {
            let originalValue = patient.medicalRecordNumber
            if let normalizedValue = Self.normalizedRecordNumber(from: originalValue) {
                guard normalizedValue != originalValue else { continue }
                patient.medicalRecordNumber = normalizedValue
                patient.updatedAt = Date()
                normalizedCount += 1
                continue
            }

            patient.medicalRecordNumber = Self.generateRecordNumber()
            patient.updatedAt = Date()
            generatedCount += 1
        }

        if generatedCount > 0 || normalizedCount > 0 {
            try context.save()
        }

        let skippedCount = patients.count - generatedCount - normalizedCount
        logger.info(
            "PatientMedicalRecordNumberService: generated=\(generatedCount, privacy: .public) normalized=\(normalizedCount, privacy: .public) skipped=\(skippedCount, privacy: .public)"
        )

        return PatientMedicalRecordRepairResult(
            generatedCount: generatedCount,
            normalizedCount: normalizedCount,
            skippedCount: skippedCount
        )
    }

    static func normalizedRecordNumber(from rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmed
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func generateRecordNumber() -> String {
        "HC-\(UUID().uuidString.prefix(8).uppercased())"
    }
}
