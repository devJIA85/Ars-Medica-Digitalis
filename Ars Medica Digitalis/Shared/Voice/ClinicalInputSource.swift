//
//  ClinicalInputSource.swift
//  Ars Medica Digitalis
//
//  Contratos y modelos base para captura de voz clínica por campo activo.
//  Esta capa es solo arquitectura: no inicia audio ni pide permisos.
//

import Foundation

enum ClinicalVoiceField: String, CaseIterable, Hashable, Sendable {
    case medicationLegacy
    case weight
    case height
    case waist
    case familyHistoryOther

    var label: String {
        switch self {
        case .medicationLegacy:
            return "Medicación actual"
        case .weight:
            return "Peso"
        case .height:
            return "Altura"
        case .waist:
            return "Cintura"
        case .familyHistoryOther:
            return "Otros antecedentes"
        }
    }
}

enum VoiceCaptureMode: Equatable, Sendable {
    case idle
    case armed(field: ClinicalVoiceField)
    case capturing(field: ClinicalVoiceField)
    case finishing(field: ClinicalVoiceField)

    var field: ClinicalVoiceField? {
        switch self {
        case .idle:
            return nil
        case .armed(let field),
             .capturing(let field),
             .finishing(let field):
            return field
        }
    }
}

struct ClinicalAudioTimeRange: Equatable, Sendable {
    var startSeconds: TimeInterval
    var endSeconds: TimeInterval

    var durationSeconds: TimeInterval {
        max(0, endSeconds - startSeconds)
    }

    var signature: String {
        "\(startSeconds)-\(endSeconds)"
    }
}

struct ClinicalTranscriptState: Equatable, Sendable {
    var volatileTranscript: String = ""
    var finalizedTranscript: String = ""
    var audioTimeRange: ClinicalAudioTimeRange? = nil

    /// Snapshot estable para persistencia/autosave.
    /// Deliberadamente NO incluye volatileTranscript.
    var stableSignature: String {
        let hasFinalizedContent = !finalizedTranscript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        let stableRangeSignature: String
        if hasFinalizedContent {
            stableRangeSignature = audioTimeRange?.signature ?? "no-range"
        } else {
            stableRangeSignature = "no-range"
        }

        return [
            finalizedTranscript,
            stableRangeSignature,
        ].joined(separator: "|")
    }
}

@MainActor
protocol ClinicalInputSource: AnyObject {
    var captureMode: VoiceCaptureMode { get }
    var activeField: ClinicalVoiceField? { get }
    var transcriptState: ClinicalTranscriptState { get }

    func toggleCapture(for field: ClinicalVoiceField)
    func stopCapture()
    func clearTranscripts(for field: ClinicalVoiceField?)
}
