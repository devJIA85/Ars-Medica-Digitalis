//
//  ToggleRow.swift
//  Ars Medica Digitalis
//
//  Variante de SettingsRow para switches con feedback visual sutil.
//

import SwiftUI

struct ToggleRow: View {

    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .accentColor
    var isEnabled: Bool = true
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            tint: tint
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled)
                .tint(tint)
        }
        .opacity(isEnabled ? 1 : 0.6)
        .animation(.easeOut(duration: 0.3), value: isOn)
    }
}

#Preview {
    @Previewable @State var enabled = true

    ToggleRow(
        systemImage: "faceid",
        title: "Bloqueo al abrir la app",
        isOn: $enabled
    )
    .padding()
}
