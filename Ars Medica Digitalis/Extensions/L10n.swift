import Foundation

enum L10n {
    static func tr(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
