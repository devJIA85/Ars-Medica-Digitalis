//
//  SessionRichTextHelpers.swift
//  Ars Medica Digitalis
//
//  Helpers RTF extraídos de Session.swift para mantener import UIKit
//  fuera del @Model.
//

import Foundation
import UIKit

enum SessionRichTextHelper {

    /// Serializa un AttributedString a RTF usando NSAttributedString.
    /// Retorna nil si la conversión falla (e.g., string vacío sin atributos).
    static func encodeRTF(_ text: AttributedString) -> Data? {
        let nsString = NSAttributedString(text)
        guard nsString.length > 0 else { return nil }
        return try? nsString.data(
            from: NSRange(location: 0, length: nsString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    /// Deserializa RTF a AttributedString con scope UIKit.
    /// Retorna nil si los datos son inválidos o no corresponden a RTF.
    static func decodeRTF(from data: Data) -> AttributedString? {
        guard let nsString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { return nil }
        return try? AttributedString(nsString, including: \.uiKit)
    }
}
