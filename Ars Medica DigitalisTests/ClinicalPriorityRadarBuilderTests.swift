import Testing
@testable import Ars_Medica_Digitalis

struct ClinicalPriorityRadarBuilderTests {

    @Test("ClinicalPriorityRadarBuilder construye conteos y fracciones desde el estado del dashboard")
    func buildFromState() {
        let state = makeState(
            total: 10,
            critical: 2,
            attention: 3,
            stable: 5
        )

        let model = ClinicalPriorityRadarBuilder.build(from: state)

        #expect(model.totalCount == 10)
        #expect(model.criticalCount == 2)
        #expect(model.attentionCount == 3)
        #expect(model.stableCount == 5)
        #expect(model.criticalFraction == 0.2)
        #expect(model.attentionFraction == 0.3)
        #expect(model.stableFraction == 0.5)
    }

    @Test("ClinicalPriorityRadarBuilder retorna fracciones en cero cuando el total es cero")
    func buildFromEmptyState() {
        let state = makeState(
            total: 0,
            critical: 0,
            attention: 0,
            stable: 0
        )

        let model = ClinicalPriorityRadarBuilder.build(from: state)

        #expect(model.totalCount == 0)
        #expect(model.criticalFraction == 0)
        #expect(model.attentionFraction == 0)
        #expect(model.stableFraction == 0)
    }

    @Test("ClinicalPriorityRadarModel y bucket son Sendable")
    func radarModelAndBucketAreSendable() {
        let model = ClinicalPriorityRadarModel(
            totalCount: 4,
            criticalCount: 1,
            attentionCount: 1,
            stableCount: 2
        )
        assertSendable(model)
        assertSendable(ClinicalPriorityBucket.critical)
    }

    private func makeState(
        total: Int,
        critical: Int,
        attention: Int,
        stable: Int
    ) -> PatientDashboardState {
        PatientDashboardState(
            summary: ClinicalInsightsSummary(
                totalPatients: total,
                title: "Clinical Intelligence",
                subtitle: "\(total) patients analyzed",
                criticalPatientsCount: critical,
                attentionPatientsCount: attention,
                stablePatientsCount: stable,
                trends: [],
                metrics: [],
                radarModel: .empty
            ),
            sections: []
        )
    }

    private func assertSendable<T: Sendable>(_ value: T) {
        _ = value
    }
}

