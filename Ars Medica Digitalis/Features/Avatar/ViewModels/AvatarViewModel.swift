//
//  AvatarViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel @Observable para el flujo de selección y generación de avatar.
//
//  LIFECYCLE
//  ---------
//  El ViewModel se inicializa en el `init()` explícito de ProfileView mediante
//  `_avatarViewModel = State(initialValue: AvatarViewModel(from: professional))`.
//  Esto garantiza una sola instancia durante toda la vida de la pantalla, sin
//  re-instancias por recomposición de SwiftUI ni inicialización lazy frágil.
//
//  SEPARACIÓN DE RESPONSABILIDADES
//  --------------------------------
//  - AvatarViewModel: estado de selección/pendiente, conceptos de IA, coordinación.
//  - AvatarImageStore: toda operación sobre FileManager (guardar, borrar, cargar).
//  Esta separación mantiene el ViewModel testeable y libre de dependencias de sistema.
//

import SwiftUI
import SwiftData
import OSLog
import ImagePlayground

@Observable
final class AvatarViewModel {

    private static let logger = Logger(
        subsystem: "com.arsmedica.digitalis",
        category: "AvatarViewModel"
    )

    // MARK: - Concepto de contexto clínico fijo

    /// Concepto de contexto añadido siempre al prompt junto al texto del usuario.
    /// Se declara aquí para poder incluirlo en el `fullPrompt` guardado en metadata.
    private static let clinicalContextConcept = "retrato profesional de salud"

    // MARK: - Estado de configuración

    /// Configuración confirmada en SwiftData para este Professional.
    private(set) var current: AvatarConfiguration

    /// Selección realizada por el usuario, aún no aplicada/guardada.
    private(set) var pending: AvatarConfiguration?

    // MARK: - Wizard de IA

    /// Texto libre del usuario que describe la vibra del avatar.
    /// Se convierte en el primer `ImagePlaygroundConcept`.
    var vibeText: String = "profesional de salud"

    /// Controla la presentación del sheet de Image Playground.
    var showingImagePlayground: Bool = false

    // MARK: - Imagen generada (caché en memoria)

    /// UIImage del avatar generado, cargada al init o tras una nueva generación.
    /// nil si la configuración actual/pendiente es predefinida.
    private(set) var generatedImage: Image?

    // MARK: - Init

    /// Inicializa el ViewModel desde el estado actual del Professional.
    /// Llamar desde el `init()` de ProfileView para garantizar un lifecycle estable.
    init(from professional: Professional) {
        current = professional.avatar
        loadGeneratedImageIfNeeded(for: current)
    }

    // MARK: - Configuración a mostrar

    /// La configuración que debe renderizar la UI: la pendiente si existe, la actual si no.
    var preview: AvatarConfiguration { pending ?? current }

    var hasPendingChanges: Bool { pending != nil }

    // MARK: - Selección predefinida

    func selectPredefined(_ style: PredefinedAvatarStyle) {
        pending = .predefined(style: style)
        generatedImage = nil
    }

    // MARK: - Image Playground

    /// Conceptos enviados al sheet de Image Playground.
    /// Se construyen en tiempo de acceso para reflejar el `vibeText` actual.
    var imagePlaygroundConcepts: [ImagePlaygroundConcept] {
        [.text(vibeText), .text(Self.clinicalContextConcept)]
    }

    /// Prompt final efectivamente enviado: texto del usuario + concepto de contexto.
    /// Se persiste en `AvatarGenerationMetadata.fullPrompt` para trazabilidad.
    private var currentFullPrompt: String {
        "\(vibeText.trimmingCharacters(in: .whitespaces)), \(Self.clinicalContextConcept)"
    }

    /// Llamado por `.imagePlaygroundSheet(onCompletion:)` con la URL temporal.
    ///
    /// La URL es temporal; se copia inmediatamente a almacenamiento permanente
    /// mediante `AvatarImageStore`. Si la copia falla, se loguea y no se actualiza
    /// el estado (la selección pendiente queda sin cambiar).
    func handleGeneratedImage(url: URL) {
        do {
            let fileName = try AvatarImageStore.save(from: url)
            let metadata = AvatarGenerationMetadata(
                vibe: vibeText,
                fullPrompt: currentFullPrompt,
                generatedAt: Date()
            )
            let config = AvatarConfiguration.generated(imageFileName: fileName, metadata: metadata)
            pending = config
            loadGeneratedImage(named: fileName)
        } catch {
            Self.logger.error("Failed to save generated avatar image: \(error, privacy: .private)")
        }
    }

    // MARK: - Aplicar al Professional

    /// Confirma la selección pendiente: escribe en Professional, persiste en SwiftData,
    /// y elimina la imagen generada anterior si ya no se usa.
    func apply(to professional: Professional, in context: ModelContext) {
        guard let config = pending else { return }
        deleteSupersededImage(previous: current, next: config)
        professional.avatar = config
        professional.updatedAt = Date()
        current = config
        pending = nil
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to persist avatar: \(error, privacy: .private)")
        }
        // Cleanup defensivo: elimina cualquier residuo no capturado por los flujos normales.
        cleanupOrphans(for: professional)
    }

    /// Descarta la selección pendiente y elimina el archivo temporal si era una generación.
    func cancel() {
        if case .generated(let fileName, _) = pending {
            AvatarImageStore.delete(fileName: fileName)
        }
        pending = nil
        loadGeneratedImageIfNeeded(for: current)
    }

    // MARK: - Image loading

    private func loadGeneratedImageIfNeeded(for config: AvatarConfiguration) {
        guard case .generated(let fileName, _) = config else {
            generatedImage = nil
            return
        }
        loadGeneratedImage(named: fileName)
    }

    private func loadGeneratedImage(named fileName: String) {
        if let uiImage = AvatarImageStore.loadImage(named: fileName) {
            generatedImage = Image(uiImage: uiImage)
        } else {
            generatedImage = nil
        }
    }

    // MARK: - File cleanup

    /// Elimina la imagen anterior cuando se confirma una nueva configuración generada distinta,
    /// o cuando se confirma una predefinida (la imagen generada queda huérfana).
    private func deleteSupersededImage(
        previous: AvatarConfiguration,
        next: AvatarConfiguration
    ) {
        guard case .generated(let oldName, _) = previous else { return }
        if case .generated(let newName, _) = next, newName == oldName { return }
        AvatarImageStore.delete(fileName: oldName)
    }

    /// Limpieza defensiva tras un apply: construye el conjunto de nombres activos
    /// para el Professional recién actualizado y delega en AvatarImageStore.
    /// Usa Set<String> para ser consistente con la política global de cleanup
    /// (que también usa Set para soportar múltiples Professional).
    private func cleanupOrphans(for professional: Professional) {
        var activeFileNames: Set<String> = []
        if case .generated(let fileName, _) = professional.avatar {
            activeFileNames.insert(fileName)
        }
        AvatarImageStore.removeOrphans(keeping: activeFileNames)
    }
}
