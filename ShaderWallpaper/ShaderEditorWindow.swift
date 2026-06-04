import SwiftUI
import Combine

final class ShaderEditorState: ObservableObject {
    let packageURL: URL
    weak var activeRenderer: ShaderRenderer?
    @Published var effectName: String
    @Published var manifestText = ""
    @Published var sourceText = ""
    @Published var diagnostics: [String] = []
    @Published var previewEffect: ShaderEffectDescriptor?
    @Published var isDirty = false
    @Published var packageExists = true

    private let originalID: String
    private var watcher: PackageFolderWatcher?
    private var manifestURL: URL?
    private var sourceURL: URL?
    private var savedManifestText = ""
    private var savedSourceText = ""

    init(effect: ShaderEffectDescriptor, renderer: ShaderRenderer? = nil) {
        packageURL = effect.packageURL
        activeRenderer = renderer
        effectName = effect.name
        originalID = effect.id
        loadFromDisk()
        reloadPreview()
        watcher = PackageFolderWatcher(url: packageURL) { [weak self] in self?.externalChangeDetected() }
        watcher?.start()
    }

    func externalChangeDetected() {
        if isDirty {
            diagnostics.append("External package change detected. Reload from disk or keep your unsaved changes.")
        } else {
            loadFromDisk()
            reloadPreview()
        }
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
            let activeIDBeforeSave = activeRenderer?.currentShader?.id
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
            reloadPreview()
            activeRenderer?.reloadShaderPackages()
            if let previewEffect, previewEffect.id == activeIDBeforeSave {
                activeRenderer?.activateShader(previewEffect)
            }
        } catch {
            diagnostics.append("Save failed: \(error.localizedDescription)")
        }
    }

    func reloadPreview() {
        let candidate = ShaderPackageValidator.validatePackage(at: packageURL, source: .installed)
        diagnostics = candidate.diagnostics.map { "\($0.severity.rawValue.capitalized): \($0.message)" }
        guard candidate.isSelectable, let manifest = candidate.manifest else {
            if diagnostics.isEmpty { diagnostics.append("Package is not valid.") }
            return
        }
        let effect = ShaderEffectDescriptor(
            id: manifest.id,
            name: manifest.name,
            packageURL: packageURL,
            source: .installed,
            manifest: manifest,
            diagnostics: candidate.diagnostics
        )
        previewEffect = effect
        effectName = manifest.name
        if manifest.id != originalID {
            diagnostics.append("Package id changed; use Set Active again to activate the new Shader Effect identity.")
        }
        if manifest.editable != true {
            diagnostics.append("This package no longer allows editing. Close this Shader Editor Window.")
            packageExists = false
        }
        if case let .source(path) = manifest.artifact {
            let newSourceURL = packageURL.appendingPathComponent(path)
            if sourceURL?.standardizedFileURL != newSourceURL.standardizedFileURL, FileManager.default.fileExists(atPath: newSourceURL.path) {
                sourceURL = newSourceURL
                sourceText = (try? String(contentsOf: newSourceURL, encoding: .utf8)) ?? sourceText
                savedSourceText = sourceText
            } else if !FileManager.default.fileExists(atPath: newSourceURL.path), path.hasSuffix(".metal") {
                diagnostics.append("Source file is missing. Use Create Source File to add it.")
            }
        }
        if diagnostics.isEmpty { diagnostics.append("Saved and preview reloaded.") }
    }

    func setActive() {
        guard let previewEffect else { return }
        if isDirty {
            diagnostics.append("Save before Set Active, or the last saved version will be activated.")
        }
        activeRenderer?.activateShader(previewEffect)
    }

    func createMissingSourceFile() {
        guard let manifest = try? ShaderManifest.decodeYAML(manifestText), case let .source(path) = manifest.artifact, path.hasSuffix(".metal") else { return }
        let url = packageURL.appendingPathComponent(path)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let source = """
            #include <metal_stdlib>
            #include "ShaderWallpaper.h"
            using namespace metal;

            fragment float4 \(manifest.fragmentFunction)(ShaderWallpaperVertexOut in [[stage_in]], constant ShaderWallpaperUniforms& u [[buffer(0)]]) {
                return float4(in.uv, 0.5 + 0.5 * sin(u.time), 1.0);
            }
            """
            try source.write(to: url, atomically: true, encoding: .utf8)
            sourceURL = url
            sourceText = source
            savedSourceText = source
            reloadPreview()
        } catch {
            diagnostics.append("Create Source File failed: \(error.localizedDescription)")
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
                Button("Create Source File") { state.createMissingSourceFile() }
                Button("Set Active") { state.setActive() }
                    .disabled(state.previewEffect == nil)
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

            VStack(alignment: .leading) {
                Text("Preview")
                    .font(.headline)
                ShaderLivePreviewView(effect: state.previewEffect)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(minHeight: 180)
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

    init(effect: ShaderEffectDescriptor, renderer: ShaderRenderer? = nil) {
        self.packageURL = effect.packageURL.standardizedFileURL
        self.state = ShaderEditorState(effect: effect, renderer: renderer)
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
