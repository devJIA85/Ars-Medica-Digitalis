//
//  MMSESectionView.swift
//  Ars Medica Digitalis
//
//  Vista de sección MMSE con header sutil y lista de ítems dinámicos.
//

import SwiftUI

struct MMSESectionView: View {
    let section: MMSESection
    let sectionIndex: Int
    let totalSections: Int
    let store: MMSEStore

    var body: some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeader

                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        MMSEItemView(
                            item: item,
                            response: store.response(for: item.id),
                            onSelectResponse: { isCorrect in
                                store.setResponse(for: item, isCorrect: isCorrect)
                            }
                        )

                        if index < section.items.count - 1 {
                            Divider()
                                .padding(.leading, AppSpacing.xs)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Header estilo "Health-like": subtítulo discreto + título + score y progreso.
    /// Se prioriza escaneabilidad clínica rápida durante la administración.
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Sección \(sectionIndex + 1) de \(totalSections)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(section.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: AppSpacing.sm)

                Text("\(store.score(for: section))/\(section.maxScore)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    )
            }

            HStack(spacing: AppSpacing.sm) {
                ProgressView(value: store.progress(for: section))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                Text("\(Int((store.progress(for: section) * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Progreso de sección")
            .accessibilityValue("\(Int((store.progress(for: section) * 100).rounded())) por ciento")
        }
    }
}
