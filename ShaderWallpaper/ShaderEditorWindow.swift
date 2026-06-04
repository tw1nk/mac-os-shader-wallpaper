import SwiftUI
import Combine

final class ShaderEditorState: ObservableObject {
    let packageURL: URL
    @Published var effectName: String
    @Published var manifestText = ""
    @Published var sourceText = ""
    @Published var diagnostics: [String] = []
    @Published var isDirty = false
    @Published var packageExists = true

    private var manifestURL: URL?
    private var sourceURL: URL?
    private var savedManifestText = ""
    private var savedSourceText = ""

    init(effect: ShaderEffectDescriptor) {
        packageURL = effect.packageURL
        effectName = effect.name
        loadFromDisk()
    }

    func loadFromDisk() {
        packageExists = FileManager.default.fileExists(atPath: packageURL.path)
        guard packageExists else { return }
        diagnostics.removeAll()
        let yamlURL = packageURL.appendingPathComponent("shader.yaml")
        let ymlURL = packageURL.appendingPathComponent("shader.yml")
        manifestURL = FileManager.default.fileExists(atPath: yamlURL.path) ? yamlURL : ymlURL
        guard let manifestURL else {
            diagnostics.append("Missing shader.yaml manifest.")
            return
        }

        do {
            manifestText = try String(contentsOf: manifestURL, encoding: .utf8)
            savedManifestText = manifestText
            let manifest = try ShaderManifest.decodeYAML(manifestText)
            effectName = manifest.name
            if case let .source(path) = manifest.artifact {
                sourceURL = packageURL.appendingPathComponent(path)
                sourceText = try String(contentsOf: sourceURL!, encoding: .utf8)
                savedSourceText = sourceText
            } else {
                diagnostics.append("This package is not source-backed.")
            }
            isDirty = false
        } catch {
            diagnostics.append(error.localizedDescription)
        }
    }

    func manifestChanged(_ value: String) {
        manifestText = value
        updateDirtyState()
    }

    func sourceChanged(_ value: String) {
        sourceText = value
        updateDirtyState()
    }

    func save() {
        guard packageExists else { return }
        diagnostics.removeAll()
        do {
            if manifestText != savedManifestText {
                guard let manifestURL else { throw ShaderEditorSaveError.missingManifestURL }
                try manifestText.write(to: manifestURL, atomically: true, encoding: .utf8)
                savedManifestText = manifestText
            }
            if sourceText != savedSourceText {
                guard let sourceURL else { throw ShaderEditorSaveError.missingSourceURL }
                try sourceText.write(to: sourceURL, atomically: true, encoding: .utf8)
                savedSourceText = sourceText
            }
            isDirty = false
            diagnostics.append("Saved.")
        } catch {
            diagnostics.append("Save failed: \(error.localizedDescription)")
        }
    }

    private func updateDirtyState() {
        isDirty = manifestText != savedManifestText || sourceText != savedSourceText
    }
}

private enum ShaderEditorSaveError: LocalizedError {
    case missingManifestURL
    case missingSourceURL

    var errorDescription: String? {
        switch self {
        case .missingManifestURL: return "Missing manifest URL."
        case .missingSourceURL: return "Missing source URL."
        }
    }
}

struct ShaderEditorWindowView: View {
    @ObservedObject var state: ShaderEditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Shader Editor Window")
                        .font(.title2)
                        .bold()
                    Text(state.packageURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("Save") { state.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!state.isDirty || !state.packageExists)
            }

            if !state.packageExists {
                Label("Package no longer exists. Editing is disabled.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            HSplitView {
                VStack(alignment: .leading) {
                    Text("shader.yaml")
                        .font(.headline)
                    SyntaxHighlightingTextView(
                        text: Binding(get: { state.manifestText }, set: state.manifestChanged),
                        syntax: .yaml,
                        isEditable: state.packageExists
                    )
                }
                VStack(alignment: .leading) {
                    Text("Source")
                        .font(.headline)
                    SyntaxHighlightingTextView(
                        text: Binding(get: { state.sourceText }, set: state.sourceChanged),
                        syntax: .metal,
                        isEditable: state.packageExists
                    )
                }
            }

            if !state.diagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(state.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                        Text(diagnostic)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .frame(minWidth: 900, minHeight: 620)
    }
}

final class ShaderEditorWindowController: NSWindowController, NSWindowDelegate {
    private static let frameAutosaveName = "ShaderEditorWindowFrame"

    let packageURL: URL
    let state: ShaderEditorState
    private var cancellables: Set<AnyCancellable> = []
    var onClose: ((URL) -> Void)?

    init(effect: ShaderEffectDescriptor) {
        self.packageURL = effect.packageURL.standardizedFileURL
        self.state = ShaderEditorState(effect: effect)
        let hostingController = NSHostingController(rootView: ShaderEditorWindowView(state: state))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Shader Editor — \(effect.name)"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrameAutosaveName(Self.frameAutosaveName)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        state.$isDirty
            .receive(on: RunLoop.main)
            .sink { [weak window, weak state] isDirty in
                let name = state?.effectName ?? effect.name
                window?.title = "Shader Editor — \(name)\(isDirty ? " *" : "")"
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard state.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Close without saving?"
        alert.informativeText = "This Shader Package has unsaved changes."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(packageURL)
    }
}
