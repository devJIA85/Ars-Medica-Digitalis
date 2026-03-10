//
//  MMSEAssessmentView.swift
//  Ars Medica Digitalis
//
//  Flujo completo de administración MMSE orientado por JSON.
//

import SwiftUI
import SwiftData

struct MMSEAssessmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let loader: MMSELoader
    private let patientID: UUID?
    private let showsCloseButton: Bool
    private let onResultSaved: () -> Void

    @State private var store: MMSEStore? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isSavingResult: Bool = false
    @State private var savedResultID: UUID? = nil
    @State private var saveErrorMessage: String? = nil

    init(
        loader: MMSELoader = MMSELoader(),
        patientID: UUID? = nil,
        showsCloseButton: Bool = false,
        onResultSaved: @escaping () -> Void = {}
    ) {
        self.loader = loader
        self.patientID = patientID
        self.showsCloseButton = showsCloseButton
        self.onResultSaved = onResultSaved
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let errorMessage {
                errorView(message: errorMessage)
            } else if let store {
                content(store: store)
            } else {
                errorView(message: "No se pudo inicializar la evaluación MMSE.")
            }
        }
        .navigationTitle("MMSE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .task {
            await loadMMSEIfNeeded()
        }
    }

    /// Estado de carga inicial mientras se lee y valida el JSON.
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
            Text("Cargando Mini Mental State Examination…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Estado de error explícito para hacer visible cualquier problema de recurso.
    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "No se pudo cargar MMSE",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Contenido principal en ScrollView + LazyVStack según requerimiento.
    private func content(store: MMSEStore) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                headerCard(test: store.test)

                progressCard(store: store)

                ForEach(Array(store.visibleSections.enumerated()), id: \.element.id) { index, section in
                    MMSESectionView(
                        section: section,
                        sectionIndex: index,
                        totalSections: store.test.sections.count,
                        store: store
                    )
                }

                sectionNavigationCard(store: store)

                if store.isComplete {
                    MMSEScoreView(
                        test: store.test,
                        totalScore: store.totalScore,
                        sectionScores: store.sectionScores,
                        interpretation: store.currentInterpretation
                    )

                    saveResultCard(store: store)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .alert(
            "No se pudo guardar el resultado",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false { saveErrorMessage = nil }
                }
            )
        ) {
            Button("Aceptar", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Intentá nuevamente.")
        }
    }

    /// Card de contexto clínico del test, íntegramente tomado del JSON.
    private func headerCard(test: MMSETest) -> some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(test.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(test.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.md) {
                    Label("\(test.maximumScore) puntos", systemImage: "sum")
                    Label("\(test.sections.count) secciones", systemImage: "list.number")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Resumen de progreso global y score parcial para feedback continuo.
    private func progressCard(store: MMSEStore) -> some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Progreso")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("\(Int((store.progress * 100).rounded()))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: store.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                HStack {
                    Text("Respondidos: \(store.answeredScorableItems)/\(store.totalScorableItems)")
                    Spacer()
                    Text("Puntaje actual: \(store.totalScore)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Progreso del MMSE")
            .accessibilityValue("\(Int((store.progress * 100).rounded())) por ciento")
        }
    }

    /// Controles secuenciales de secciones para mantener flujo clínico ordenado.
    private func sectionNavigationCard(store: MMSEStore) -> some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if store.hasNextSection {
                    Button {
                        store.goToNextSection()
                    } label: {
                        Label(
                            "Continuar a la siguiente sección",
                            systemImage: "arrow.right.circle.fill"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canAdvanceToNextSection)
                    .accessibilityHint(
                        store.canAdvanceToNextSection
                        ? "Avanza a la próxima sección del test"
                        : "Completá primero todos los ítems evaluables de esta sección"
                    )

                    if !store.canAdvanceToNextSection {
                        Text("Completá todos los ítems evaluables para avanzar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.hasPreviousSection {
                    Button {
                        store.goToPreviousSection()
                    } label: {
                        Label(
                            "Volver a la sección anterior",
                            systemImage: "arrow.left.circle"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }

                if store.isComplete {
                    Text("Evaluación completa. Revisión final disponible abajo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Persistencia explícita del resultado MMSE para mantener paridad con flujos clínicos existentes.
    /// Se guarda en SwiftData como `PatientScaleResult` usando `scaleID = test.id`.
    private func saveResultCard(store: MMSEStore) -> some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if patientID == nil {
                    Text("No se puede guardar el resultado sin paciente asociado.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    saveResult(store: store)
                } label: {
                    if isSavingResult {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Text(savedResultID == nil ? "Guardar resultado" : "Resultado guardado")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(patientID == nil || savedResultID != nil || isSavingResult)
                .accessibilityHint("Guarda este resultado MMSE en el historial del paciente")
            }
        }
    }

    @MainActor
    private func saveResult(store: MMSEStore) {
        guard let patientID, savedResultID == nil else { return }
        isSavingResult = true

        defer {
            isSavingResult = false
        }

        do {
            // Se adapta MMSE al formato común de persistencia para unificar historial clínico.
            let result = ScaleComputedResult(
                patientID: patientID,
                scaleID: store.test.id,
                date: Date(),
                totalScore: store.totalScore,
                maximumScore: store.test.maximumScore,
                severity: store.currentInterpretation?.severity ?? "unknown",
                interpretationLabel: store.currentInterpretation?.label ?? "Sin interpretación",
                color: store.currentInterpretation?.color ?? "gray",
                answers: store.persistedAnswers()
            )

            let saved = try ScaleResultPersistenceService.save(result, in: modelContext)
            savedResultID = saved.id

            // Tras guardar se vuelve al resumen intermedio para mostrar historial actualizado.
            dismiss()
            onResultSaved()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    /// Carga única del JSON MMSE y creación del store observable.
    @MainActor
    private func loadMMSEIfNeeded() async {
        guard store == nil else { return }
        isLoading = true

        do {
            let test = try await loader.load()
            store = MMSEStore(test: test)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview("MMSE Assessment") {
    MMSEAssessmentView()
}
