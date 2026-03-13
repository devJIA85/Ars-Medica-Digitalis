//
//  PatientContactImportService.swift
//  Ars Medica Digitalis
//
//  Mapea un contacto del sistema al draft clínico-administrativo del paciente
//  y detecta duplicados fuertes dentro del padrón del profesional.
//

import Contacts
import Foundation

struct ImportedContactDraft: Equatable {
    let firstName: String
    let lastName: String
    let dateOfBirth: Date?
    let email: String
    let phoneNumber: String
    let address: String
    let photoData: Data?

    init(
        firstName: String,
        lastName: String,
        dateOfBirth: Date?,
        email: String,
        phoneNumber: String,
        address: String,
        photoData: Data?
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.email = email
        self.phoneNumber = phoneNumber
        self.address = address
        self.photoData = photoData
    }

    init?(
        contact: CNContact,
        imageResizer: (Data) -> Data?
    ) {
        let firstName = contact.stringValue(for: CNContactGivenNameKey) ?? ""
        let lastName = contact.stringValue(for: CNContactFamilyNameKey) ?? ""

        guard firstName.trimmed.isEmpty == false, lastName.trimmed.isEmpty == false else {
            return nil
        }

        self.firstName = firstName.trimmed
        self.lastName = lastName.trimmed
        self.dateOfBirth = Self.resolvedBirthday(from: contact)
        self.email = Self.preferredEmail(from: contact)
        self.phoneNumber = Self.preferredPhoneNumber(from: contact)
        self.address = Self.preferredPostalAddress(from: contact)
        self.photoData = Self.preferredPhotoData(from: contact, imageResizer: imageResizer)
    }

    private static func resolvedBirthday(from contact: CNContact) -> Date? {
        guard contact.isKeyAvailable(CNContactBirthdayKey),
              let birthday = contact.birthday,
              let year = birthday.year,
              let month = birthday.month,
              let day = birthday.day else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date
    }

    private static func preferredEmail(from contact: CNContact) -> String {
        guard contact.isKeyAvailable(CNContactEmailAddressesKey) else {
            return ""
        }

        return contact.emailAddresses
            .lazy
            .map { String($0.value) }
            .map(\.trimmed)
            .first(where: { $0.isEmpty == false }) ?? ""
    }

    private static func preferredPhoneNumber(from contact: CNContact) -> String {
        guard contact.isKeyAvailable(CNContactPhoneNumbersKey) else {
            return ""
        }

        return contact.phoneNumbers
            .compactMap { labeledValue -> (value: String, priority: Int)? in
                let phoneNumber = labeledValue.value.stringValue.trimmed
                guard phoneNumber.isEmpty == false else { return nil }
                return (
                    value: phoneNumber,
                    priority: Self.phonePriority(for: labeledValue.label)
                )
            }
            .sorted { (lhs: (value: String, priority: Int), rhs: (value: String, priority: Int)) in
                if lhs.priority == rhs.priority {
                    return lhs.value.localizedStandardCompare(rhs.value) == .orderedAscending
                }
                return lhs.priority < rhs.priority
            }
            .first?.value ?? ""
    }

    private static func preferredPostalAddress(from contact: CNContact) -> String {
        guard contact.isKeyAvailable(CNContactPostalAddressesKey),
              let postalAddress = contact.postalAddresses.first?.value else {
            return ""
        }

        let formatted = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
        return formatted
            .components(separatedBy: .newlines)
            .map(\.trimmed)
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    private static func preferredPhotoData(
        from contact: CNContact,
        imageResizer: (Data) -> Data?
    ) -> Data? {
        let rawPhotoData: Data?

        if contact.isKeyAvailable(CNContactThumbnailImageDataKey),
           let thumbnail = contact.thumbnailImageData,
           thumbnail.isEmpty == false {
            rawPhotoData = thumbnail
        } else if contact.isKeyAvailable(CNContactImageDataKey),
                  let imageData = contact.imageData,
                  imageData.isEmpty == false {
            rawPhotoData = imageData
        } else {
            rawPhotoData = nil
        }

        guard let rawPhotoData else {
            return nil
        }

        return imageResizer(rawPhotoData) ?? rawPhotoData
    }

    private static func phonePriority(for label: String?) -> Int {
        switch label {
        case CNLabelPhoneNumberMobile:
            return 0
        case CNLabelPhoneNumberiPhone:
            return 1
        case CNLabelPhoneNumberMain:
            return 2
        case CNLabelHome:
            return 3
        case CNLabelWork:
            return 4
        case nil:
            return 5
        default:
            return 6
        }
    }
}

enum ImportedContactMergeMode {
    case fillEmpty
    case overwriteExisting
}

struct PatientContactDuplicateMatch: Identifiable {
    enum Reason: Equatable {
        case email(String)
        case phone(String)
        case nameAndBirthDate

        var title: String {
            switch self {
            case .email:
                return "Ya existe un paciente con ese email"
            case .phone:
                return "Ya existe un paciente con ese teléfono"
            case .nameAndBirthDate:
                return "Ya existe un paciente con ese nombre y fecha de nacimiento"
            }
        }

        var subtitle: String {
            switch self {
            case .email(let value):
                return "Coincidencia exacta por email: \(value)"
            case .phone(let value):
                return "Coincidencia exacta por teléfono: \(value)"
            case .nameAndBirthDate:
                return "Coincidencia fuerte por identidad demográfica"
            }
        }
    }

    let patient: Patient
    let reason: Reason

    var id: UUID { patient.id }
}

enum PatientContactImportService {
    static func findDuplicate(
        for draft: ImportedContactDraft,
        among patients: [Patient],
        excluding excludedPatientID: UUID? = nil
    ) -> PatientContactDuplicateMatch? {
        let normalizedEmail = normalizedEmailValue(draft.email)
        let normalizedPhone = normalizedPhoneValue(draft.phoneNumber)
        let normalizedFirstName = normalizedPersonNameValue(draft.firstName)
        let normalizedLastName = normalizedPersonNameValue(draft.lastName)

        let matches = patients.compactMap { patient -> (match: PatientContactDuplicateMatch, score: Int, isActive: Bool, updatedAt: Date)? in
            guard patient.id != excludedPatientID else {
                return nil
            }

            if normalizedEmail.isEmpty == false,
               normalizedEmail == normalizedEmailValue(patient.email) {
                return (
                    match: PatientContactDuplicateMatch(
                        patient: patient,
                        reason: .email(patient.email.trimmed)
                    ),
                    score: 300,
                    isActive: patient.isActive,
                    updatedAt: patient.updatedAt
                )
            }

            if normalizedPhone.isEmpty == false,
               normalizedPhone == normalizedPhoneValue(patient.phoneNumber) {
                return (
                    match: PatientContactDuplicateMatch(
                        patient: patient,
                        reason: .phone(patient.phoneNumber.trimmed)
                    ),
                    score: 200,
                    isActive: patient.isActive,
                    updatedAt: patient.updatedAt
                )
            }

            guard let importedDateOfBirth = draft.dateOfBirth,
                  normalizedFirstName.isEmpty == false,
                  normalizedLastName.isEmpty == false,
                  normalizedFirstName == normalizedPersonNameValue(patient.firstName),
                  normalizedLastName == normalizedPersonNameValue(patient.lastName),
                  Calendar(identifier: .gregorian).isDate(patient.dateOfBirth, inSameDayAs: importedDateOfBirth) else {
                return nil
            }

            return (
                match: PatientContactDuplicateMatch(
                    patient: patient,
                    reason: .nameAndBirthDate
                ),
                score: 100,
                isActive: patient.isActive,
                updatedAt: patient.updatedAt
            )
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    if lhs.isActive != rhs.isActive {
                        return lhs.isActive && rhs.isActive == false
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.score > rhs.score
            }
            .first?.match
    }

}

extension PatientViewModel {
    func overwriteFields(for draft: ImportedContactDraft) -> [String] {
        var fields: [String] = []

        if fieldWouldBeOverwritten(currentValue: firstName, importedValue: draft.firstName) {
            fields.append("nombre")
        }

        if fieldWouldBeOverwritten(currentValue: lastName, importedValue: draft.lastName) {
            fields.append("apellido")
        }

        if let importedDateOfBirth = draft.dateOfBirth,
           hasManuallyEditedDateOfBirth,
           Calendar(identifier: .gregorian).isDate(dateOfBirth, inSameDayAs: importedDateOfBirth) == false {
            fields.append("fecha de nacimiento")
        }

        if fieldWouldBeOverwritten(
            currentValue: email,
            importedValue: draft.email,
            normalizer: { $0.trimmed.lowercased() }
        ) {
            fields.append("email")
        }

        if fieldWouldBeOverwritten(
            currentValue: phoneNumber,
            importedValue: draft.phoneNumber,
            normalizer: normalizedPhoneValue
        ) {
            fields.append("teléfono")
        }

        if fieldWouldBeOverwritten(currentValue: address, importedValue: draft.address) {
            fields.append("dirección")
        }

        if photoData != nil, draft.photoData != nil {
            fields.append("foto de perfil")
        }

        return fields
    }

    func apply(importedContact draft: ImportedContactDraft, mode: ImportedContactMergeMode) {
        firstName = merged(currentValue: firstName, importedValue: draft.firstName, mode: mode)
        lastName = merged(currentValue: lastName, importedValue: draft.lastName, mode: mode)
        email = merged(currentValue: email, importedValue: draft.email, mode: mode)
        phoneNumber = merged(currentValue: phoneNumber, importedValue: draft.phoneNumber, mode: mode)
        address = merged(currentValue: address, importedValue: draft.address, mode: mode)

        if let importedDateOfBirth = draft.dateOfBirth {
            switch mode {
            case .fillEmpty:
                if hasManuallyEditedDateOfBirth == false {
                    dateOfBirth = importedDateOfBirth
                    hasManuallyEditedDateOfBirth = true
                }
            case .overwriteExisting:
                dateOfBirth = importedDateOfBirth
                hasManuallyEditedDateOfBirth = true
            }
        }

        if let importedPhotoData = draft.photoData {
            switch mode {
            case .fillEmpty:
                if photoData == nil {
                    photoData = importedPhotoData
                }
            case .overwriteExisting:
                photoData = importedPhotoData
            }
        }
    }

    private func fieldWouldBeOverwritten(
        currentValue: String,
        importedValue: String,
        normalizer: (String) -> String = { $0.trimmed }
    ) -> Bool {
        let normalizedCurrent = normalizer(currentValue)
        let normalizedImported = normalizer(importedValue)

        guard normalizedCurrent.isEmpty == false, normalizedImported.isEmpty == false else {
            return false
        }

        return normalizedCurrent != normalizedImported
    }

    private func merged(
        currentValue: String,
        importedValue: String,
        mode: ImportedContactMergeMode
    ) -> String {
        let normalizedImported = importedValue.trimmed
        guard normalizedImported.isEmpty == false else {
            return currentValue
        }

        switch mode {
        case .fillEmpty:
            return currentValue.trimmed.isEmpty ? normalizedImported : currentValue
        case .overwriteExisting:
            return normalizedImported
        }
    }
}

private extension CNContact {
    func stringValue(for key: String) -> String? {
        guard isKeyAvailable(key) else {
            return nil
        }

        switch key {
        case CNContactGivenNameKey:
            return givenName
        case CNContactFamilyNameKey:
            return familyName
        default:
            return nil
        }
    }
}

private func normalizedEmailValue(_ value: String) -> String {
    value.trimmed.lowercased()
}

private func normalizedPhoneValue(_ value: String) -> String {
    let allowedCharacters = CharacterSet(charactersIn: "+0123456789")
    let normalized = value.unicodeScalars.filter { scalar in
        allowedCharacters.contains(scalar)
    }
    return String(String.UnicodeScalarView(normalized))
}

private func normalizedPersonNameValue(_ value: String) -> String {
    let folded = value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

    let mapped = folded.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
    }
    .joined()

    return mapped
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
