//
//  GenogramCanvasView.swift
//  Ars Medica Digitalis
//
//  Canvas de dibujo libre para genogramas usando PencilKit.
//  UIViewRepresentable justificado: PencilKit no tiene wrapper
//  nativo en SwiftUI. Permite dibujar con dedo y Apple Pencil.
//  El dibujo se serializa como Data (PKDrawing es Codable).
//

import SwiftUI
import PencilKit

struct GenogramCanvasView: UIViewRepresentable {

    @Binding var drawingData: Data?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .systemBackground

        // Cargar dibujo existente si hay datos guardados
        if let data = drawingData,
           let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }

        canvas.delegate = context.coordinator

        // Mostrar el tool picker para selección de herramientas
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        canvas.becomeFirstResponder()

        // Guardamos referencia al toolPicker en el coordinator
        // para que no se desaloque
        context.coordinator.toolPicker = toolPicker

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // No actualizamos desde SwiftUI para evitar sobreescribir
        // el dibujo mientras el usuario dibuja activamente
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    /// Coordinator que guarda el dibujo al cambiar
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawingData: Binding<Data?>
        var toolPicker: PKToolPicker?

        init(drawingData: Binding<Data?>) {
            self.drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Serializar el dibujo actual a Data para persistencia
            drawingData.wrappedValue = canvasView.drawing.dataRepresentation()
        }
    }
}
