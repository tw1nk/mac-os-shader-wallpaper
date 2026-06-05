import MetalKit
import SwiftUI

struct ShaderLivePreviewView: NSViewRepresentable {
    let effect: ShaderEffectDescriptor?
    var reloadToken: Int = 0

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
        let key = ReloadKey(effectID: effect?.id, reloadToken: reloadToken)
        if context.coordinator.reloadKey != key {
            context.coordinator.reloadKey = key
            if let effect {
                renderer.loadShader(effect, for: view, persistSelection: false)
                view.isPaused = false
            } else {
                view.isPaused = true
            }
        }
    }

    struct ReloadKey: Equatable {
        let effectID: String?
        let reloadToken: Int
    }

    final class Coordinator {
        var renderer: ShaderRenderer?
        var reloadKey: ReloadKey?
    }
}
