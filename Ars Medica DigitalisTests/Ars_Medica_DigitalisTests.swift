import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct Ars_Medica_DigitalisTests {

    @Test("PatientViewModel.canSave valida trimming de nombre/apellido")
    func patientViewModelCanSaveWithTrimmedNames() {
        let viewModel = PatientViewModel()
        viewModel.firstName = "   "
        viewModel.lastName = "García"
        #expect(viewModel.canSave == false)

        viewModel.firstName = " Ana "
        viewModel.lastName = "   "
        #expect(viewModel.canSave == false)

        viewModel.lastName = " García "
        #expect(viewModel.canSave == true)
    }

    @Test("PatientViewModel.load copia campos principales desde Patient")
    func patientViewModelLoadCopiesFields() {
        let patient = Patient(
            firstName: "Ana",
            lastName: "García",
            gender: "femenino",
            currentMedication: "Ibuprofeno",
            clinicalStatus: ClinicalStatusMapping.riesgo.rawValue,
            smokingStatus: true
        )
        let viewModel = PatientViewModel()

        viewModel.load(from: patient)

        #expect(viewModel.firstName == "Ana")
        #expect(viewModel.lastName == "García")
        #expect(viewModel.gender == "femenino")
        #expect(viewModel.currentMedication == "Ibuprofeno")
        #expect(viewModel.clinicalStatus == ClinicalStatusMapping.riesgo.rawValue)
        #expect(viewModel.smokingStatus == true)
    }

    @Test("SessionViewModel ajusta status automáticamente según fecha")
    func sessionViewModelAdjustsStatusForDate() {
        let viewModel = SessionViewModel()

        viewModel.status = SessionStatusMapping.completada.rawValue
        viewModel.sessionDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(viewModel.status == SessionStatusMapping.programada.rawValue)

        viewModel.sessionDate = Date().addingTimeInterval(-60 * 60 * 24)
        #expect(viewModel.status == SessionStatusMapping.completada.rawValue)
    }

    @Test("SessionViewModel.preloadDiagnoses importa diagnósticos vigentes")
    func sessionViewModelPreloadsActiveDiagnoses() {
        let patient = Patient(firstName: "Test", lastName: "Patient")
        let diagnosis = Diagnosis(
            icdCode: "6A70",
            icdTitle: "Single episode depressive disorder",
            icdTitleEs: "Trastorno depresivo de episodio único",
            icdURI: "http://id.who.int/icd/release/11/2024-01/mms/6A70"
        )
        patient.activeDiagnoses = [diagnosis]

        let viewModel = SessionViewModel()
        viewModel.preloadDiagnoses(from: patient)

        #expect(viewModel.selectedDiagnoses.count == 1)
        #expect(viewModel.selectedDiagnoses.first?.id == diagnosis.icdURI)
        #expect(viewModel.selectedDiagnoses.first?.theCode == diagnosis.icdCode)
    }

    @Test("DashboardViewModel calcula KPIs base de sesiones")
    func dashboardViewModelComputesKPIs() {
        let now = Date()
        let patientA = Patient(firstName: "A", lastName: "One")
        patientA.sessions = [
            Session(sessionDate: now, durationMinutes: 50, status: SessionStatusMapping.completada.rawValue),
            Session(sessionDate: now, durationMinutes: 30, status: SessionStatusMapping.cancelada.rawValue),
        ]

        let patientB = Patient(firstName: "B", lastName: "Two")
        patientB.sessions = [
            Session(sessionDate: now, durationMinutes: 40, status: SessionStatusMapping.programada.rawValue),
        ]

        let viewModel = DashboardViewModel()
        viewModel.loadStatistics(from: [patientA, patientB])

        #expect(viewModel.totalPatients == 2)
        #expect(viewModel.sessionsThisMonth == 3)
        #expect(viewModel.averageDurationMinutes == 50)
        #expect(viewModel.completionRate == 50)
    }

    @Test("CalendarViewModel navega entre meses")
    func calendarViewModelMonthNavigation() {
        let viewModel = CalendarViewModel()
        let calendar = Calendar.current
        let initial = date(year: 2026, month: 1, day: 15)
        viewModel.displayedMonth = initial

        viewModel.goToNextMonth()
        let next = calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)
        #expect(next.year == 2026)
        #expect(next.month == 2)

        viewModel.goToPreviousMonth()
        let back = calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)
        #expect(back.year == 2026)
        #expect(back.month == 1)
    }

    @Test("CalendarViewModel.calendarDays refleja cantidad de días del mes")
    func calendarViewModelCalendarDaysCount() {
        let viewModel = CalendarViewModel()
        viewModel.displayedMonth = date(year: 2026, month: 2, day: 1) // Febrero 2026 = 28 días

        let dayCount = viewModel.calendarDays().compactMap { $0 }.count
        #expect(dayCount == 28)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date()
    }
}
