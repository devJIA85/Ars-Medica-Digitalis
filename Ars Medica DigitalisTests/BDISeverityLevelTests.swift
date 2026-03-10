import Testing
@testable import Ars_Medica_Digitalis

struct BDISeverityLevelTests {

    @Test("BDISeverityLevel normaliza severidades legacy y actuales")
    func mapsLegacyAndCurrentValues() {
        #expect(BDISeverityLevel.from(rawSeverity: "moderate") == .moderate)
        #expect(BDISeverityLevel.from(rawSeverity: "moderateDepression") == .moderate)
        #expect(BDISeverityLevel.from(rawSeverity: "severe") == .severe)
        #expect(BDISeverityLevel.from(rawSeverity: "severeDepression") == .severe)
        #expect(BDISeverityLevel.from(rawSeverity: "extreme") == .extreme)
        #expect(BDISeverityLevel.from(rawSeverity: "extremeDepression") == .extreme)
    }

    @Test("BDISeverityLevel identifica severidad alta para severa y extrema")
    func highDepressionFlag() {
        #expect(BDISeverityLevel.from(rawSeverity: "severeDepression")?.isHighDepression == true)
        #expect(BDISeverityLevel.from(rawSeverity: "extremeDepression")?.isHighDepression == true)
        #expect(BDISeverityLevel.from(rawSeverity: "moderateDepression")?.isHighDepression == false)
    }
}
