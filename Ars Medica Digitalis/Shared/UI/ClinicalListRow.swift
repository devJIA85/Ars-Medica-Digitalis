//
//  ClinicalListRow.swift
//  Ars Medica Digitalis
//
//  Fila clínica reutilizable con acciones de swipe.
//

import SwiftUI

struct ClinicalListRow: View {

    let icon: String
    let title: String
    let value: String
    var showsChevron: Bool = true
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button("Eliminar", role: .destructive, action: onDelete)
            }

            if let onEdit {
                Button("Editar", action: onEdit)
                    .tint(.blue)
            }
        }
    }

    private var rowContent: some View {
        ViewThatFits(in: .vertical) {
            compactRowLayout
            expandedRowLayout
        }
        .contentShape(Rectangle())
        .frame(minHeight: 44, alignment: .center)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(onTap != nil ? "Abre el detalle de este elemento" : "")
    }

    private var compactRowLayout: some View {
        HStack(spacing: AppSpacing.sm) {
            rowIcon
            rowTitle
            Spacer(minLength: 0)
            rowValue(alignment: .trailing)
            chevron
        }
    }

    private var expandedRowLayout: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                rowIcon
                rowTitle
                Spacer(minLength: 0)
                chevron
            }

            rowValue(alignment: .leading)
                .padding(.leading, 32)
        }
    }

    private var rowIcon: some View {
        Image(systemName: icon)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 24)
            .accessibilityHidden(true)
    }

    private var rowTitle: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rowValue(alignment: TextAlignment) -> some View {
        Text(value)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var chevron: some View {
        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
