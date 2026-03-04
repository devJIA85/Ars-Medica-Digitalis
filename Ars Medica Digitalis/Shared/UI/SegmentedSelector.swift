//
//  SegmentedSelector.swift
//  Ars Medica Digitalis
//
//  Selector segmentado reutilizable para preferencias discretas.
//

import SwiftUI

protocol SegmentedSelectorOption: Hashable, Identifiable {
    var title: String { get }
}

struct SegmentedSelector<Option: SegmentedSelectorOption>: View {

    let title: String
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(option.title)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.3), value: selection)
        .accessibilityLabel(title)
    }
}

#Preview {
    @Previewable @State var selection: PreviewSegmentedOption = .system

    SegmentedSelector(
        title: "Modo",
        options: PreviewSegmentedOption.allCases,
        selection: $selection
    )
    .padding()
}

private enum PreviewSegmentedOption: String, CaseIterable, SegmentedSelectorOption {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }
}
