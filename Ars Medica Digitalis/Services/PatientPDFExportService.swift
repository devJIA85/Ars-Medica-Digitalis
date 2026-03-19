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
        let layout = PDFLayout.a4
        let renderer = UIGraphicsPDFRenderer(bounds: layout.pageRect)

        let pdfData = renderer.pdfData { context in
            let composer = PDFComposer(context: context, layout: layout)
            composer.beginDocument()

            drawDocumentIntro(patient: patient, professional: professional, using: composer)
            drawPersonalData(patient: patient, using: composer)
            drawContact(patient: patient, using: composer)
            drawCoverage(patient: patient, using: composer)
            drawClinicalHistoryAndHabits(patient: patient, using: composer)
            drawFamilyHistory(patient: patient, using: composer)
            drawActiveDiagnoses(patient: patient, using: composer)
            drawPriorTreatments(patient: patient, using: composer)
            drawHospitalizations(patient: patient, using: composer)
            drawAnthropometricRecords(patient: patient, using: composer)
            drawSessions(patient: patient, using: composer)
            drawTraceability(patient: patient, using: composer)
        }

        guard !pdfData.isEmpty else {
            throw ExportError.emptyPDF
        }

        let outputURL = makeOutputURL(for: patient)
        try pdfData.write(to: outputURL, options: .atomic)
        return outputURL
    }

    // MARK: - Sections

    private func drawDocumentIntro(
        patient: Patient,
        professional: Professional?,
        using composer: PDFComposer
    ) {
        composer.drawParagraph(
            "Historia Clínica del Paciente",
            attributes: composer.titleAttributes,
            spacingAfter: 4
        )
        composer.drawParagraph(
            "Generado: \(Date().formatted(date: .abbreviated, time: .shortened))",
            attributes: composer.smallAttributes,
            spacingAfter: 16
        )

        if let professional {
            composer.drawParagraph(
                "Profesional: \(composer.valueOrFallback(professional.fullName)) · Matrícula: \(composer.valueOrFallback(professional.licenseNumber))",
                attributes: composer.bodyAttributes,
                spacingAfter: 14
            )
        }
    }

    private func drawPersonalData(patient: Patient, using composer: PDFComposer) {
        drawSectionFields(
            "Datos Personales",
            fields: [
                ("Nombre", composer.valueOrFallback(patient.fullName)),
                ("Nº de historia clínica", composer.valueOrFallback(patient.medicalRecordNumber)),
                ("Fecha de nacimiento", patient.dateOfBirth.formatted(date: .long, time: .omitted)),
                ("Edad", "\(patient.age) años"),
                ("Sexo biológico", composer.valueOrFallback(patient.biologicalSex)),
                ("Género", composer.valueOrFallback(patient.gender)),
                ("Documento", composer.valueOrFallback(patient.nationalId)),
                ("Nacionalidad", composer.valueOrFallback(patient.nationality)),
                ("País de residencia", composer.valueOrFallback(patient.residenceCountry)),
                ("Ocupación", composer.valueOrFallback(patient.occupation)),
                ("Nivel académico", composer.valueOrFallback(patient.educationLevel)),
                ("Estado civil", composer.valueOrFallback(patient.maritalStatus)),
                ("Paciente activo", composer.boolLabel(patient.isActive)),
            ],
            using: composer
        )
    }

    private func drawContact(patient: Patient, using composer: PDFComposer) {
        drawSectionFields(
            "Contacto",
            fields: [
                ("Email", composer.valueOrFallback(patient.email)),
                ("Teléfono", composer.valueOrFallback(patient.phoneNumber)),
                ("Dirección", composer.valueOrFallback(patient.address)),
                ("Contacto de emergencia", composer.valueOrFallback(patient.emergencyContactName)),
                ("Teléfono emergencia", composer.valueOrFallback(patient.emergencyContactPhone)),
                ("Relación emergencia", composer.valueOrFallback(patient.emergencyContactRelation)),
            ],
            using: composer
        )
    }

    private func drawCoverage(patient: Patient, using composer: PDFComposer) {
        drawSectionFields(
            "Cobertura Médica",
            fields: [
                ("Obra social", composer.valueOrFallback(patient.healthInsurance)),
                ("Nº afiliado", composer.valueOrFallback(patient.insuranceMemberNumber)),
                ("Plan", composer.valueOrFallback(patient.insurancePlan)),
            ],
            using: composer
        )
    }

    private func drawClinicalHistoryAndHabits(patient: Patient, using composer: PDFComposer) {
        let bmiLabel: String = {
            guard let bmi = patient.bmi else { return "No registrado" }
            return String(format: "%.1f", bmi)
        }()

        drawSectionFields(
            "Historia Clínica y Hábitos",
            fields: [
                ("Medicación actual", composer.valueOrFallback(patient.currentMedication)),
                ("Peso", patient.weightKg > 0 ? String(format: "%.1f kg", patient.weightKg) : "No registrado"),
                ("Altura", patient.heightCm > 0 ? String(format: "%.0f cm", patient.heightCm) : "No registrado"),
                ("Cintura", patient.waistCm > 0 ? String(format: "%.0f cm", patient.waistCm) : "No registrado"),
                ("IMC", bmiLabel),
                ("Tabaquismo", composer.boolLabel(patient.smokingStatus)),
                ("Alcohol", composer.boolLabel(patient.alcoholUse)),
                ("Drogas", composer.boolLabel(patient.drugUse)),
                ("Chequeos de rutina", composer.boolLabel(patient.routineCheckups)),
                ("Foto de perfil cargada", composer.boolLabel(patient.photoData != nil)),
                ("Genograma cargado", composer.boolLabel(patient.genogramData != nil)),
            ],
            using: composer
        )
    }

    private func drawFamilyHistory(patient: Patient, using composer: PDFComposer) {
        drawSectionFields(
            "Antecedentes Familiares",
            fields: [
                ("Hipertensión arterial", composer.boolLabel(patient.familyHistoryHTA)),
                ("ACV", composer.boolLabel(patient.familyHistoryACV)),
                ("Cáncer", composer.boolLabel(patient.familyHistoryCancer)),
                ("Diabetes", composer.boolLabel(patient.familyHistoryDiabetes)),
                ("Enfermedad cardíaca", composer.boolLabel(patient.familyHistoryHeartDisease)),
                ("Salud mental", composer.boolLabel(patient.familyHistoryMentalHealth)),
                ("Otros antecedentes", composer.valueOrFallback(patient.familyHistoryOther)),
            ],
            using: composer
        )
    }

    private func drawActiveDiagnoses(patient: Patient, using composer: PDFComposer) {
        let activeDiagnoses = patient.activeDiagnoses.sorted { $0.createdAt > $1.createdAt }
        composer.drawSectionTitle("Diagnósticos Vigentes")

        if activeDiagnoses.isEmpty {
            composer.drawParagraph("Sin diagnósticos vigentes.", attributes: composer.bodyAttributes)
            return
        }

        for diagnosis in activeDiagnoses {
            let title = diagnosis.displayTitle
            let code = diagnosis.icdCode.isEmpty ? "-" : diagnosis.icdCode
            composer.drawParagraph(
                "• [\(code)] \(composer.valueOrFallback(title))",
                attributes: composer.bodyAttributes,
                spacingAfter: 4
            )
        }
    }

    private func drawPriorTreatments(patient: Patient, using composer: PDFComposer) {
        let priorTreatments = patient.priorTreatments.sorted { $0.createdAt > $1.createdAt }
        composer.drawSectionTitle("Tratamientos Previos")

        if priorTreatments.isEmpty {
            composer.drawParagraph("Sin tratamientos previos registrados.", attributes: composer.bodyAttributes)
            return
        }

        for treatment in priorTreatments {
            composer.drawParagraph(
                "• Tipo: \(composer.valueOrFallback(treatment.treatmentType)) · Fecha: \(treatment.createdAt.formatted(date: .abbreviated, time: .omitted))",
                attributes: composer.bodyAttributes,
                spacingAfter: 3
            )
            composer.drawParagraph(
                "Duración: \(composer.valueOrFallback(treatment.durationDescription))",
                attributes: composer.bodyAttributes,
                spacingAfter: 3,
                indent: 14
            )
            composer.drawParagraph(
                "Medicación: \(composer.valueOrFallback(treatment.medication))",
                attributes: composer.bodyAttributes,
                spacingAfter: 3,
                indent: 14
            )
            composer.drawParagraph(
                "Resultado: \(composer.valueOrFallback(treatment.outcome))",
                attributes: composer.bodyAttributes,
                spacingAfter: 3,
                indent: 14
            )
            composer.drawParagraph(
                "Observaciones: \(composer.valueOrFallback(treatment.observations))",
                attributes: composer.bodyAttributes,
                spacingAfter: 6,
                indent: 14
            )
        }
    }

    private func drawHospitalizations(patient: Patient, using composer: PDFComposer) {
        let hospitalizations = patient.hospitalizations.sorted { $0.admissionDate > $1.admissionDate }
        composer.drawSectionTitle("Internaciones Previas")

        if hospitalizations.isEmpty {
            composer.drawParagraph("Sin internaciones previas registradas.", attributes: composer.bodyAttributes)
            return
        }

        for hospitalization in hospitalizations {
            composer.drawParagraph(
                "• Ingreso: \(hospitalization.admissionDate.formatted(date: .abbreviated, time: .omitted))",
                attributes: composer.bodyAttributes,
                spacingAfter: 3
            )
            composer.drawParagraph(
                "Duración: \(composer.valueOrFallback(hospitalization.durationDescription))",
                attributes: composer.bodyAttributes,
                spacingAfter: 3,
                indent: 14
            )
            composer.drawParagraph(
                "Observaciones: \(composer.valueOrFallback(hospitalization.observations))",
                attributes: composer.bodyAttributes,
                spacingAfter: 6,
                indent: 14
            )
        }
    }

    private func drawAnthropometricRecords(patient: Patient, using composer: PDFComposer) {
        let anthropometricRecords = patient.anthropometricRecords.sorted { $0.recordDate > $1.recordDate }
        composer.drawSectionTitle("Registros Antropométricos")

        if anthropometricRecords.isEmpty {
            composer.drawParagraph("Sin registros antropométricos históricos.", attributes: composer.bodyAttributes)
            return
        }

        for record in anthropometricRecords {
            let bmiValue = record.bmi.map { String(format: "%.1f", $0) } ?? "No registrado"
            composer.drawParagraph(
                "• Fecha: \(record.recordDate.formatted(date: .abbreviated, time: .omitted)) · Peso: \(String(format: "%.1f", record.weightKg)) kg · Altura: \(String(format: "%.0f", record.heightCm)) cm · Cintura: \(String(format: "%.0f", record.waistCm)) cm · IMC: \(bmiValue)",
                attributes: composer.bodyAttributes,
                spacingAfter: 4
            )
        }
    }

    private func drawSessions(patient: Patient, using composer: PDFComposer) {
        composer.drawSectionTitle("Sesiones Clínicas")
        let sessions = patient.sessions.sorted { $0.sessionDate > $1.sessionDate }

        if sessions.isEmpty {
            composer.drawParagraph("Sin sesiones registradas.", attributes: composer.bodyAttributes)
            return
        }

        for (index, session) in sessions.enumerated() {
            composer.drawParagraph(
                "Sesión \(index + 1) · \(session.sessionDate.formatted(date: .long, time: .shortened))",
                attributes: composer.sectionAttributes,
                spacingAfter: 5
            )

            composer.drawKeyValue("Modalidad", sessionTypeLabel(session.sessionType, composer: composer))
            composer.drawKeyValue("Duración", "\(session.durationMinutes) minutos")
            composer.drawKeyValue("Estado", sessionStatusLabel(session.status, composer: composer))
            composer.drawKeyValue("Motivo de consulta", composer.valueOrFallback(session.chiefComplaint))
            composer.drawKeyValue("Notas clínicas", composer.valueOrFallback(session.notes))
            composer.drawKeyValue("Plan de tratamiento", composer.valueOrFallback(session.treatmentPlan))

            let diagnoses = session.diagnoses.sorted { $0.createdAt > $1.createdAt }
            if diagnoses.isEmpty {
                composer.drawKeyValue("Diagnósticos", "Sin diagnósticos en esta sesión")
            } else {
                composer.drawParagraph("Diagnósticos:", attributes: composer.bodyAttributes, spacingAfter: 3)
                for diagnosis in diagnoses {
                    let title = diagnosis.displayTitle
                    let code = diagnosis.icdCode.isEmpty ? "-" : diagnosis.icdCode
                    composer.drawParagraph(
                        "• [\(code)] \(composer.valueOrFallback(title))",
                        attributes: composer.bodyAttributes,
                        spacingAfter: 2,
                        indent: 14
                    )

                    if !diagnosis.clinicalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        composer.drawParagraph(
                            "Notas diagnóstico: \(composer.valueOrFallback(diagnosis.clinicalNotes))",
                            attributes: composer.bodyAttributes,
                            spacingAfter: 2,
                            indent: 20
                        )
                    }
                }
            }

            let attachments = session.attachments.sorted { $0.createdAt > $1.createdAt }
            if attachments.isEmpty {
                composer.drawKeyValue("Adjuntos", "Sin adjuntos")
            } else {
                composer.drawParagraph("Adjuntos:", attributes: composer.bodyAttributes, spacingAfter: 3)
                for attachment in attachments {
                    composer.drawParagraph(
                        "• \(composer.valueOrFallback(attachment.fileName)) (\(composer.valueOrFallback(attachment.fileType)))",
                        attributes: composer.bodyAttributes,
                        spacingAfter: 2,
                        indent: 14
                    )
                }
            }

            composer.drawParagraph(
                "Creada: \(session.createdAt.formatted(date: .abbreviated, time: .shortened)) · Modificada: \(session.updatedAt.formatted(date: .abbreviated, time: .shortened))",
                attributes: composer.smallAttributes,
                spacingAfter: 14
            )
        }
    }

    private func drawTraceability(patient: Patient, using composer: PDFComposer) {
        composer.drawSectionTitle("Trazabilidad")
        composer.drawKeyValue("Paciente creado", patient.createdAt.formatted(date: .abbreviated, time: .shortened))
        composer.drawKeyValue("Paciente modificado", patient.updatedAt.formatted(date: .abbreviated, time: .shortened))
        composer.drawKeyValue(
            "Fecha de baja",
            patient.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? "No aplica"
        )
    }

    private func drawSectionFields(
        _ title: String,
        fields: [(String, String)],
        using composer: PDFComposer
    ) {
        composer.drawSectionTitle(title)
        for (key, value) in fields {
            composer.drawKeyValue(key, value)
        }
    }

    private func sessionTypeLabel(_ value: String, composer: PDFComposer) -> String {
        SessionTypeMapping(sessionTypeRawValue: value)?.label
            ?? composer.valueOrFallback(value)
    }

    private func sessionStatusLabel(_ value: String, composer: PDFComposer) -> String {
        SessionStatusMapping(sessionStatusRawValue: value)?.label
            ?? composer.valueOrFallback(value)
    }

    // MARK: - File URL

    private func makeOutputURL(for patient: Patient) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let baseName = [
            patient.lastName,
            patient.firstName,
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

private extension PatientPDFExportService {

    struct PDFLayout {
        let pageRect: CGRect
        let margin: CGFloat
        let contentWidth: CGFloat

        let titleAttrs: [NSAttributedString.Key: Any]
        let sectionAttrs: [NSAttributedString.Key: Any]
        let bodyAttrs: [NSAttributedString.Key: Any]
        let smallAttrs: [NSAttributedString.Key: Any]

        static var a4: PDFLayout {
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
                .foregroundColor: UIColor.label,
            ]
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: UIColor.label,
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
            ]
            let smallAttrs: [NSAttributedString.Key: Any] = [
                .font: smallFont,
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle,
            ]

            return PDFLayout(
                pageRect: pageRect,
                margin: margin,
                contentWidth: contentWidth,
                titleAttrs: titleAttrs,
                sectionAttrs: sectionAttrs,
                bodyAttrs: bodyAttrs,
                smallAttrs: smallAttrs
            )
        }
    }

    final class PDFComposer {
        private let context: UIGraphicsPDFRendererContext
        private let layout: PDFLayout

        private var currentPage: Int = 0
        private var cursorY: CGFloat

        init(context: UIGraphicsPDFRendererContext, layout: PDFLayout) {
            self.context = context
            self.layout = layout
            self.cursorY = layout.margin
        }

        var titleAttributes: [NSAttributedString.Key: Any] { layout.titleAttrs }
        var sectionAttributes: [NSAttributedString.Key: Any] { layout.sectionAttrs }
        var bodyAttributes: [NSAttributedString.Key: Any] { layout.bodyAttrs }
        var smallAttributes: [NSAttributedString.Key: Any] { layout.smallAttrs }

        func beginDocument() {
            beginPage()
            drawPageHeader()
        }

        func drawParagraph(
            _ text: String,
            attributes: [NSAttributedString.Key: Any],
            spacingAfter: CGFloat = 8,
            indent: CGFloat = 0
        ) {
            let width = layout.contentWidth - indent
            let height = textHeight(text, attributes: attributes, width: width)
            ensureSpace(for: height)

            let textRect = CGRect(
                x: layout.margin + indent,
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
            drawParagraph(title, attributes: sectionAttributes, spacingAfter: 6)

            let lineRect = CGRect(
                x: layout.margin,
                y: cursorY - 4,
                width: layout.contentWidth,
                height: 0.7
            )
            UIColor.separator.setFill()
            context.cgContext.fill(lineRect)
            cursorY += 8
        }

        func drawKeyValue(_ key: String, _ value: String) {
            drawParagraph("\(key): \(value)", attributes: bodyAttributes, spacingAfter: 5)
        }

        func valueOrFallback(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "No registrado" : trimmed
        }

        func boolLabel(_ value: Bool) -> String {
            value ? "Sí" : "No"
        }

        private func beginPage() {
            context.beginPage()
            currentPage += 1
            cursorY = layout.margin
        }

        private func textHeight(
            _ text: String,
            attributes: [NSAttributedString.Key: Any],
            width: CGFloat
        ) -> CGFloat {
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            return ceil(bounds.height)
        }

        private func ensureSpace(for expectedHeight: CGFloat) {
            let maxY = layout.pageRect.height - layout.margin
            if cursorY + expectedHeight > maxY {
                beginPage()
                drawPageHeader()
            }
        }

        private func drawPageHeader() {
            let header = "Ars Medica Digitalis"
            let headerRect = CGRect(x: layout.margin, y: 14, width: layout.contentWidth, height: 16)
            (header as NSString).draw(in: headerRect, withAttributes: smallAttributes)

            let pageLabel = "Página \(currentPage)"
            let pageLabelSize = (pageLabel as NSString).size(withAttributes: smallAttributes)
            let pageRect = CGRect(
                x: layout.margin + layout.contentWidth - pageLabelSize.width,
                y: 14,
                width: pageLabelSize.width,
                height: 16
            )
            (pageLabel as NSString).draw(in: pageRect, withAttributes: smallAttributes)
        }
    }
}
