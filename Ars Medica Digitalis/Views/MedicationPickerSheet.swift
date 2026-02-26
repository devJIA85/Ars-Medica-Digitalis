//
//  MedicationPickerSheet.swift
//  Ars Medica Digitalis
//
//  Búsqueda y selección múltiple de medicamentos con opción
//  de alta local cuando no existe en el catálogo.
//

import SwiftUI
import SwiftData

struct MedicationPickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    @Query(
        sort: [
            SortDescriptor(\Medication.principioActivo),
            SortDescriptor(\Medication.nombreComercial),
        ]
    )
    private var medications: [Medication]

    @Binding var selectedMedications: [Medication]

    @State private var searchText: String = ""
    @State private var showingNewMedicationForm: Bool = false
    @State private var infoMedication: Medication? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Seleccionados: \(selectedMedications.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if filteredMedications.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Sin resultados",
                            systemImage: "pills",
                            description: Text("No hay coincidencias en el catálogo. Podés cargar un medicamento local.")
                        )

                        Button {
                            showingNewMedicationForm = true
                        } label: {
                            Label("Cargar medicamento local", systemImage: "plus.circle")
                        }
                    }
                } else {
                    Section("Resultados") {
                        ForEach(filteredMedications) { medication in
                            MedicationSelectableRow(
                                medication: medication,
                                isSelected: isSelected(medication),
                                onToggle: {
                                    toggleSelection(for: medication)
                                },
                                onInfo: {
                                    infoMedication = medication
                                }
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar por principio activo o nombre comercial")
            .navigationTitle("Agregar medicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewMedicationForm = true
                    } label: {
                        Label("Nuevo", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewMedicationForm) {
                NavigationStack {
                    NewMedicationFormView { newMedication in
                        if !isSelected(newMedication) {
                            selectedMedications.append(newMedication)
                        }
                    }
                }
            }
            .sheet(item: $infoMedication) { medication in
                NavigationStack {
                    MedicationInfoSheetView(medication: medication)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Listo") {
                                    infoMedication = nil
                                }
                            }
                        }
                }
            }
        }
    }

    private var filteredMedications: [Medication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return Array(medications.prefix(100))
        }

        // Mínimo 2 caracteres para filtrar el catálogo completo.
        guard query.count >= 2 else {
            return Array(medications.prefix(100))
        }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // Acumular resultados con cap para no iterar todo si ya encontramos suficientes.
        var results: [Medication] = []
        let maxResults = 80

        for medication in medications {
            let principio = medication.principioActivo.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let comercial = medication.nombreComercial.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            if principio.localizedCaseInsensitiveContains(normalizedQuery)
                || comercial.localizedCaseInsensitiveContains(normalizedQuery)
            {
                results.append(medication)
                if results.count >= maxResults { break }
            }
        }

        return results
    }

    private func isSelected(_ medication: Medication) -> Bool {
        selectedMedications.contains { $0.id == medication.id }
    }

    private func toggleSelection(for medication: Medication) {
        if let index = selectedMedications.firstIndex(where: { $0.id == medication.id }) {
            selectedMedications.remove(at: index)
        } else {
            selectedMedications.append(medication)
        }
    }
}

private struct MedicationSelectableRow: View {

    let medication: Medication
    let isSelected: Bool
    let onToggle: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.primaryDisplayName)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(medication.secondaryDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }

            Button {
                onInfo()
            } label: {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

private struct NewMedicationFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\Medication.principioActivo),
            SortDescriptor(\Medication.nombreComercial),
        ]
    )
    private var medications: [Medication]

    let onCreate: (Medication) -> Void

    @State private var principioActivo: String = ""
    @State private var nombreComercial: String = ""
    @State private var potencia: String = ""
    @State private var potenciaValor: String = ""
    @State private var potenciaUnidad: String = ""
    @State private var contenido: String = ""
    @State private var presentacion: String = ""
    @State private var laboratorio: String = ""

    // Deduplicación debounceada para no bloquear cada keystroke.
    @State private var potentialDuplicates: [MedicationDuplicateMatch] = []
    @State private var debouncedDraftHash: String = ""

    /// Hash de los campos del draft para disparar recomputo debounceado.
    private var draftHash: String {
        "\(principioActivo.trimmed)|\(nombreComercial.trimmed)|\(potencia.trimmed)|\(potenciaValor.trimmed)|\(potenciaUnidad.trimmed)|\(contenido.trimmed)|\(presentacion.trimmed)|\(laboratorio.trimmed)"
    }

    var body: some View {
        Form {
            Section("Nuevo medicamento") {
                TextField("Principio activo", text: $principioActivo)
                TextField("Nombre comercial", text: $nombreComercial)
                TextField("Potencia", text: $potencia)
                TextField("Potencia valor", text: $potenciaValor)
                TextField("Potencia unidad", text: $potenciaUnidad)
                TextField("Contenido", text: $contenido)
                TextField("Presentacion", text: $presentacion)
                TextField("Laboratorio", text: $laboratorio)
            }

            if !potentialDuplicates.isEmpty {
                Section {
                    ForEach(potentialDuplicates) { match in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.medication.primaryDisplayName)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    Text(match.medication.secondaryDisplayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                Text("\(Int((match.score * 100).rounded()))%")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }

                            Button {
                                onCreate(match.medication)
                                dismiss()
                            } label: {
                                Label("Usar existente", systemImage: "arrow.uturn.backward.circle")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Posibles duplicados")
                } footer: {
                    if hasStrongDuplicate {
                        Text("Ya existe un medicamento casi idéntico. Usá \"Usar existente\" o modificá los campos para diferenciarlo.")
                    } else {
                        Text("Sugerencias para evitar cargar variantes casi iguales del mismo medicamento.")
                    }
                }
            }
        }
        .navigationTitle("Medicamento local")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    if let strictMatch = potentialDuplicates.first(where: \.isStrictDuplicate) {
                        // Reusar exacto normalizado en lugar de crear duplicado.
                        onCreate(strictMatch.medication)
                        dismiss()
                        return
                    }

                    let medication = Medication(
                        principioActivo: principioActivo.trimmed,
                        nombreComercial: nombreComercial.trimmed,
                        potencia: potencia.trimmed,
                        potenciaValor: potenciaValor.trimmed,
                        potenciaUnidad: potenciaUnidad.trimmed,
                        contenido: contenido.trimmed,
                        presentacion: presentacion.trimmed,
                        laboratorio: laboratorio.trimmed,
                        isUserCreated: true
                    )

                    modelContext.insert(medication)
                    onCreate(medication)
                    dismiss()
                }
                .disabled(!canSave || (hasStrongDuplicate && !hasStrictDuplicate))
            }
        }
        // Recomputa duplicados solo tras 300ms sin typear.
        .onChange(of: draftHash) { oldValue, newValue in
            guard oldValue != newValue else { return }
            debouncedDraftHash = newValue
        }
        .task(id: debouncedDraftHash) {
            guard !debouncedDraftHash.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            potentialDuplicates = MedicationDeduplicationEngine.findMatches(for: draft, in: medications)
        }
    }

    private var canSave: Bool {
        !principioActivo.trimmed.isEmpty || !nombreComercial.trimmed.isEmpty
    }

    private var draft: MedicationDraft {
        MedicationDraft(
            principioActivo: principioActivo.trimmed,
            nombreComercial: nombreComercial.trimmed,
            potencia: potencia.trimmed,
            potenciaValor: potenciaValor.trimmed,
            potenciaUnidad: potenciaUnidad.trimmed,
            contenido: contenido.trimmed,
            presentacion: presentacion.trimmed,
            laboratorio: laboratorio.trimmed
        )
    }

    private var hasStrongDuplicate: Bool {
        potentialDuplicates.contains(where: { $0.score >= 0.97 })
    }

    private var hasStrictDuplicate: Bool {
        potentialDuplicates.contains(where: \.isStrictDuplicate)
    }
}

private struct MedicationDraft {
    let principioActivo: String
    let nombreComercial: String
    let potencia: String
    let potenciaValor: String
    let potenciaUnidad: String
    let contenido: String
    let presentacion: String
    let laboratorio: String

    var hasMinimumData: Bool {
        !principioActivo.isBlank || !nombreComercial.isBlank
    }

    var strictKey: String {
        [
            principioActivo.normalizedForDedup,
            nombreComercial.normalizedForDedup,
            potencia.normalizedForDedup,
            potenciaValor.normalizedForDedup,
            potenciaUnidad.normalizedForDedup,
            contenido.normalizedForDedup,
            presentacion.normalizedForDedup,
            laboratorio.normalizedForDedup,
        ].joined(separator: "|")
    }
}

private struct MedicationDuplicateMatch: Identifiable {
    let medication: Medication
    let score: Double
    let isStrictDuplicate: Bool

    var id: UUID { medication.id }
}

private enum MedicationDeduplicationEngine {

    static func findMatches(for draft: MedicationDraft, in medications: [Medication]) -> [MedicationDuplicateMatch] {
        guard draft.hasMinimumData else { return [] }

        let draftActive = draft.principioActivo.normalizedForDedup
        let draftBrand = draft.nombreComercial.normalizedForDedup

        return medications.compactMap { medication in
            let match = score(draft: draft, against: medication)
            guard match.score >= 0.76 || match.isStrictDuplicate else { return nil }

            // Filtro rápido: al menos una coincidencia razonable en núcleo (activo/comercial).
            let medicationActive = medication.principioActivo.normalizedForDedup
            let medicationBrand = medication.nombreComercial.normalizedForDedup
            let hasCoreOverlap =
                textSimilarity(draftActive, medicationActive) >= 0.55
                || textSimilarity(draftBrand, medicationBrand) >= 0.55

            guard hasCoreOverlap || match.isStrictDuplicate else { return nil }
            return match
        }
        .sorted {
            if abs($0.score - $1.score) < 0.001 {
                return $0.medication.primaryDisplayName.localizedCaseInsensitiveCompare($1.medication.primaryDisplayName) == .orderedAscending
            }
            return $0.score > $1.score
        }
        .prefix(5)
        .map { $0 }
    }

    private static func score(draft: MedicationDraft, against medication: Medication) -> MedicationDuplicateMatch {
        let medicationDraft = MedicationDraft(
            principioActivo: medication.principioActivo,
            nombreComercial: medication.nombreComercial,
            potencia: medication.potencia,
            potenciaValor: medication.potenciaValor,
            potenciaUnidad: medication.potenciaUnidad,
            contenido: medication.contenido,
            presentacion: medication.presentacion,
            laboratorio: medication.laboratorio
        )

        let isStrictDuplicate = draft.strictKey == medicationDraft.strictKey

        let activeScore = textSimilarity(draft.principioActivo.normalizedForDedup, medication.principioActivo.normalizedForDedup)
        let brandScore = textSimilarity(draft.nombreComercial.normalizedForDedup, medication.nombreComercial.normalizedForDedup)
        let potencyScore = textSimilarity(
            "\(draft.potencia) \(draft.potenciaValor) \(draft.potenciaUnidad)".normalizedForDedup,
            "\(medication.potencia) \(medication.potenciaValor) \(medication.potenciaUnidad)".normalizedForDedup
        )
        let contentScore = textSimilarity(draft.contenido.normalizedForDedup, medication.contenido.normalizedForDedup)
        let presentationScore = textSimilarity(draft.presentacion.normalizedForDedup, medication.presentacion.normalizedForDedup)
        let labScore = textSimilarity(draft.laboratorio.normalizedForDedup, medication.laboratorio.normalizedForDedup)

        let score =
            (activeScore * 0.40)
            + (brandScore * 0.32)
            + (potencyScore * 0.10)
            + (contentScore * 0.04)
            + (presentationScore * 0.08)
            + (labScore * 0.06)

        return MedicationDuplicateMatch(
            medication: medication,
            score: isStrictDuplicate ? 1.0 : score,
            isStrictDuplicate: isStrictDuplicate
        )
    }

    private static func textSimilarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs.isEmpty && rhs.isEmpty { return 1.0 }
        if lhs.isEmpty || rhs.isEmpty { return 0.5 }
        if lhs == rhs { return 1.0 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return 0.92 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        let unionCount = lhsTokens.union(rhsTokens).count
        let overlap = unionCount == 0 ? 0.0 : Double(lhsTokens.intersection(rhsTokens).count) / Double(unionCount)

        let maxLen = max(lhs.count, rhs.count)
        let editComponent = maxLen == 0 ? 1.0 : 1.0 - (Double(levenshtein(lhs, rhs)) / Double(maxLen))

        return max(overlap, editComponent)
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)

        guard !left.isEmpty else { return right.count }
        guard !right.isEmpty else { return left.count }

        var previous = Array(0...right.count)
        for (leftIndex, leftChar) in left.enumerated() {
            var current = Array(repeating: 0, count: right.count + 1)
            current[0] = leftIndex + 1

            for (rightIndex, rightChar) in right.enumerated() {
                let insertion = current[rightIndex] + 1
                let deletion = previous[rightIndex + 1] + 1
                let substitution = previous[rightIndex] + (leftChar == rightChar ? 0 : 1)
                current[rightIndex + 1] = min(insertion, deletion, substitution)
            }
            previous = current
        }

        return previous[right.count]
    }
}

private extension String {
    var trimmedAndNewlines: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBlank: Bool {
        trimmedAndNewlines.isEmpty
    }

    var normalizedForDedup: String {
        let folded = folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let mapped = folded.unicodeScalars
            .map { scalar in
                CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
            }
            .joined()

        return mapped
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmedAndNewlines
    }
}
