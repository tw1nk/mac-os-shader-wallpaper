import SwiftUI

struct ShaderEditorWindowView: View {
    let packageURL: URL
    let effectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shader Editor Window")
                .font(.title2)
                .bold()
            Text(effectName)
                .font(.headline)
            Text(packageURL.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if !FileManager.default.fileExists(atPath: packageURL.path) {
                Label("Package no longer exists. Editing is disabled.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                Text("Manifest and source editing will appear here.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 720, minHeight: 520)
    }
}

final class ShaderEditorWindowController: NSWindowController, NSWindowDelegate {
    private static let frameAutosaveName = "ShaderEditorWindowFrame"

    let packageURL: URL
    var onClose: ((URL) -> Void)?

    init(effect: ShaderEffectDescriptor) {
        self.packageURL = effect.packageURL
        let view = ShaderEditorWindowView(packageURL: effect.packageURL, effectName: effect.name)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Shader Editor — \(effect.name)"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrameAutosaveName(Self.frameAutosaveName)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(packageURL)
    }
}
