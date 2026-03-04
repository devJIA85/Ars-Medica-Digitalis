//
//  TimelineRow.swift
//  Ars Medica Digitalis
//
//  Fila reutilizable para listas cronológicas del dashboard clínico.
//

import SwiftUI

struct TimelineRow: View {

    let dateLabel: String
    let title: String
    let subtitle: String?
    let statusLabel: String?
    let statusVariant: StatusBadge.Variant
    let isFirst: Bool
    let isLast: Bool
    var showsChevron: Bool = false
    var notes: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            timelineIndicator

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(dateLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    if let statusLabel {
                        StatusBadge(label: statusLabel, variant: statusVariant)
                    }

                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }

                if let subtitle, !subtitle.trimmed.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let notes, !notes.trimmed.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(minHeight: 44, alignment: .top)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel)
    }

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 2, height: isFirst ? 0 : 10)
                .opacity(isFirst ? 0 : 1)

            Circle()
                .fill(.secondary.opacity(0.7))
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(.quaternary)
                .frame(width: 2)
                .frame(minHeight: isLast ? 0 : 24, maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 12)
        .accessibilityHidden(true)
    }

    private var timelineAccessibilityLabel: String {
        var parts = [dateLabel, title]
        if let subtitle, !subtitle.trimmed.isEmpty {
            parts.append(subtitle)
        }
        if let statusLabel, !statusLabel.trimmed.isEmpty {
            parts.append("Estado \(statusLabel)")
        }
        if let notes, !notes.trimmed.isEmpty {
            parts.append(notes)
        }
        return parts.joined(separator: ", ")
    }
}
