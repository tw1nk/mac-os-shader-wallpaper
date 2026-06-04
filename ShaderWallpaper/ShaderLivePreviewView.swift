import MetalKit
import SwiftUI

struct ShaderLivePreviewView: NSViewRepresentable {
    let effect: ShaderEffectDescriptor?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.preferredFramesPerSecond = 30
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)

        if let renderer = ShaderRenderer(metalView: view) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
            if let effect {
                renderer.loadShader(effect, for: view, persistSelection: false)
            }
        }

        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        if context.coordinator.effectID != effect?.id {
            context.coordinator.effectID = effect?.id
            if let effect {
                renderer.loadShader(effect, for: view, persistSelection: false)
                view.isPaused = false
            } else {
                view.isPaused = true
            }
        }
    }

    final class Coordinator {
        var renderer: ShaderRenderer?
        var effectID: String?
    }
}
