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

    var body: some View {
        VStack(spacing: 0) {
            calendarSection

            Divider()
                .padding(.horizontal)

            sessionListForSelectedDay
        }
        .navigationTitle("Calendario")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.goToToday()
                    }
                    viewModel.loadSessions(in: modelContext)
                } label: {
                    Text("Hoy")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSession = true
                } label: {
                    Image(systemName: "plus")
                }
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
        .padding(.bottom, 12)
    }

    // MARK: - Cabecera de navegación de mes

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.goToPreviousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Spacer()

            Text(monthYearText)
                .font(.title3)
                .fontWeight(.bold)
                .contentTransition(.numericText())

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
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
        let formatted = viewModel.displayedMonth.formatted(
            .dateTime.month(.wide).year()
        )
        return formatted.prefix(1).uppercased() + formatted.dropFirst()
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
        let days = viewModel.calendarDays()
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
                        withAnimation(.easeInOut(duration: 0.2)) {
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

    private var sessionListForSelectedDay: some View {
        let sessions = viewModel.sessionsForSelectedDate

        return Group {
            if let selectedDate = viewModel.selectedDate {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("Sin sesiones", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text(selectedDate.formatted(
                            .dateTime.weekday(.wide).day().month(.wide)
                        ))
                    }
                    .frame(maxHeight: .infinity)
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
                        } header: {
                            Text(selectedDate.formatted(
                                .dateTime.weekday(.wide).day().month(.wide)
                            ))
                        }
                    }
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
                // Fondo circular
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)

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
        HStack(spacing: 12) {
            // Hora a la izquierda
            Text(session.sessionDate.formatted(date: .omitted, time: .shortened))
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
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case "programada": .blue
        case "completada": .green
        case "cancelada": .red
        default: .secondary
        }
    }

    private var statusIcon: String {
        switch session.status {
        case "programada": "clock"
        case "completada": "checkmark.circle.fill"
        case "cancelada": "xmark.circle.fill"
        default: "questionmark.circle"
        }
    }

    private var modalityLabel: String {
        switch session.sessionType {
        case "presencial": "Presencial"
        case "videollamada": "Video"
        case "telefónica": "Tel."
        default: session.sessionType
        }
    }

    private var modalityIcon: String {
        switch session.sessionType {
        case "presencial": "person.2.wave.2"
        case "videollamada": "video"
        case "telefónica": "phone"
        default: "questionmark"
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self, AnthropometricRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
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
