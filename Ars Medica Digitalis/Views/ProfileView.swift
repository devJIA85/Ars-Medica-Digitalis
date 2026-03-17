//
//  ProfileView.swift
//  Ars Medica Digitalis
//
//  Dashboard de perfil profesional con arquitectura de secciones reutilizables.
//  Rediseñado con lenguaje Liquid Glass: 5 módulos semánticos, cabeceras externas
//  en small-caps y animación de entrada en cascada.
//

import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let professional: Professional

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = ProfessionalViewModel()
    @State private var showingFinanceDashboard: Bool = false
    @State private var showingHonorarios: Bool = false
    @State private var saveErrorMessage: String?

    // Controla la animación de entrada en cascada de los 5 módulos
    @State private var appeared: Bool = false

    private enum ScrollTarget: Hashable {
        case professionalData
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.sectionGap) {

                    // MARK: — Módulo 1: Identidad
                    ProfileHeaderSection(
                        fullName: viewModel.fullName,
                        professionalTitle: viewModel.specialty,
                        licenseNumber: viewModel.licenseNumber,
                        onEdit: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(ScrollTarget.professionalData, anchor: .top)
                            }
                        }
                    )
                    .moduleEntrance(appeared: appeared, delay: 0.00)

                    // MARK: — Módulo 2: Actividad
                    sectionHeader("Actividad")
                        .moduleEntrance(appeared: appeared, delay: 0.05)

                    StatisticsSection(
                        professional: professional,
                        onShowFinances: { showingFinanceDashboard = true },
                        onShowFees: { showingHonorarios = true }
                    )
                    .moduleEntrance(appeared: appeared, delay: 0.10)

                    // MARK: — Ajustes
                    NavigationLink {
                        ProfileSettingsView(professional: professional)
                    } label: {
                        CardContainer(style: .flat) {
                            HStack(spacing: AppSpacing.md) {
                                Label {
                                    Text("Ajustes")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: "gearshape")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: AppSpacing.md)
                                settingsChevron
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .moduleEntrance(appeared: appeared, delay: 0.15)

                    // MARK: — Módulo 3: Preferencias
                    sectionHeader("Preferencias")
                        .moduleEntrance(appeared: appeared, delay: 0.18)

                    FinanceSection(
                        defaultPatientCurrencyCode: $viewModel.defaultPatientCurrencyCode,
                        defaultFinancialSessionTypeID: $viewModel.defaultFinancialSessionTypeID,
                        sessionTypes: activeSessionTypes,
                        onManageFees: { showingHonorarios = true }
                    )
                    .moduleEntrance(appeared: appeared, delay: 0.20)

                    // MARK: — Módulo 4: Datos profesionales
                    sectionHeader("Datos profesionales")
                        .moduleEntrance(appeared: appeared, delay: 0.28)

                    ProfessionalDataSection(
                        fullName: $viewModel.fullName,
                        professionalTitle: $viewModel.specialty,
                        licenseNumber: $viewModel.licenseNumber
                    )
                    .id(ScrollTarget.professionalData)
                    .moduleEntrance(appeared: appeared, delay: 0.30)

                    // MARK: — Módulo 5: Contacto
                    sectionHeader("Contacto")
                        .moduleEntrance(appeared: appeared, delay: 0.38)

                    ContactSection(email: $viewModel.email)
                        .moduleEntrance(appeared: appeared, delay: 0.40)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            // Dispara la animación de entrada en cascada al aparecer la vista
            .onAppear {
                appeared = true
            }
        }
        .themedBackground()
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    saveProfile()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .task(id: professional.updatedAt) {
            await loadViewModel()
        }
        .sheet(isPresented: $showingFinanceDashboard) {
            FinanceDashboardView()
        }
        .sheet(isPresented: $showingHonorarios) {
            HonorariosView(professional: professional)
        }
        .alert("No se pudo guardar el perfil", isPresented: saveErrorBinding) {
            Button("Aceptar", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Intenta nuevamente.")
        }
    }

    // MARK: - Helpers

    /// Cabecera de sección en small-caps: texto en mayúsculas, Footnote Semibold, Secondary.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.sm)
    }

    @MainActor
    private func loadViewModel() async {
        viewModel.load(from: professional)
    }

    @MainActor
    private func saveProfile() {
        do {
            viewModel.update(professional)
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private var activeSessionTypes: [SessionCatalogType] {
        (professional.sessionCatalogTypes ?? [])
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                return lhs.sortOrder < rhs.sortOrder
            }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private var settingsChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - Animación de entrada en cascada

/// ViewModifier que aplica opacidad + offset Y con spring animado,
/// respetando la preferencia de accesibilidad "Reducir movimiento".
private struct ModuleEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : 20)
            .animation(
                reduceMotion
                    ? .easeIn(duration: 0.15)
                    : .spring(duration: 0.35, bounce: 0.2).delay(delay),
                value: appeared
            )
    }
}

private extension View {
    /// Aplica opacidad + offset Y con spring animado. delay en segundos.
    /// Respeta la preferencia del sistema "Reducir movimiento".
    func moduleEntrance(appeared: Bool, delay: Double) -> some View {
        modifier(ModuleEntranceModifier(appeared: appeared, delay: delay))
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: Professional.self,
        SessionCatalogType.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let professional = Professional(
        fullName: "Juan I. Antolini",
        licenseNumber: "MN 12345",
        specialty: "Licenciado en Psicologia",
        email: "juan@example.com",
        defaultPatientCurrencyCode: "ARS"
    )
    let sessionType = SessionCatalogType(
        name: "Consulta individual",
        professional: professional
    )
    professional.sessionCatalogTypes = [sessionType]
    professional.defaultFinancialSessionTypeID = sessionType.id
    context.insert(professional)
    context.insert(sessionType)

    return NavigationStack {
        ProfileView(professional: professional)
    }
    .modelContainer(container)
}
