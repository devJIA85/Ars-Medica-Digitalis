//
//  PatientPDFExportService.swift
//  Ars Medica Digitalis
//
//  Genera un PDF clínico completo del paciente con:
//  - todos los datos del perfil
//  - sesiones cronológicas
//  - modalidad, duración, notas y plan
//

import Foundation
import UIKit

struct PatientPDFExportService {

    enum ExportError: LocalizedError {
        case emptyPDF

        var errorDescription: String? {
            switch self {
            case .emptyPDF:
                "No se pudo generar el archivo PDF."
            }
        }
    }

    func export(patient: Patient, professional: Professional?) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - (margin * 2)

        let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let sectionFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let smallFont = UIFont.systemFont(ofSize: 10, weight: .regular)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: UIColor.label
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        let smallAttrs: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let pdfData = renderer.pdfData { context in
            var currentPage = 0
            var cursorY: CGFloat = margin

            func beginPage() {
                context.beginPage()
                currentPage += 1
                cursorY = margin
            }

            func textHeight(_ text: String, attributes: [NSAttributedString.Key: Any], width: CGFloat) -> CGFloat {
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                return ceil(bounds.height)
            }

            func ensureSpace(for expectedHeight: CGFloat) {
                let maxY = pageRect.height - margin
                if cursorY + expectedHeight > maxY {
                    beginPage()
                    drawPageHeader()
                }
            }

            func drawPageHeader() {
                let header = "Ars Medica Digitalis"
                let headerRect = CGRect(x: margin, y: 14, width: contentWidth, height: 16)
                (header as NSString).draw(
                    in: headerRect,
                    withAttributes: smallAttrs
                )

                let pageLabel = "Página \(currentPage)"
                let pageLabelSize = (pageLabel as NSString).size(withAttributes: smallAttrs)
                let pageRect = CGRect(
                    x: margin + contentWidth - pageLabelSize.width,
                    y: 14,
                    width: pageLabelSize.width,
                    height: 16
                )
                (pageLabel as NSString).draw(in: pageRect, withAttributes: smallAttrs)
            }

            func drawParagraph(
                _ text: String,
                attributes: [NSAttributedString.Key: Any],
                spacingAfter: CGFloat = 8,
                indent: CGFloat = 0
            ) {
                let width = contentWidth - indent
                let height = textHeight(text, attributes: attributes, width: width)
                ensureSpace(for: height)

                let textRect = CGRect(
                    x: margin + indent,
                    y: cursorY,
                    width: width,
                    height: height
                )
                (text as NSString).draw(
                    with: textRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                cursorY = textRect.maxY + spacingAfter
            }

            func drawSectionTitle(_ title: String) {
                ensureSpace(for: 36)
                drawParagraph(title, attributes: sectionAttrs, spacingAfter: 6)
                let lineRect = CGRect(x: margin, y: cursorY - 4, width: contentWidth, height: 0.7)
                UIColor.separator.setFill()
                context.cgContext.fill(lineRect)
                cursorY += 8
            }

            func valueOrFallback(_ value: String) -> String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "No registrado" : trimmed
            }

            func boolLabel(_ value: Bool) -> String {
                value ? "Sí" : "No"
            }

            func drawKeyValue(_ key: String, _ value: String) {
                drawParagraph("\(key): \(value)", attributes: bodyAttrs, spacingAfter: 5)
            }

            func sectionFields(_ title: String, fields: [(String, String)]) {
                drawSectionTitle(title)
                for (key, value) in fields {
                    drawKeyValue(key, value)
                }
            }

            func sessionTypeLabel(_ value: String) -> String {
                switch value {
                case "presencial": "Presencial"
                case "videollamada": "Videollamada"
                case "telefónica": "Telefónica"
                default: valueOrFallback(value)
                }
            }

            func sessionStatusLabel(_ value: String) -> String {
                switch value {
                case "programada": "Programada"
                case "completada": "Completada"
                case "cancelada": "Cancelada"
                default: valueOrFallback(value)
                }
            }

            beginPage()
            drawPageHeader()

            drawParagraph("Historia Clínica del Paciente", attributes: titleAttrs, spacingAfter: 4)
            drawParagraph(
                "Generado: \(Date().formatted(date: .abbreviated, time: .shortened))",
                attributes: smallAttrs,
                spacingAfter: 16
            )

            if let professional {
                drawParagraph(
                    "Profesional: \(valueOrFallback(professional.fullName)) · Matrícula: \(valueOrFallback(professional.licenseNumber))",
                    attributes: bodyAttrs,
                    spacingAfter: 14
                )
            }

            sectionFields("Datos Personales", fields: [
                ("Nombre", valueOrFallback(patient.fullName)),
                ("Nº de historia clínica", valueOrFallback(patient.medicalRecordNumber)),
                ("Fecha de nacimiento", patient.dateOfBirth.formatted(date: .long, time: .omitted)),
                ("Edad", "\(patient.age) años"),
                ("Sexo biológico", valueOrFallback(patient.biologicalSex)),
                ("Género", valueOrFallback(patient.gender)),
                ("Documento", valueOrFallback(patient.nationalId)),
                ("Nacionalidad", valueOrFallback(patient.nationality)),
                ("País de residencia", valueOrFallback(patient.residenceCountry)),
                ("Ocupación", valueOrFallback(patient.occupation)),
                ("Nivel académico", valueOrFallback(patient.educationLevel)),
                ("Estado civil", valueOrFallback(patient.maritalStatus)),
                ("Paciente activo", boolLabel(patient.isActive))
            ])

            sectionFields("Contacto", fields: [
                ("Email", valueOrFallback(patient.email)),
                ("Teléfono", valueOrFallback(patient.phoneNumber)),
                ("Dirección", valueOrFallback(patient.address)),
                ("Contacto de emergencia", valueOrFallback(patient.emergencyContactName)),
                ("Teléfono emergencia", valueOrFallback(patient.emergencyContactPhone)),
                ("Relación emergencia", valueOrFallback(patient.emergencyContactRelation))
            ])

            sectionFields("Cobertura Médica", fields: [
                ("Obra social", valueOrFallback(patient.healthInsurance)),
                ("Nº afiliado", valueOrFallback(patient.insuranceMemberNumber)),
                ("Plan", valueOrFallback(patient.insurancePlan))
            ])

            let bmiLabel: String = {
                guard let bmi = patient.bmi else { return "No registrado" }
                return String(format: "%.1f", bmi)
            }()

            sectionFields("Historia Clínica y Hábitos", fields: [
                ("Medicación actual", valueOrFallback(patient.currentMedication)),
                ("Peso", patient.weightKg > 0 ? String(format: "%.1f kg", patient.weightKg) : "No registrado"),
                ("Altura", patient.heightCm > 0 ? String(format: "%.0f cm", patient.heightCm) : "No registrado"),
                ("Cintura", patient.waistCm > 0 ? String(format: "%.0f cm", patient.waistCm) : "No registrado"),
                ("IMC", bmiLabel),
                ("Tabaquismo", boolLabel(patient.smokingStatus)),
                ("Alcohol", boolLabel(patient.alcoholUse)),
                ("Drogas", boolLabel(patient.drugUse)),
                ("Chequeos de rutina", boolLabel(patient.routineCheckups)),
                ("Foto de perfil cargada", boolLabel(patient.photoData != nil)),
                ("Genograma cargado", boolLabel(patient.genogramData != nil))
            ])

            sectionFields("Antecedentes Familiares", fields: [
                ("Hipertensión arterial", boolLabel(patient.familyHistoryHTA)),
                ("ACV", boolLabel(patient.familyHistoryACV)),
                ("Cáncer", boolLabel(patient.familyHistoryCancer)),
                ("Diabetes", boolLabel(patient.familyHistoryDiabetes)),
                ("Enfermedad cardíaca", boolLabel(patient.familyHistoryHeartDisease)),
                ("Salud mental", boolLabel(patient.familyHistoryMentalHealth)),
                ("Otros antecedentes", valueOrFallback(patient.familyHistoryOther))
            ])

            let activeDiagnoses = (patient.activeDiagnoses ?? []).sorted { $0.createdAt > $1.createdAt }
            drawSectionTitle("Diagnósticos Vigentes")
            if activeDiagnoses.isEmpty {
                drawParagraph("Sin diagnósticos vigentes.", attributes: bodyAttrs)
            } else {
                for diagnosis in activeDiagnoses {
                    let title = diagnosis.icdTitleEs.isEmpty ? diagnosis.icdTitle : diagnosis.icdTitleEs
                    let code = diagnosis.icdCode.isEmpty ? "-" : diagnosis.icdCode
                    drawParagraph("• [\(code)] \(valueOrFallback(title))", attributes: bodyAttrs, spacingAfter: 4)
                }
            }

            let priorTreatments = (patient.priorTreatments ?? []).sorted { $0.createdAt > $1.createdAt }
            drawSectionTitle("Tratamientos Previos")
            if priorTreatments.isEmpty {
                drawParagraph("Sin tratamientos previos registrados.", attributes: bodyAttrs)
            } else {
                for treatment in priorTreatments {
                    drawParagraph(
                        "• Tipo: \(valueOrFallback(treatment.treatmentType)) · Fecha: \(treatment.createdAt.formatted(date: .abbreviated, time: .omitted))",
                        attributes: bodyAttrs,
                        spacingAfter: 3
                    )
                    drawParagraph("Duración: \(valueOrFallback(treatment.durationDescription))", attributes: bodyAttrs, spacingAfter: 3, indent: 14)
                    drawParagraph("Medicación: \(valueOrFallback(treatment.medication))", attributes: bodyAttrs, spacingAfter: 3, indent: 14)
                    drawParagraph("Resultado: \(valueOrFallback(treatment.outcome))", attributes: bodyAttrs, spacingAfter: 3, indent: 14)
                    drawParagraph("Observaciones: \(valueOrFallback(treatment.observations))", attributes: bodyAttrs, spacingAfter: 6, indent: 14)
                }
            }

            let hospitalizations = (patient.hospitalizations ?? []).sorted { $0.admissionDate > $1.admissionDate }
            drawSectionTitle("Internaciones Previas")
            if hospitalizations.isEmpty {
                drawParagraph("Sin internaciones previas registradas.", attributes: bodyAttrs)
            } else {
                for hospitalization in hospitalizations {
                    drawParagraph(
                        "• Ingreso: \(hospitalization.admissionDate.formatted(date: .abbreviated, time: .omitted))",
                        attributes: bodyAttrs,
                        spacingAfter: 3
                    )
                    drawParagraph(
                        "Duración: \(valueOrFallback(hospitalization.durationDescription))",
                        attributes: bodyAttrs,
                        spacingAfter: 3,
                        indent: 14
                    )
                    drawParagraph(
                        "Observaciones: \(valueOrFallback(hospitalization.observations))",
                        attributes: bodyAttrs,
                        spacingAfter: 6,
                        indent: 14
                    )
                }
            }

            let anthropometricRecords = (patient.anthropometricRecords ?? []).sorted { $0.recordDate > $1.recordDate }
            drawSectionTitle("Registros Antropométricos")
            if anthropometricRecords.isEmpty {
                drawParagraph("Sin registros antropométricos históricos.", attributes: bodyAttrs)
            } else {
                for record in anthropometricRecords {
                    let bmiValue = record.bmi.map { String(format: "%.1f", $0) } ?? "No registrado"
                    drawParagraph(
                        "• Fecha: \(record.recordDate.formatted(date: .abbreviated, time: .omitted)) · Peso: \(String(format: "%.1f", record.weightKg)) kg · Altura: \(String(format: "%.0f", record.heightCm)) cm · Cintura: \(String(format: "%.0f", record.waistCm)) cm · IMC: \(bmiValue)",
                        attributes: bodyAttrs,
                        spacingAfter: 4
                    )
                }
            }

            drawSectionTitle("Sesiones Clínicas")
            let sessions = (patient.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
            if sessions.isEmpty {
                drawParagraph("Sin sesiones registradas.", attributes: bodyAttrs)
            } else {
                for (index, session) in sessions.enumerated() {
                    drawParagraph(
                        "Sesión \(index + 1) · \(session.sessionDate.formatted(date: .long, time: .shortened))",
                        attributes: sectionAttrs,
                        spacingAfter: 5
                    )

                    drawKeyValue("Modalidad", sessionTypeLabel(session.sessionType))
                    drawKeyValue("Duración", "\(session.durationMinutes) minutos")
                    drawKeyValue("Estado", sessionStatusLabel(session.status))
                    drawKeyValue("Motivo de consulta", valueOrFallback(session.chiefComplaint))
                    drawKeyValue("Notas clínicas", valueOrFallback(session.notes))
                    drawKeyValue("Plan de tratamiento", valueOrFallback(session.treatmentPlan))

                    let diagnoses = (session.diagnoses ?? []).sorted { $0.createdAt > $1.createdAt }
                    if diagnoses.isEmpty {
                        drawKeyValue("Diagnósticos", "Sin diagnósticos en esta sesión")
                    } else {
                        drawParagraph("Diagnósticos:", attributes: bodyAttrs, spacingAfter: 3)
                        for diagnosis in diagnoses {
                            let title = diagnosis.icdTitleEs.isEmpty ? diagnosis.icdTitle : diagnosis.icdTitleEs
                            let code = diagnosis.icdCode.isEmpty ? "-" : diagnosis.icdCode
                            drawParagraph("• [\(code)] \(valueOrFallback(title))", attributes: bodyAttrs, spacingAfter: 2, indent: 14)

                            if !diagnosis.clinicalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                drawParagraph(
                                    "Notas diagnóstico: \(valueOrFallback(diagnosis.clinicalNotes))",
                                    attributes: bodyAttrs,
                                    spacingAfter: 2,
                                    indent: 20
                                )
                            }
                        }
                    }

                    let attachments = (session.attachments ?? []).sorted { $0.createdAt > $1.createdAt }
                    if attachments.isEmpty {
                        drawKeyValue("Adjuntos", "Sin adjuntos")
                    } else {
                        drawParagraph("Adjuntos:", attributes: bodyAttrs, spacingAfter: 3)
                        for attachment in attachments {
                            drawParagraph(
                                "• \(valueOrFallback(attachment.fileName)) (\(valueOrFallback(attachment.fileType)))",
                                attributes: bodyAttrs,
                                spacingAfter: 2,
                                indent: 14
                            )
                        }
                    }

                    drawParagraph(
                        "Creada: \(session.createdAt.formatted(date: .abbreviated, time: .shortened)) · Modificada: \(session.updatedAt.formatted(date: .abbreviated, time: .shortened))",
                        attributes: smallAttrs,
                        spacingAfter: 14
                    )
                }
            }

            drawSectionTitle("Trazabilidad")
            drawKeyValue("Paciente creado", patient.createdAt.formatted(date: .abbreviated, time: .shortened))
            drawKeyValue("Paciente modificado", patient.updatedAt.formatted(date: .abbreviated, time: .shortened))
            drawKeyValue(
                "Fecha de baja",
                patient.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? "No aplica"
            )
        }

        guard !pdfData.isEmpty else {
            throw ExportError.emptyPDF
        }

        let outputURL = makeOutputURL(for: patient)
        try pdfData.write(to: outputURL, options: .atomic)
        return outputURL
    }

    // MARK: - File URL

    private func makeOutputURL(for patient: Patient) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let baseName = [
            patient.lastName,
            patient.firstName
        ]
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanName = baseName
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }

        let fileName = "HC_\(cleanName.isEmpty ? "Paciente" : cleanName)_\(timestamp).pdf"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
}
