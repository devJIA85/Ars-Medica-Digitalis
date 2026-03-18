//
//  HonorariosView.swift
//  Ars Medica Digitalis
//
//  Tablero premium de honorarios del profesional.
//  Presenta señales económicas ya calculadas por el ViewModel sin mover
//  lógica comercial a la capa visual.
//

import SwiftUI
import SwiftData

/// Regla visual de enfriamiento para el highlight de sugerencias.
/// Se mantiene pura y separada para poder testear el comportamiento
/// sin depender de SwiftUI ni de persistencia.
enum HonorariosHighlightRules {

    /// Ventana fija para evitar "nagging" después de descartar una sugerencia.
    /// En este PR queda constante para dar una UX predecible; luego podrá
    /// hacerse configurable si el producto lo necesita.
    private static let dismissCooldownDays = 7

    static func shouldShowSuggestionHighlight(
        policy: PricingAdjustmentPolicy?,
        snapshot: SessionTypeBusinessSnapshot,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard snapshot.shouldSuggestUpdate else {
            return false
        }

        guard let policy else {
            return true
        }

        guard let dismissedAt = policy.lastSuggestionDismissedAt else {
            return true
        }

        guard let nextVisibleDate = calendar.date(
            byAdding: .day,
            value: dismissCooldownDays,
            to: dismissedAt
        ) else {
            return true
        }

        return now >= nextVisibleDate
    }
}

/// Reglas puras del tipo sugerido para nuevas sesiones.
/// Se centralizan fuera de la vista para reutilizar el mismo criterio en la
/// UI y en tests sin depender de estado visual.
enum HonorariosSuggestedTypeRules {

    /// Solo los tipos activos pueden proponerse en sesiones nuevas.
    /// Los inactivos siguen existiendo para historial, pero no para captura.
    static func activeSnapshots(
        from snapshots: [SessionTypeBusinessSnapshot]
    ) -> [SessionTypeBusinessSnapshot] {
        snapshots.filter { $0.sessionType.isActive }
    }

    /// Devuelve un tipo sugerido siempre válido para la operación diaria.
    /// Si la preferencia guardada se volvió inválida, se cae al primer tipo
    /// activo para no dejar sesiones nuevas sin una sugerencia usable.
    static func resolvedDefaultSessionTypeID(
        defaultSessionTypeID: UUID?,
        activeSnapshots: [SessionTypeBusinessSnapshot]
    ) -> UUID? {
        if let defaultSessionTypeID,
           activeSnapshots.contains(where: { $0.sessionType.id == defaultSessionTypeID }) {
            return defaultSessionTypeID
        }

        return activeSnapshots.first?.sessionType.id
    }
}

struct HonorariosView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let professional: Professional

    @State private var viewModel: SessionTypeBusinessViewModel?
    @State private var errorMessage: String?
    @State private var selectedUpdateSnapshot: UpdateSheetState?
    @State private var selectedManagementState: SessionTypeManagementSheetState?
    @State private var showingCreateHonorarium: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Moneda predeterminada", selection: defaultPatientCurrencyBinding) {
                        Text("Sin configurar").tag("")
                        ForEach(CurrencyCatalog.common) { currency in
                            Text(currency.displayLabel).tag(currency.code)
                        }
                    }
                } header: {
                    Text("Pacientes nuevos")
                } footer: {
                    Text("Se aplica automáticamente al crear pacientes nuevos.")
                }

                if let viewModel {
                    content(for: viewModel)
                } else {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .refreshable {
                await refreshHonorarios()
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(L10n.tr("honorarios.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("honorarios.close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateHonorarium = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            prepareViewModelIfNeeded()
            await refreshHonorarios()
        }
        .alert(L10n.tr("honorarios.load_error.title"), isPresented: $errorMessage.isPresent) {
            Button(L10n.tr("common.accept"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.tr("honorarios.load_error.message"))
        }
        .sheet(item: $selectedUpdateSnapshot) { state in
            SessionTypePriceUpdateView(
                snapshot: state.snapshot,
                professional: professional,
                context: modelContext
            ) {
                await refreshHonorarios()
            }
        }
        .sheet(item: $selectedManagementState) { state in
            SessionTypeManagementView(
                snapshot: state.snapshot,
                professional: professional,
                context: modelContext
            ) {
                await refreshHonorarios()
            }
        }
        .sheet(isPresented: $showingCreateHonorarium) {
            HonorariumCreateView(
                professional: professional,
                context: modelContext
            ) {
                await refreshHonorarios()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: SessionTypeBusinessViewModel) -> some View {
        let activeSnapshots = HonorariosSuggestedTypeRules.activeSnapshots(
            from: viewModel.snapshots
        )
        let suggestedSessionTypeID = HonorariosSuggestedTypeRules
            .resolvedDefaultSessionTypeID(
                defaultSessionTypeID: professional.defaultFinancialSessionTypeID,
                activeSnapshots: activeSnapshots
            )

        if activeSnapshots.isEmpty {
            Section {
                VStack(spacing: 18) {
                    ContentUnavailableView(
                        L10n.tr("honorarios.empty.title"),
                        systemImage: "banknote",
                        description: Text(L10n.tr("honorarios.empty.description"))
                    )

                    Button("Crear primer honorario") {
                        showingCreateHonorarium = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            if activeSnapshots.isEmpty == false {
                suggestedSessionTypeSection(
                    activeSnapshots: activeSnapshots
                )
            }

            Section {
                ForEach(activeSnapshots, id: \.sessionType.id) { snapshot in
                    HonorariosSessionTypeCard(
                        snapshot: snapshot,
                        isSuggestedDefault: snapshot.sessionType.id == suggestedSessionTypeID,
                        isHighlighted: HonorariosHighlightRules.shouldShowSuggestionHighlight(
                            policy: professional.pricingAdjustmentPolicy,
                            snapshot: snapshot
                        ),
                        onDismissHighlight: dismissSuggestionHighlight,
                        onRequestUpdate: {
                            selectedUpdateSnapshot = UpdateSheetState(snapshot: snapshot)
                        },
                        onManageType: {
                            selectedManagementState = SessionTypeManagementSheetState(
                                snapshot: snapshot
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    /// Inicializa el ViewModel una sola vez usando el contexto del entorno.
    /// El contexto no está disponible en el init de la vista, por eso la
    /// construcción se difiere a la primera tarea asincrónica.
    @MainActor
    private func prepareViewModelIfNeeded() {
        guard viewModel == nil else {
            return
        }

        viewModel = SessionTypeBusinessViewModel(
            professional: professional,
            context: modelContext
        )
    }

    @MainActor
    private func refreshHonorarios() async {
        guard let viewModel else {
            return
        }

        do {
            try await viewModel.refresh()
            normalizeSuggestedFinancialSessionTypeIfNeeded(using: viewModel)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Persiste el descarte global del highlight para bajar fricción.
    /// El silencio dura siete días y se guarda en la policy para sobrevivir
    /// cierres de app, recargas de contexto y nuevos ingresos al módulo.
    @MainActor
    private func dismissSuggestionHighlight() {
        let policy: PricingAdjustmentPolicy
        if let existingPolicy = professional.pricingAdjustmentPolicy {
            policy = existingPolicy
        } else {
            let newPolicy = PricingAdjustmentPolicy(isEnabled: true, professional: professional)
            modelContext.insert(newPolicy)
            professional.pricingAdjustmentPolicy = newPolicy
            policy = newPolicy
        }

        policy.lastSuggestionDismissedAt = .now

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// La vista escribe directo sobre el Professional vivo y persiste enseguida
    /// para que la preferencia impacte en altas futuras sin depender de otro
    /// formulario intermedio.
    private var defaultPatientCurrencyBinding: Binding<String> {
        Binding(
            get: { professional.defaultPatientCurrencyCode },
            set: { newValue in
                updateDefaultPatientCurrency(to: newValue)
            }
        )
    }

    @MainActor
    private func updateDefaultPatientCurrency(to newValue: String) {
        let normalizedCurrency = newValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard professional.defaultPatientCurrencyCode != normalizedCurrency else {
            return
        }

        professional.defaultPatientCurrencyCode = normalizedCurrency
        professional.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Mantiene consistente la preferencia sugerida del profesional.
    /// Si cambia el catálogo y la selección guardada ya no aplica, se corrige
    /// automáticamente para que la siguiente sesión nueva abra con un tipo válido.
    @MainActor
    private func normalizeSuggestedFinancialSessionTypeIfNeeded(
        using viewModel: SessionTypeBusinessViewModel
    ) {
        let activeSnapshots = HonorariosSuggestedTypeRules.activeSnapshots(
            from: viewModel.snapshots
        )
        let normalizedID = HonorariosSuggestedTypeRules.resolvedDefaultSessionTypeID(
            defaultSessionTypeID: professional.defaultFinancialSessionTypeID,
            activeSnapshots: activeSnapshots
        )

        guard professional.defaultFinancialSessionTypeID != normalizedID else {
            return
        }

        professional.defaultFinancialSessionTypeID = normalizedID
        professional.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func suggestedSessionTypeSection(
        activeSnapshots: [SessionTypeBusinessSnapshot]
    ) -> some View {
        Section {
            if activeSnapshots.count == 1, let onlySnapshot = activeSnapshots.first {
                LabeledContent(L10n.tr("honorarios.default_session_type")) {
                    Text(onlySnapshot.sessionType.name)
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker(
                    L10n.tr("honorarios.default_session_type"),
                    selection: suggestedFinancialSessionTypeBinding(
                        activeSnapshots: activeSnapshots
                    )
                ) {
                    ForEach(activeSnapshots, id: \.sessionType.id) { snapshot in
                        Text(snapshot.sessionType.name)
                            .tag(snapshot.sessionType.id)
                    }
                }
            }
        } header: {
            Text(L10n.tr("honorarios.new_sessions"))
        } footer: {
            Text(
                activeSnapshots.count == 1
                ? L10n.tr("honorarios.default_session_type_single_footer")
                : L10n.tr("honorarios.default_session_type_footer")
            )
        }
    }

    /// La vista persiste la preferencia en Professional para que impacte de
    /// inmediato en sesiones nuevas sin recalcular nada adicional en la captura.
    private func suggestedFinancialSessionTypeBinding(
        activeSnapshots: [SessionTypeBusinessSnapshot]
    ) -> Binding<UUID> {
        Binding(
            get: {
                HonorariosSuggestedTypeRules.resolvedDefaultSessionTypeID(
                    defaultSessionTypeID: professional.defaultFinancialSessionTypeID,
                    activeSnapshots: activeSnapshots
                ) ?? activeSnapshots.first?.sessionType.id ?? UUID()
            },
            set: { newValue in
                updateDefaultFinancialSessionType(to: newValue)
            }
        )
    }

    @MainActor
    private func updateDefaultFinancialSessionType(to newValue: UUID) {
        guard professional.defaultFinancialSessionTypeID != newValue else {
            return
        }

        professional.defaultFinancialSessionTypeID = newValue
        professional.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct UpdateSheetState: Identifiable {
    let snapshot: SessionTypeBusinessSnapshot

    var id: UUID {
        snapshot.sessionType.id
    }
}

private struct SessionTypeManagementSheetState: Identifiable {
    let snapshot: SessionTypeBusinessSnapshot

    var id: UUID {
        snapshot.sessionType.id
    }
}

private struct HonorariosSessionTypeCard: View {

    let snapshot: SessionTypeBusinessSnapshot
    let isSuggestedDefault: Bool
    let isHighlighted: Bool
    let onDismissHighlight: () -> Void
    let onRequestUpdate: () -> Void
    let onManageType: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 10) {
                metricLine(effectiveFromText)
                metricLine(
                    L10n.tr(
                        "honorarios.ipc_accumulated",
                        snapshot.ipcAccumulated.formattedPercent()
                    )
                )
                metricLine(
                    L10n.tr(
                        "honorarios.last_update_months",
                        "\(snapshot.monthsSinceLastUpdate)"
                    )
                )
            }

            if isHighlighted {
                suggestionHighlight
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var header: some View {
        let colorToken = snapshot.sessionType.resolvedColorToken

        return HStack(alignment: .top, spacing: 12) {
            SessionTypeIconBadge(
                symbolName: snapshot.sessionType.resolvedSymbolName,
                colorToken: colorToken,
                frameSize: 48,
                symbolSize: 20
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.sessionType.name)
                    .font(.headline)

                Text(currentPriceText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if isSuggestedDefault {
                    Text(L10n.tr("honorarios.default_session_type_badge"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colorToken.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(colorToken.softFill)
                        )
                }
            }

            Spacer(minLength: 0)

            Button(action: onManageType) {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Administrar \(snapshot.sessionType.name)")
        }
    }

    private func metricLine(_ value: String) -> some View {
        Text(value)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var suggestionHighlight: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.wiggle, options: .nonRepeating)

                Text(L10n.tr("honorarios.suggest_update"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 10) {
                Button(L10n.tr("honorarios.update")) {
                    onRequestUpdate()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                Button(L10n.tr("honorarios.dismiss")) {
                    onDismissHighlight()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }

    private var currentPriceText: String {
        guard let price = snapshot.currentPrice else {
            return L10n.tr("honorarios.no_current_price")
        }

        return price.formattedCurrency(code: snapshot.currentCurrencyCode ?? "")
    }

    private var effectiveFromText: String {
        guard let effectiveFrom = snapshot.effectiveFrom else {
            return L10n.tr("honorarios.no_effective_from")
        }

        return L10n.tr(
            "honorarios.effective_from",
            effectiveFrom.formatted(date: .abbreviated, time: .omitted)
        )
    }
}
