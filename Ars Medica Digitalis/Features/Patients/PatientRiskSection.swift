//
//  PatientRiskSection.swift
//  Ars Medica Digitalis
//
//  Sección agrupada por prioridad clínica dentro del dashboard.
//

import SwiftUI

struct PatientRiskSection: View {

    let section: PatientDashboardSection
    let namespace: Namespace.ID
    let onDelete: (Patient) -> Void
    let activePriorityFilterTitle: String?
    let onClearPriorityFilter: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header

            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(section.rows) { row in
                    NavigationLink(value: row.id) {
                        PatientCard(model: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: row.id, in: namespace)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if row.isActive {
                            Button(L10n.tr("Baja"), role: .destructive) {
                                onDelete(row.patient)
                            }
                        }
                    }
                    .contextMenu {
                        if row.isActive {
                            Button(L10n.tr("Baja"), role: .destructive) {
                                onDelete(row.patient)
                            }
                        }
                    }
                }
            }
        }
        .glassCardEntrance()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.title3.weight(.semibold))

                Text(section.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let activePriorityFilterTitle {
                Button {
                    onClearPriorityFilter?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                        Text(activePriorityFilterTitle)
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("patient.dashboard.priority_filter.clear"))
            }

            Text("\(section.rows.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule(style: .continuous))
        }
    }
}
