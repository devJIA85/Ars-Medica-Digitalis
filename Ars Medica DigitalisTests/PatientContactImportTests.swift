import Contacts
import SwiftData
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct PatientContactImportTests {

    @Test("ImportedContactDraft prioriza móvil, resuelve address y redimensiona la foto")
    func importedContactDraftMapsPreferredFields() {
        let contact = CNMutableContact()
        contact.givenName = "Ana"
        contact.familyName = "García"
        contact.birthday = DateComponents(year: 1991, month: 7, day: 12)
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelWork, value: "  " as NSString),
            CNLabeledValue(label: CNLabelHome, value: "ana@example.com" as NSString),
        ]
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: "+54 11 4444-3333")),
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+54 9 11 5555-2222")),
        ]

        let address = CNMutablePostalAddress()
        address.street = "Av. Siempre Viva 742"
        address.city = "Buenos Aires"
        address.state = "CABA"
        address.postalCode = "1000"
        address.country = "Argentina"
        contact.postalAddresses = [
            CNLabeledValue(label: CNLabelHome, value: address.copy() as! CNPostalAddress),
        ]
        contact.imageData = Data([1, 2, 3])

        let draft = ImportedContactDraft(contact: contact) { _ in
            Data([9, 9, 9])
        }

        #expect(draft?.firstName == "Ana")
        #expect(draft?.lastName == "García")
        #expect(draft?.email == "ana@example.com")
        #expect(draft?.phoneNumber == "+54 9 11 5555-2222")
        #expect(draft?.address.contains("Av. Siempre Viva 742") == true)
        #expect(draft?.address.contains("Buenos Aires") == true)
        #expect(draft?.photoData == Data([9, 9, 9]))
        #expect(draft?.dateOfBirth == Calendar(identifier: .gregorian).date(from: DateComponents(year: 1991, month: 7, day: 12)))
    }

    @Test("ImportedContactDraft descarta cumpleaños incompleto y rechaza contactos sin nombre usable")
    func importedContactDraftRejectsInvalidIdentity() {
        let nameless = CNMutableContact()
        nameless.givenName = " "
        nameless.familyName = " "

        #expect(ImportedContactDraft(contact: nameless, imageResizer: { _ in nil }) == nil)

        let contact = CNMutableContact()
        contact.givenName = "Luz"
        contact.familyName = "Paz"
        contact.birthday = DateComponents(month: 4, day: 20)

        let draft = ImportedContactDraft(contact: contact, imageResizer: { _ in nil })

        #expect(draft?.dateOfBirth == nil)
    }

    @Test("PatientContactImportService detecta duplicados por email y teléfono exactos")
    func patientContactImportServiceFindsExactMatches() {
        let emailPatient = Patient(
            firstName: "Ana",
            lastName: "Uno",
            email: "ana@example.com",
            updatedAt: Date(timeIntervalSince1970: 30)
        )
        let phonePatient = Patient(
            firstName: "Ana",
            lastName: "Dos",
            phoneNumber: "+54 9 11 5555-2222",
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let emailDraft = ImportedContactDraft(
            firstName: "Ana",
            lastName: "Nueva",
            dateOfBirth: nil,
            email: "ANA@example.com",
            phoneNumber: "",
            address: "",
            photoData: nil
        )

        let phoneDraft = ImportedContactDraft(
            firstName: "Ana",
            lastName: "Nueva",
            dateOfBirth: nil,
            email: "",
            phoneNumber: "+54 9 11 5555 2222",
            address: "",
            photoData: nil
        )

        let emailMatch = PatientContactImportService.findDuplicate(
            for: emailDraft,
            among: [phonePatient, emailPatient]
        )
        let phoneMatch = PatientContactImportService.findDuplicate(
            for: phoneDraft,
            among: [emailPatient, phonePatient]
        )

        #expect(emailMatch?.patient.id == emailPatient.id)
        #expect(phoneMatch?.patient.id == phonePatient.id)
    }

    @Test("PatientContactImportService cae a nombre y fecha de nacimiento cuando no hay contacto exacto")
    func patientContactImportServiceFindsDemographicMatch() {
        let birthday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1988, month: 2, day: 9))!
        let patient = Patient(
            firstName: "María",
            lastName: "López",
            dateOfBirth: birthday
        )

        let draft = ImportedContactDraft(
            firstName: "Maria",
            lastName: "Lopez",
            dateOfBirth: birthday,
            email: "",
            phoneNumber: "",
            address: "",
            photoData: nil
        )

        let match = PatientContactImportService.findDuplicate(
            for: draft,
            among: [patient]
        )

        #expect(match?.patient.id == patient.id)
        #expect(match?.reason == .nameAndBirthDate)
    }

    @Test("PatientViewModel completa vacíos sin pisar datos y solo reemplaza al confirmar")
    func patientViewModelAppliesImportedContactWithExplicitMergeMode() {
        let fillOnlyViewModel = PatientViewModel()
        fillOnlyViewModel.firstName = "Ana"
        fillOnlyViewModel.lastName = "García"
        fillOnlyViewModel.email = ""
        fillOnlyViewModel.phoneNumber = "11 1234 0000"
        fillOnlyViewModel.dateOfBirth = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1))!
        fillOnlyViewModel.markDateOfBirthAsEdited()

        let importedBirthday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1999, month: 8, day: 20))!
        let draft = ImportedContactDraft(
            firstName: "Juana",
            lastName: "Pérez",
            dateOfBirth: importedBirthday,
            email: "juana@example.com",
            phoneNumber: "+54 9 11 5555-1111",
            address: "Nueva dirección",
            photoData: Data([7, 7, 7])
        )

        #expect(fillOnlyViewModel.overwriteFields(for: draft).contains("fecha de nacimiento"))
        #expect(fillOnlyViewModel.overwriteFields(for: draft).contains("teléfono"))

        fillOnlyViewModel.apply(importedContact: draft, mode: .fillEmpty)

        #expect(fillOnlyViewModel.firstName == "Ana")
        #expect(fillOnlyViewModel.lastName == "García")
        #expect(fillOnlyViewModel.email == "juana@example.com")
        #expect(fillOnlyViewModel.phoneNumber == "11 1234 0000")
        #expect(fillOnlyViewModel.address == "Nueva dirección")
        #expect(fillOnlyViewModel.photoData == Data([7, 7, 7]))
        #expect(fillOnlyViewModel.dateOfBirth == Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1)))

        let overwriteViewModel = PatientViewModel()
        overwriteViewModel.firstName = "Ana"
        overwriteViewModel.lastName = "García"
        overwriteViewModel.phoneNumber = "11 1234 0000"
        overwriteViewModel.dateOfBirth = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1))!
        overwriteViewModel.markDateOfBirthAsEdited()

        overwriteViewModel.apply(importedContact: draft, mode: .overwriteExisting)

        #expect(overwriteViewModel.firstName == "Juana")
        #expect(overwriteViewModel.lastName == "Pérez")
        #expect(overwriteViewModel.phoneNumber == "+54 9 11 5555-1111")
        #expect(overwriteViewModel.dateOfBirth == importedBirthday)
    }

    @Test("PatientViewModel llena fecha de nacimiento si todavía estaba en estado default")
    func patientViewModelImportsBirthDateWhenItWasNotEditedYet() {
        let viewModel = PatientViewModel()
        let importedBirthday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1985, month: 12, day: 24))!
        let draft = ImportedContactDraft(
            firstName: "Leo",
            lastName: "Paz",
            dateOfBirth: importedBirthday,
            email: "",
            phoneNumber: "",
            address: "",
            photoData: nil
        )

        viewModel.apply(importedContact: draft, mode: .fillEmpty)

        #expect(viewModel.dateOfBirth == importedBirthday)
        #expect(viewModel.hasManuallyEditedDateOfBirth == true)
    }
}
