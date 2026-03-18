//
//  SessionViewModelStatusTests.swift
//  Ars Medica Digitalis
//
//  Tests unitarios para SessionViewModel.adjustStatusForDate().
//  La función es privada; se prueba a través de:
//   - init(initialDate:) — que la invoca al construir
//   - sessionDate setter — que la invoca en didSet
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct SessionViewModelStatusTests {

    // MARK: - init(initialDate:)

    @Test("Fecha futura → status programada al construir con init(initialDate:)")
    func initFutureDateProducesScheduled() {
        let future = Date().addingTimeInterval(60 * 60 * 24)  // mañana
        let vm = SessionViewModel(initialDate: future)

        #expect(vm.status == SessionStatusMapping.programada.rawValue)
    }

    @Test("Fecha pasada → status completada al construir con init(initialDate:)")
    func initPastDateProducesCompleted() {
        let past = Date().addingTimeInterval(-60 * 60 * 24)  // ayer
        let vm = SessionViewModel(initialDate: past)

        #expect(vm.status == SessionStatusMapping.completada.rawValue)
    }

    @Test("init() por defecto produce status completada con fecha actual")
    func defaultInitProducesCompleted() {
        let vm = SessionViewModel()

        #expect(vm.status == SessionStatusMapping.completada.rawValue)
    }

    // MARK: - sessionDate setter (didSet → adjustStatusForDate)

    @Test("Cambiar fecha a futuro desde completada → status cambia a programada")
    func changingDateToFutureFlipsToScheduled() {
        let vm = SessionViewModel()
        // Estado inicial: completada (fecha actual)
        #expect(vm.status == SessionStatusMapping.completada.rawValue)

        vm.sessionDate = Date().addingTimeInterval(60 * 60 * 24 * 2)

        #expect(vm.status == SessionStatusMapping.programada.rawValue)
    }

    @Test("Cambiar fecha a pasado desde programada → status cambia a completada")
    func changingDateToPastFlipsToCompleted() {
        let future = Date().addingTimeInterval(60 * 60 * 24)
        let vm = SessionViewModel(initialDate: future)
        #expect(vm.status == SessionStatusMapping.programada.rawValue)

        vm.sessionDate = Date().addingTimeInterval(-60 * 60 * 24)

        #expect(vm.status == SessionStatusMapping.completada.rawValue)
    }

    @Test("Cambiar fecha cuando status es cancelada → status no cambia")
    func cancelledStatusNotOverridden() {
        let vm = SessionViewModel()
        vm.status = SessionStatusMapping.cancelada.rawValue

        // Cambiar a futuro — cancelada debe mantenerse
        vm.sessionDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(vm.status == SessionStatusMapping.cancelada.rawValue)

        // Cambiar a pasado — cancelada debe mantenerse
        vm.sessionDate = Date().addingTimeInterval(-60 * 60 * 24)
        #expect(vm.status == SessionStatusMapping.cancelada.rawValue)
    }

    @Test("Cambiar fecha de futuro a futuro cuando ya es programada → status no cambia")
    func futureToFutureKeepsScheduled() {
        let future = Date().addingTimeInterval(60 * 60 * 24)
        let vm = SessionViewModel(initialDate: future)
        #expect(vm.status == SessionStatusMapping.programada.rawValue)

        vm.sessionDate = Date().addingTimeInterval(60 * 60 * 48)

        #expect(vm.status == SessionStatusMapping.programada.rawValue)
    }

    @Test("Cambiar fecha de pasado a pasado cuando ya es completada → status no cambia")
    func pastToPastKeepsCompleted() {
        let vm = SessionViewModel()
        #expect(vm.status == SessionStatusMapping.completada.rawValue)

        vm.sessionDate = Date().addingTimeInterval(-60 * 60 * 48)

        #expect(vm.status == SessionStatusMapping.completada.rawValue)
    }
}
