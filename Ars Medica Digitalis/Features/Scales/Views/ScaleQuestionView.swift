//
//  ScaleQuestionView.swift
//  Ars Medica Digitalis
//
//  Aplicación dinámica de preguntas para una escala clínica.
//

import SwiftUI

struct ScaleQuestionView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ScaleSessionViewModel
    @State private var showingResult: Bool = false
    @State private var errorMessage: String? = nil
    let onSessionSaved: () -> Void

    init(
        viewModel: ScaleSessionViewModel,
        onSessionSaved: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSessionSaved = onSessionSaved
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            header

            ZStack {
                if let currentItem = viewModel.currentItem {
                    questionContent(item: currentItem)
                        .id(currentItem.id)
                        .transition(
                            .move(edge: transitionEdge)
                                .combined(with: .opacity)
                        )
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentQuestionIndex)

            Spacer(minLength: 0)

            footerControls
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .themedBackground()
        .navigationTitle(viewModel.scale.id)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingResult) {
            ScaleResultView(
                viewModel: viewModel,
                onSessionSaved: {
                    dismiss()
                    DispatchQueue.main.async {
                        onSessionSaved()
                    }
                }
            )
        }
        .alert(
            "No se puede finalizar",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if isPresented == false { errorMessage = nil }
                }
            )
        ) {
            Button("Aceptar", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Completá la escala para continuar.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(viewModel.currentQuestionLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func questionContent(item: ScaleItem) -> some View {
        VStack(spacing: AppSpacing.md) {
            CardContainer(style: .elevated) {
                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.primary)
            }
            .glassCardEntrance()

            VStack(spacing: AppSpacing.sm) {
                ForEach(item.options) { option in
                    optionRow(item: item, option: option)
                }
            }
        }
    }

    private func optionRow(item: ScaleItem, option: ScaleOption) -> some View {
        let isSelected = option.id == viewModel.selectedOptionIDForCurrentQuestion

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectAnswer(itemID: item.id, optionID: option.id, score: option.score)
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)

                Text(option.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.text). Puntaje \(option.score)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var footerControls: some View {
        HStack(spacing: AppSpacing.md) {
            Button("Anterior") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.previousQuestion()
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isFirstQuestion)

            Spacer(minLength: AppSpacing.md)

            Button(viewModel.isLastQuestion ? "Finalizar" : "Siguiente") {
                handlePrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canMoveForward)
        }
    }

    private var transitionEdge: Edge {
        switch viewModel.navigationDirection {
        case .forward:
            .trailing
        case .backward:
            .leading
        }
    }

    private func handlePrimaryAction() {
        if viewModel.isLastQuestion {
            do {
                _ = try viewModel.finishScale()
                showingResult = true
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.nextQuestion()
        }
    }
}
