//
//  VoiceInputManager.swift
//  Ars Medica Digitalis
//
//  Stub de entrada por voz para preparar integración con SpeechAnalyzer.
//  No inicia grabación, no solicita permisos y no usa transcripción real.
//

import Foundation

@MainActor
@Observable
final class VoiceInputManager: ClinicalInputSource {

    private(set) var captureMode: VoiceCaptureMode = .idle
    private(set) var activeField: ClinicalVoiceField? = nil
    private(set) var transcriptState: ClinicalTranscriptState = ClinicalTranscriptState()

    var volatileTranscript: String {
        transcriptState.volatileTranscript
    }

    var finalizedTranscript: String {
        transcriptState.finalizedTranscript
    }

    var audioTimeRange: ClinicalAudioTimeRange? {
        transcriptState.audioTimeRange
    }

    /// Firma estable para autosave/persistencia.
    /// Deliberadamente no usa texto volátil.
    var stableAutosaveSignature: String {
        transcriptState.stableSignature
    }

    func toggleCapture(for field: ClinicalVoiceField) {
        if activeField == field {
            stopCapture()
            return
        }

        activeField = field
        captureMode = .armed(field: field)

        // Se reinicia estado temporal para la próxima sesión del campo.
        transcriptState.volatileTranscript = ""
        transcriptState.finalizedTranscript = ""
        transcriptState.audioTimeRange = nil
    }

    func stopCapture() {
        activeField = nil
        captureMode = .idle
        transcriptState.volatileTranscript = ""
        if transcriptState.finalizedTranscript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            transcriptState.audioTimeRange = nil
        }
    }

    func clearTranscripts(for field: ClinicalVoiceField? = nil) {
        if let field, activeField != nil, activeField != field { return }
        transcriptState.volatileTranscript = ""
        transcriptState.finalizedTranscript = ""
        transcriptState.audioTimeRange = nil
    }

    // MARK: - Stub hooks (sin integración real)

    /// Hook para futuras pruebas locales sin SpeechAnalyzer real.
    func ingestStubVolatileTranscript(
        _ text: String,
        for field: ClinicalVoiceField,
        audioTimeRange: ClinicalAudioTimeRange?
    ) {
        guard activeField == field else { return }
        captureMode = .capturing(field: field)
        transcriptState.volatileTranscript = text
        transcriptState.audioTimeRange = audioTimeRange
    }

    /// Hook para futuras pruebas locales sin SpeechTranscriber real.
    func ingestStubFinalizedTranscript(
        _ text: String,
        for field: ClinicalVoiceField,
        audioTimeRange: ClinicalAudioTimeRange?
    ) {
        guard activeField == field else { return }
        captureMode = .finishing(field: field)
        transcriptState.finalizedTranscript = text
        transcriptState.volatileTranscript = ""
        transcriptState.audioTimeRange = audioTimeRange
    }
}
