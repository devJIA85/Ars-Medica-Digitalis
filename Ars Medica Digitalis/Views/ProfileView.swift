//
//  ProfileView.swift
//  Ars Medica Digitalis
//
//  Dashboard de perfil profesional con arquitectura de secciones reutilizables.
//

import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let professional: Professional

    @State private var viewModel = ProfessionalViewModel()
    @State private var showingFinanceDashboard: Bool = false
    @State private var showingHonorarios: Bool = false
    @State private var saveErrorMessage: String?

    private enum ScrollTarget: Hashable {
        case professionalData
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.sectionGap) {
                    ProfileHeaderSection(
                        fullName: viewModel.fullName,
                        professionalTitle: viewModel.specialty,
                        initials: professionalInitials,
                        onEdit: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(ScrollTarget.professionalData, anchor: .top)
                            }
                        }
                    )

                    StatisticsSection(
                        professional: professional,
                        onShowFinances: { showingFinanceDashboard = true },
                        onShowFees: { showingHonorarios = true }
                    )

                    // MARK: - Ajustes
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
                        .glassCardEntrance()
                    }
                    .buttonStyle(.plain)

                    FinanceSection(
                        defaultPatientCurrencyCode: $viewModel.defaultPatientCurrencyCode,
                        defaultFinancialSessionTypeID: $viewModel.defaultFinancialSessionTypeID,
                        sessionTypes: activeSessionTypes,
                        onManageFees: { showingHonorarios = true }
                    )

                    ProfessionalDataSection(
                        fullName: $viewModel.fullName,
                        professionalTitle: $viewModel.specialty,
                        licenseNumber: $viewModel.licenseNumber
                    )
                    .id(ScrollTarget.professionalData)

                    ContactSection(email: $viewModel.email)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
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

    private var professionalInitials: String? {
        let name = viewModel.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return nil }

        let parts = name.split(separator: " ")
        if parts.count >= 2,
           let first = parts.first?.prefix(1),
           let last = parts.last?.prefix(1) {
            return "\(first)\(last)".uppercased()
        }

        return String(name.prefix(1)).uppercased()
    }
    private var settingsChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

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
