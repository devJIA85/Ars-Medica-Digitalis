//
//  PatientCard.swift
//  Ars Medica Digitalis
//
//  Card clínica ligera para cada paciente dentro del dashboard.
//

import SwiftUI

struct PatientCard: View, Equatable {

    let model: PatientDashboardRowModel

    @State private var isVisible = false

    static func == (lhs: PatientCard, rhs: PatientCard) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                Text(model.fullName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(model.sessionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                adherenceRow
                badges
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .onAppear {
            guard isVisible == false else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84).delay(model.transitionDelay)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var avatar: some View {
        PatientRiskAvatar(model: model)
            .accessibilityLabel("\(model.fullName), \(model.riskBadgeLabel)")
    }

    private var adherenceRow: some View {
        HStack(spacing: 6) {
            Text(model.adherenceLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Image(systemName: model.adherenceTrend.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(model.adherenceTrend.tint)
                .accessibilityHidden(true)

            Text(model.adherenceTrend.shortLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(model.adherenceTrend.tint)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr(
            "patient.dashboard.adherence.accessibility",
            model.adherencePercentage,
            model.adherenceTrend.accessibilityLabel
        ))
    }

    private var badges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                if let diagnosisSummary = model.diagnosisSummary {
                    StatusBadge(label: diagnosisSummary, variant: .neutral, systemImage: "stethoscope")
                        .accessibilityLabel(L10n.tr("patient.dashboard.badge.diagnosis.accessibility", diagnosisSummary))
                }

                AnimatedRiskBadge(label: model.riskBadgeLabel, variant: model.riskBadgeVariant)
                    .accessibilityLabel(L10n.tr("patient.dashboard.badge.risk.accessibility", model.riskBadgeLabel))

                if model.hasDebt {
                    StatusBadge(label: L10n.tr("patient.list.badge.debt"), variant: .warning, systemImage: "exclamationmark.circle")
                        .accessibilityLabel(L10n.tr("patient.dashboard.badge.debt.accessibility"))
                }

                StatusBadge(label: model.activeBadgeLabel, variant: model.activeBadgeVariant, systemImage: "person.fill")
                    .accessibilityLabel(L10n.tr("patient.dashboard.badge.status.accessibility", model.activeBadgeLabel))
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PatientRiskAvatar: View {

    let model: PatientDashboardRowModel

    var body: some View {
        ZStack {
            Circle()
                .fill(ringTint.opacity(0.12))
                .frame(width: 66, height: 66)

            PatientAvatarView(
                photoData: model.photoData,
                firstName: model.firstName,
                lastName: model.lastName,
                genderHint: model.genderHint,
                clinicalStatus: model.clinicalStatus,
                size: 54
            )
            .padding(4)
            .background(Circle().fill(Color(uiColor: .systemBackground)))
            .overlay {
                Circle()
                    .strokeBorder(ringTint.opacity(0.22), lineWidth: 1)
            }

            Circle()
                .stroke(ringTint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 66, height: 66)
        }
    }

    private var ringTint: Color {
        model.riskRingTint
    }
}

private struct AnimatedRiskBadge: View {

    let label: String
    let variant: StatusBadge.Variant

    @State private var isVisible = false

    var body: some View {
        StatusBadge(label: label, variant: variant, systemImage: "waveform.path.ecg")
            .scaleEffect(isVisible ? 1 : 0.92)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                guard isVisible == false else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75, blendDuration: 0.04)) {
                    isVisible = true
                }
            }
    }
}
