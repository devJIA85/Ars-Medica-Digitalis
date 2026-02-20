//
//  SplashView.swift
//  Ars Medica Digitalis
//
//  Pantalla inicial breve para transición de arranque
//  y branding antes de resolver onboarding/bloqueo/app.
//

import SwiftUI

struct SplashView: View {

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.teal.opacity(0.8), Color.blue.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.06 : 0.94)

                Text("Ars Medica Digitalis")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Preparando tu espacio clínico")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(24)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    SplashView()
}
