//
//  CalendarView.swift
//  Ars Medica Digitalis
//
//  Vista de calendario mensual que muestra las sesiones agendadas
//  de todos los pacientes. Permite navegar entre meses, ver sesiones
//  por día y crear nuevas sesiones asignándolas a un paciente.
//

import SwiftUI
import SwiftData

struct CalendarView: View {

    let professional: Professional

    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel = CalendarViewModel()

    @State private var showingNewSession: Bool = false
    @State private var isCalendarCollapsed: Bool = false
    @State private var sessionListOffset: CGFloat = 0

    private let collapseThreshold: CGFloat = 24
    private let expandOverscrollThreshold: CGFloat = -22

    var body: some View {
        VStack(spacing: 0) {
            calendarSection

            sessionListForSelectedDay
        }
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle(monthYearText)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.smooth(duration: 0.30)) {
                        viewModel.goToToday()
                    }
                    viewModel.loadSessions(in: modelContext)
                } label: {
                    Text("Hoy")
                }
                .buttonStyle(.glass)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSession = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Nueva sesión")
            }
        }
        .sheet(isPresented: $showingNewSession, onDismiss: {
            viewModel.loadSessions(in: modelContext)
        }) {
            NavigationStack {
                PatientPickerView(
                    professional: professional,
                    initialDate: viewModel.selectedDate
                )
            }
        }
        .onAppear {
            // Seleccionar hoy por defecto para evitar estado "vacío"
            if viewModel.selectedDate == nil {
                viewModel.selectedDate = Date()
            }
            viewModel.loadSessions(in: modelContext)
        }
        .onChange(of: viewModel.displayedMonth) {
            viewModel.loadSessions(in: modelContext)
        }
    }

    // MARK: - Sección del calendario (cabecera + grilla)

    private var calendarSection: some View {
        VStack(spacing: 12) {
            monthNavigationHeader
            weekdayHeader
            calendarGrid
        }
        .padding(.bottom, isCalendarCollapsed ? 8 : 20)
        .animation(.smooth(duration: 0.22), value: isCalendarCollapsed)
    }

    // MARK: - Cabecera de navegación de mes

    // El mes se muestra en el navigationSubtitle; aquí solo los botones de navegación.
    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.smooth(duration: 0.30)) {
                    viewModel.goToPreviousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Spacer()

            Button {
                withAnimation(.smooth(duration: 0.30)) {
                    viewModel.goToNextMonth()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
    }

    /// Texto del mes capitalizado (ej: "Febrero 2026")
    private var monthYearText: String {
        // Ej: "Feb 2026" en español abreviado
        var style = Date.FormatStyle.dateTime
            .month(.abbreviated)
            .year(.defaultDigits)
        style.locale = Locale(identifier: "es_AR")
        return viewModel.displayedMonth.formatted(style)
    }

    // MARK: - Días de la semana

    private var weekdayHeader: some View {
        let days = ["L", "M", "X", "J", "V", "S", "D"]
        return LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Grilla del calendario

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    private var calendarGrid: some View {
        let days = isCalendarCollapsed ? viewModel.selectedWeekDays() : viewModel.calendarDays()
        let sessionCounts = viewModel.sessionCountsByDay

        return LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    CalendarDayCell(
                        day: day,
                        isSelected: viewModel.isSelected(day),
                        isToday: viewModel.isToday(day),
                        sessionCount: sessionCounts[day, default: 0]
                    )
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.20)) {
                            viewModel.selectedDate = viewModel.date(forDay: day)
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Lista de sesiones del día seleccionado

    @ViewBuilder
    private var sessionListForSelectedDay: some View {
        let sessions = viewModel.sessionsForSelectedDate

        if let selectedDate = viewModel.selectedDate {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("Sin sesiones", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text(selectedDate.formatted(
                        Date.FormatStyle.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "es_AR"))
                    ))
                }
                .frame(maxHeight: .infinity)
                .onAppear {
                    setCalendarCollapsed(false)
                }
            } else {
                List {
                    Section {
                        ForEach(sessions) { session in
                            if let patient = session.patient {
                                NavigationLink {
                                    SessionDetailView(
                                        session: session,
                                        patient: patient,
                                        professional: professional
                                    )
                                } label: {
                                    CalendarSessionRow(session: session)
                                }
                            } else {
                                CalendarSessionRow(session: session)
                            }
                        }
                        // Filas flotantes sobre fondo glass de la app
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    } header: {
                        Text(selectedDate.formatted(
                            Date.FormatStyle.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "es_AR"))
                        ))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .all)
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    },
                    action: { _, offset in
                        sessionListOffset = offset
                        handleSessionListScroll(offset)
                    }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            // Fallback explícito: swipe hacia arriba colapsa siempre.
                            if value.translation.height < -18 {
                                setCalendarCollapsed(true)
                            } else if value.translation.height > 18, sessionListOffset <= 0 {
                                // Expandir solo en gesto hacia abajo cerca del tope.
                                setCalendarCollapsed(false)
                            }
                        }
                )
            }
        } else {
            ContentUnavailableView(
                "Seleccioná un día",
                systemImage: "calendar",
                description: Text("Tocá un día para ver sus sesiones.")
            )
            .frame(maxHeight: .infinity)
        }
    }

    private func handleSessionListScroll(_ offset: CGFloat) {
        if offset > collapseThreshold, !isCalendarCollapsed {
            setCalendarCollapsed(true)
        } else if offset < expandOverscrollThreshold, isCalendarCollapsed {
            setCalendarCollapsed(false)
        }
    }

    private func setCalendarCollapsed(_ collapsed: Bool) {
        withAnimation(.smooth(duration: 0.22)) {
            isCalendarCollapsed = collapsed
        }
    }
}

// MARK: - Celda de día

private struct CalendarDayCell: View {

    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let sessionCount: Int

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Fondo circular: el día seleccionado es ligeramente más grande
                // y proyecta una sombra acent para mayor protagonismo visual.
                Circle()
                    .fill(backgroundColor)
                    .frame(
                        width: isSelected ? 38 : 36,
                        height: isSelected ? 38 : 36
                    )
                    .shadow(
                        color: isSelected ? .accentColor.opacity(0.35) : .clear,
                        radius: 5, y: 2
                    )

                // Anillo de hoy cuando no está seleccionado
                if isToday && !isSelected {
                    Circle()
                        .strokeBorder(.tint, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                Text("\(day)")
                    .font(.callout)
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundStyle(foregroundColor)
            }

            // Indicador: hasta 3 puntos según cantidad de sesiones
            HStack(spacing: 2) {
                let dots = min(sessionCount, 3)
                ForEach(0..<dots, id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? .white.opacity(0.8) : Color.accentColor)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        if isSelected { return .accentColor }
        return .clear
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }
}

// MARK: - Fila de sesión en el calendario

private struct CalendarSessionRow: View {

    let session: Session

    var body: some View {
        CardContainer(style: .flat) {
            HStack(spacing: 12) {
                // Hora a la izquierda
                Text(session.sessionDate.esShortTime())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .leading)

                // Barra lateral de color según status
                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor)
                    .frame(width: 3, height: 36)

                // Contenido principal
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.patient?.fullName ?? "Sin paciente")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 6) {
                        Label(modalityLabel, systemImage: modalityIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !session.chiefComplaint.isEmpty {
                            Text("·")
                                .foregroundStyle(.secondary)

                            Text(session.chiefComplaint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Ícono de status a la derecha
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusColor: Color {
        statusMapping?.tint ?? .secondary
    }

    private var statusIcon: String {
        statusMapping?.icon ?? "questionmark.circle"
    }

    private var modalityLabel: String {
        sessionTypeMapping?.abbreviatedLabel ?? session.sessionType
    }

    private var modalityIcon: String {
        sessionTypeMapping?.icon ?? "questionmark"
    }

    private var sessionTypeMapping: SessionTypeMapping? {
        SessionTypeMapping(sessionTypeRawValue: session.sessionType)
    }

    private var statusMapping: SessionStatusMapping? {
        SessionStatusMapping(sessionStatusRawValue: session.status)
    }
}

#Preview {
    let container = ModelContainer.preview
    let professional = Professional(
        fullName: "Dr. Test",
        licenseNumber: "MN 999",
        specialty: "Psicología"
    )
    container.mainContext.insert(professional)

    return NavigationStack {
        CalendarView(professional: professional)
    }
    .modelContainer(container)
}
