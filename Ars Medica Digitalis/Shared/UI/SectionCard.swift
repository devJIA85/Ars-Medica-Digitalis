//
//  SectionCard.swift
//  Ars Medica Digitalis
//
//  Card reutilizable para secciones clínicas del dashboard.
//

import SwiftUI

struct SectionCard<Content: View, Action: View>: View {

    let title: String
    let icon: String?
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    @State private var hasAppeared = false

    init(
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) where Action == EmptyView {
        self.title = title
        self.icon = icon
        self.content = content()
        self.action = EmptyView()
    }

    init(
        title: String,
        icon: String? = nil,
        @ViewBuilder action: () -> Action,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            content
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .systemGroupedBackground),
            in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 14)
        .onAppear {
            guard hasAppeared == false else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                hasAppeared = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Label {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            } icon: {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            action
        }
    }
}
