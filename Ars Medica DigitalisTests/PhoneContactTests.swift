//
//  PhoneContactTests.swift
//  Ars Medica DigitalisTests
//
//  Cubre normalización E.164, indicativos por país, construcción de URLs
//  y edge cases del helper PhoneContact.
//  La detección de WhatsApp (canOpenURL) no se testea aquí por depender del dispositivo.
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct PhoneContactTests {

    // MARK: - normalizedForWhatsApp — formato internacional con +

    @Test("Número argentino con formato completo (+)")
    func normalizesArgentineFormattedNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("+54 11 5555-1234") == "541155551234")
    }

    @Test("Número español con formato completo (+)")
    func normalizesSpanishFormattedNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("+34 655 123 456") == "34655123456")
    }

    @Test("Número español con guiones (+)")
    func normalizesSpanishNumberWithDashes() {
        #expect(PhoneContact.normalizedForWhatsApp("+34-655-123-456") == "34655123456")
    }

    @Test("Número con paréntesis")
    func normalizesNumberWithParentheses() {
        #expect(PhoneContact.normalizedForWhatsApp("+54 (11) 5555-1234") == "541155551234")
    }

    @Test("Número con puntos como separador")
    func normalizesNumberWithDots() {
        #expect(PhoneContact.normalizedForWhatsApp("+1.800.555.0100") == "18005550100")
    }

    // MARK: - normalizedForWhatsApp — formato internacional con 00

    @Test("Número español con prefijo 00 (formato europeo)")
    func normalizesSpanishNumberWith00Prefix() {
        #expect(PhoneContact.normalizedForWhatsApp("0034655123456") == "34655123456")
    }

    @Test("Número argentino con prefijo 00")
    func normalizesArgentineNumberWith00Prefix() {
        #expect(PhoneContact.normalizedForWhatsApp("005411 5555-1234") == "541155551234")
    }

    @Test("Prefijo 00 con espacios entre el código y el número local")
    func normalizesNumber00WithSpaces() {
        #expect(PhoneContact.normalizedForWhatsApp("00 34 655 123 456") == "34655123456")
    }

    // MARK: - normalizedForWhatsApp — número local con isoCountryCode

    @Test("Número local español sin prefijo, país ES → antepone 34")
    func normalizesLocalSpanishMobileNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("655 123 456", isoCountryCode: "ES") == "34655123456")
    }

    @Test("Número local español fijo sin prefijo, país ES → antepone 34")
    func normalizesLocalSpanishLandlineNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("91 234 56 78", isoCountryCode: "ES") == "34912345678")
    }

    @Test("Número local argentino sin prefijo, país AR → antepone 54")
    func normalizesLocalArgentineNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("11 5555-1234", isoCountryCode: "AR") == "54115555 1234".filter(\.isNumber))
    }

    @Test("Número local sin isoCountryCode no altera los dígitos")
    func localNumberWithoutCountryCodeReturnsDigitsOnly() {
        #expect(PhoneContact.normalizedForWhatsApp("655 123 456") == "655123456")
    }

    @Test("isoCountryCode en minúsculas funciona igual")
    func lowercaseISOCodeIsAccepted() {
        #expect(PhoneContact.normalizedForWhatsApp("655 123 456", isoCountryCode: "es") == "34655123456")
    }

    @Test("Número local con código de país desconocido retorna dígitos sin prefijo")
    func unknownISOCodeFallsBackToDigitsOnly() {
        #expect(PhoneContact.normalizedForWhatsApp("655 123 456", isoCountryCode: "XX") == "655123456")
    }

    // MARK: - normalizedForWhatsApp — edge cases

    @Test("Número sin código de país ni isoCountryCode retorna dígitos tal cual")
    func normalizesPlainLocalNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("1155551234") == "1155551234")
    }

    @Test("Número con más de 15 dígitos es retornado (wa.me gestiona el límite)")
    func returnsLongNumberAsIs() {
        #expect(PhoneContact.normalizedForWhatsApp("+1234567890123456") != nil)
    }

    @Test("Número con menos de 7 dígitos retorna nil")
    func rejectsShortNumber() {
        #expect(PhoneContact.normalizedForWhatsApp("+54 123") == nil)
    }

    @Test("Número vacío retorna nil")
    func rejectsEmptyString() {
        #expect(PhoneContact.normalizedForWhatsApp("") == nil)
    }

    @Test("Número solo con símbolos retorna nil")
    func rejectsSymbolsOnly() {
        #expect(PhoneContact.normalizedForWhatsApp("+-() ") == nil)
    }

    @Test("Número con exactamente 7 dígitos es aceptado (boundary)")
    func acceptsSevenDigitBoundary() {
        #expect(PhoneContact.normalizedForWhatsApp("1234567") == "1234567")
    }

    // MARK: - dialCode

    @Test("España → 34")
    func dialCodeSpain() {
        #expect(PhoneContact.dialCode(forISO: "ES") == "34")
    }

    @Test("Argentina → 54")
    func dialCodeArgentina() {
        #expect(PhoneContact.dialCode(forISO: "AR") == "54")
    }

    @Test("México → 52")
    func dialCodeMexico() {
        #expect(PhoneContact.dialCode(forISO: "MX") == "52")
    }

    @Test("Estados Unidos → 1")
    func dialCodeUSA() {
        #expect(PhoneContact.dialCode(forISO: "US") == "1")
    }

    @Test("Código ISO desconocido retorna nil")
    func dialCodeUnknownISO() {
        #expect(PhoneContact.dialCode(forISO: "XX") == nil)
    }

    @Test("Código ISO en minúsculas es resuelto igual")
    func dialCodeCaseInsensitive() {
        #expect(PhoneContact.dialCode(forISO: "es") == "34")
    }

    // MARK: - whatsAppURL

    @Test("URL wa.me contiene el número normalizado")
    func whatsAppURLContainsNormalizedPhone() throws {
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: "541155551234"))
        #expect(url.absoluteString == "https://wa.me/541155551234")
    }

    @Test("URL sin mensaje no incluye query string")
    func whatsAppURLWithoutMessageHasNoQueryString() throws {
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: "541155551234"))
        #expect(url.query == nil)
    }

    @Test("URL con mensaje incluye parámetro text")
    func whatsAppURLWithMessageIncludesTextParam() throws {
        let url = try #require(PhoneContact.whatsAppURL(
            normalizedPhone: "34655123456",
            message: "Hola, tu cita es mañana a las 10:00."
        ))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let textParam = components.queryItems?.first(where: { $0.name == "text" })
        #expect(textParam?.value == "Hola, tu cita es mañana a las 10:00.")
    }

    @Test("URL usa esquema HTTPS")
    func whatsAppURLUsesHTTPS() throws {
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: "34655123456"))
        #expect(url.scheme == "https")
    }

    @Test("URL apunta al host wa.me")
    func whatsAppURLHostIsWaMe() throws {
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: "34655123456"))
        #expect(url.host == "wa.me")
    }

    // MARK: - callURL

    @Test("URL de llamada usa esquema tel://")
    func callURLUsesTelScheme() throws {
        let url = try #require(PhoneContact.callURL(for: "+34 655 123 456"))
        #expect(url.scheme == "tel")
    }

    @Test("URL de llamada preserva el + del código de país")
    func callURLPreservesPlus() throws {
        let url = try #require(PhoneContact.callURL(for: "+34 655 123 456"))
        #expect(url.absoluteString.contains("+"))
    }

    @Test("URL de llamada elimina espacios y guiones")
    func callURLStripsFormattingCharacters() throws {
        let url = try #require(PhoneContact.callURL(for: "+54 11 5555-1234"))
        #expect(!url.absoluteString.contains(" "))
        #expect(!url.absoluteString.contains("-"))
    }

    @Test("Número vacío retorna nil para callURL")
    func callURLRejectsEmptyString() {
        #expect(PhoneContact.callURL(for: "") == nil)
    }

    @Test("Número solo con símbolos retorna nil para callURL")
    func callURLRejectsSymbolsOnly() {
        #expect(PhoneContact.callURL(for: "+-() ") == nil)
    }

    // MARK: - Flujos integrados

    @Test("Flujo Argentina: número con + → normalización → URL wa.me")
    func fullFlowArgentinaInternational() throws {
        let normalized = try #require(PhoneContact.normalizedForWhatsApp("+54 11 5555-1234"))
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: normalized))
        #expect(url.absoluteString == "https://wa.me/541155551234")
    }

    @Test("Flujo España: número con + → normalización → URL wa.me")
    func fullFlowSpainInternational() throws {
        let normalized = try #require(PhoneContact.normalizedForWhatsApp("+34 655 123 456"))
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: normalized))
        #expect(url.absoluteString == "https://wa.me/34655123456")
    }

    @Test("Flujo España: número local + ISO ES → URL wa.me con indicativo")
    func fullFlowSpainLocalWithISO() throws {
        let normalized = try #require(PhoneContact.normalizedForWhatsApp("655 123 456", isoCountryCode: "ES"))
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: normalized))
        #expect(url.absoluteString == "https://wa.me/34655123456")
    }

    @Test("Flujo España: número con 00 → normalización → URL wa.me")
    func fullFlowSpain00Prefix() throws {
        let normalized = try #require(PhoneContact.normalizedForWhatsApp("0034655123456"))
        let url = try #require(PhoneContact.whatsAppURL(normalizedPhone: normalized))
        #expect(url.absoluteString == "https://wa.me/34655123456")
    }

    @Test("Número inválido no genera URL de WhatsApp")
    func invalidNumberDoesNotProduceWhatsAppURL() {
        #expect(PhoneContact.normalizedForWhatsApp("abc") == nil)
    }
}
