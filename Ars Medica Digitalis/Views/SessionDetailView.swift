//
//  SessionDetailView.swift
//  Ars Medica Digitalis
//
//  Vista de lectura de una sesión clínica (HU-04, HU-05).
//  Muestra todos los campos de la sesión y los diagnósticos CIE-11
//  persistidos como snapshot — nunca llama a la API externa.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {

    @Environment(\.modelContext) private var modelContext

    let session: Session
    let patient: Patient
    let professional: Professional

    @State private var viewModel = SessionViewModel()
    @State private var showingEdit: Bool = false
    @State private var showingStatusPicker: Bool = false
    @State private var showAllDiagnoses = false
    @State private var sessionActionErrorMessage: String?
    @State private var completionDraft: CompletionDraft?

    private static let diagnosisVisibleLimit = 3

    var body: some View {
        List {
            // MARK: - Datos de la Sesión
            Section("Datos de la Sesión") {
                LabeledContent("Fecha", value: session.sessionDate.formatted(date: .long, time: .shortened))
                LabeledContent("Modalidad", value: sessionTypeLabel)
                LabeledContent("Duración", value: "\(session.durationMinutes) min")
                LabeledContent("Estado") {
                    statusControl
                }

                if canCompleteSession {
                    Button(completionButtonLabel) {
                        openCompletionFlow()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Abre el flujo de cierre y cobro de la sesión")
                }

                if !session.chiefComplaint.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Motivo de consulta")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(session.chiefComplaint)
                    }
                }
            }

            // MARK: - Finanzas
            Section("Finanzas") {
                LabeledContent("Tipo facturable", value: financialSessionTypeLabel)
                LabeledContent("Moneda", value: effectiveCurrencyLabel)
                LabeledContent(session.isCompleted ? "Precio final" : "Precio", value: session.effectivePrice.formattedCurrency(code: session.effectiveCurrency))
                LabeledContent("Cobrado", value: session.totalPaid.formattedCurrency(code: session.effectiveCurrency))

                if session.isCourtesy {
                    HStack {
                        Text("Tipo")
                        Spacer()
                        Text("Cortesía")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                } else {
                    LabeledContent("Deuda", value: session.debt.formattedCurrency(code: session.effectiveCurrency))
                }

                LabeledContent("Estado de pago") {
                    Text(paymentStateLabel)
                        .foregroundStyle(paymentStateTint)
                }
            }

            // MARK: - Diagnósticos CIE-11
            let diagnoses = session.diagnoses
            if !diagnoses.isEmpty {
                Section {
                    let visible = showAllDiagnoses
                        ? diagnoses
                        : Array(diagnoses.prefix(Self.diagnosisVisibleLimit))

                    ForEach(visible) { diagnosis in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diagnosis.displayTitle)
                                .font(.body)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                if !diagnosis.icdCode.isEmpty {
                                    Text(diagnosis.icdCode)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }

                                Text(diagnosis.diagnosisTypeValue.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if !diagnosis.clinicalNotes.isEmpty {
                                Text(diagnosis.clinicalNotes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    let hiddenCount = diagnoses.count - Self.diagnosisVisibleLimit
                    if hiddenCount > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllDiagnoses.toggle()
                            }
                        } label: {
                            Label(
                                showAllDiagnoses
                                    ? "Mostrar menos"
                                    : "Ver \(hiddenCount) diagnóstico\(hiddenCount == 1 ? "" : "s") más",
                                systemImage: showAllDiagnoses ? "chevron.up" : "chevron.down"
                            )
                            .font(.footnote)
                            .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Diagnósticos CIE-11")
                        Text("\(diagnoses.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
            }

            // MARK: - Notas y Plan
            if !session.notes.isEmpty || !session.treatmentPlan.isEmpty {
                Section("Notas y Plan") {
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notas clínicas")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(session.notes)
                                .lineHeight(.multiple(factor: 1.4))
                        }
                    }

                    if !session.treatmentPlan.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Plan de tratamiento")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(session.treatmentPlan)
                                .lineHeight(.multiple(factor: 1.4))
                        }
                    }
                }
            }

            // MARK: - Trazabilidad
            Section {
                LabeledContent("Creado", value: session.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Modificado", value: session.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .navigationTitle("Sesión")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Editar sesión")
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                SessionFormView(patient: patient, session: session)
            }
        }
        .sheet(item: $completionDraft) { draft in
            PaymentFlowView(draft: draft, onCancel: {}) { paymentIntent in
                // La ejecución real se mantiene en el ViewModel para que
                // completar y registrar Payment sigan un único camino.
                try viewModel.completeSession(session, in: modelContext, paymentIntent: paymentIntent)
            }
        }
        .confirmationDialog("Cambiar estado", isPresented: $showingStatusPicker, titleVisibility: .visible) {
            if session.status != SessionStatusMapping.programada.rawValue {
                Button(SessionStatusMapping.programada.label) {
                    applyStatusChange(.programada)
                }
            }
            if session.status != SessionStatusMapping.cancelada.rawValue {
                Button(SessionStatusMapping.cancelada.label, role: .destructive) {
                    applyStatusChange(.cancelada)
                }
            }
        }
        .alert("No se pudo actualizar la sesión", isPresented: sessionActionErrorBinding) {
            Button("Aceptar", role: .cancel) {
                sessionActionErrorMessage = nil
            }
        } message: {
            Text(sessionActionErrorMessage ?? "Ocurrió un error al persistir el cambio de estado.")
        }
    }

    // MARK: - Labels

    private var sessionTypeLabel: String {
        SessionTypeMapping(sessionTypeRawValue: session.sessionType)?.label
        ?? session.sessionType.capitalized
    }

    // MARK: - Status

    private var currentStatusMapping: SessionStatusMapping {
        SessionStatusMapping(sessionStatusRawValue: session.status) ?? .completada
    }

    @ViewBuilder
    private var statusControl: some View {
        if canChangeStatus {
            Button {
                showingStatusPicker = true
            } label: {
                statusLabel
            }
            .buttonStyle(.plain)
        } else {
            statusLabel
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: currentStatusMapping.icon)
            Text(currentStatusMapping.label)
        }
        .foregroundStyle(currentStatusMapping.tint)
    }

    private var canChangeStatus: Bool {
        session.sessionStatusValue != .completada
    }

    private var canCompleteSession: Bool {
        session.sessionStatusValue == .programada
    }

    private var completionButtonLabel: String {
        session.isCourtesy ? "Completar cortesía" : "Completar sesión"
    }

    private var effectiveCurrencyLabel: String {
        session.effectiveCurrency.isEmpty ? "Sin definir" : session.effectiveCurrency
    }

    private var financialSessionTypeLabel: String {
        if session.isCourtesy {
            return "Cortesía"
        }

        return viewModel.effectiveFinancialSessionTypeName(for: session) ?? "Sin definir"
    }

    private var paymentStateLabel: String {
        switch session.paymentState {
        case .unpaid: "Sin pago"
        case .paidPartial: "Pago parcial"
        case .paidFull: "Pago completo"
        }
    }

    private var paymentStateTint: Color {
        switch session.paymentState {
        case .unpaid: .red
        case .paidPartial: .orange
        case .paidFull: .green
        }
    }

    @MainActor
    private func applyStatusChange(_ newStatus: SessionStatusMapping) {
        do {
            try viewModel.applyStatusChange(newStatus, to: session, in: modelContext)
        } catch {
            sessionActionErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openCompletionFlow() {
        completionDraft = viewModel.preparePaymentFlow(for: session)
    }

    private var sessionActionErrorBinding: Binding<Bool> {
        Binding(
            get: { sessionActionErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    sessionActionErrorMessage = nil
                }
            }
        )
    }

}

#Preview {
    let container = ModelContainer.preview
    let professional = Professional(fullName: "Dr. Test", licenseNumber: "MN 999", specialty: "Psicología")
    container.mainContext.insert(professional)

    let patient = Patient(firstName: "Ana", lastName: "García", professional: professional)
    container.mainContext.insert(patient)

    let session = Session(
        notes: "Paciente refiere aumento de síntomas en las últimas 2 semanas.",
        chiefComplaint: "Ansiedad generalizada con episodios de pánico",
        treatmentPlan: "Continuar terapia cognitivo-conductual. Evaluar derivación a psiquiatría.",
        patient: patient
    )
    container.mainContext.insert(session)

    let diagnosis = Diagnosis(
        icdCode: "6B00",
        icdTitle: "Generalised anxiety disorder",
        icdTitleEs: "Trastorno de ansiedad generalizada",
        icdURI: "http://id.who.int/icd/entity/1712535455",
        session: session
    )
    container.mainContext.insert(diagnosis)

    return NavigationStack {
        SessionDetailView(session: session, patient: patient, professional: professional)
    }
    .modelContainer(container)
}
