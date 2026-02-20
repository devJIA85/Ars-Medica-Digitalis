//
//  AppLockView.swift
//  Ars Medica Digitalis
//
//  Pantalla de bloqueo para ocultar información sensible
//  hasta validar identidad del profesional.
//

import SwiftUI

struct AppLockView: View {

    let capability: BiometricCapability
    let isAuthenticating: Bool
    let errorMessage: String?
    let onUnlockBiometric: () -> Void
    let onUnlockWithPasscode: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.teal.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: lockSystemImage)
                    .font(.system(size: 54))
                    .foregroundStyle(.tint)
                    .padding(.bottom, 4)

                Text("Contenido protegido")
                    .font(.title2.bold())

                Text("Autenticá tu identidad para ver la información clínica.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button(action: onUnlockBiometric) {
                    Label(primaryButtonTitle, systemImage: lockSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating || !capability.isAvailable)

                Button(action: onUnlockWithPasscode) {
                    Label("Usar código del dispositivo", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isAuthenticating)

                if isAuthenticating {
                    ProgressView("Verificando identidad…")
                        .padding(.top, 6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                } else if let unavailableReason = capability.unavailableReason,
                          !capability.isAvailable {
                    Text(unavailableReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
        }
    }

    private var lockSystemImage: String {
        switch capability.kind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock.shield"
        }
    }

    private var primaryButtonTitle: String {
        capability.isAvailable
            ? "Desbloquear con \(capability.localizedName)"
            : "Reintentar autenticación"
    }
}

#Preview {
    AppLockView(
        capability: BiometricCapability(
            kind: .faceID,
            isAvailable: true,
            unavailableReason: nil
        ),
        isAuthenticating: false,
        errorMessage: nil,
        onUnlockBiometric: {},
        onUnlockWithPasscode: {}
    )
}
