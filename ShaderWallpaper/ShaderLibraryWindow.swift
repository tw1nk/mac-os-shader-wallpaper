import AppKit
import Combine
import SwiftUI

enum ShaderLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case builtIn
    case installed
    case warnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .builtIn: return "Built-in"
        case .installed: return "Installed"
        case .warnings: return "Warnings"
        }
    }
}

final class ShaderLibraryState: ObservableObject {
    @Published var selectedFilter: ShaderLibraryFilter {
        didSet {
            UserDefaults.standard.set(selectedFilter.rawValue, forKey: Self.selectedFilterKey)
        }
    }
    @Published var selectedShaderID: String?
    @Published var searchText = ""

    let renderer: ShaderRenderer

    private static let selectedFilterKey = "shaderLibrary.selectedFilter"

    init(renderer: ShaderRenderer) {
        self.renderer = renderer
        if
            let rawValue = UserDefaults.standard.string(forKey: Self.selectedFilterKey),
            let filter = ShaderLibraryFilter(rawValue: rawValue)
        {
            selectedFilter = filter
        } else {
            selectedFilter = .all
        }
        selectedShaderID = renderer.currentShader?.id ?? renderer.packageRegistry.effects.first?.id
    }

    var activeShaderID: String? {
        renderer.currentShader?.id
    }

    var hasDiagnostics: Bool {
        renderer.packageDiagnostics.contains { $0.severity == .warning || $0.severity == .error }
    }

    func setActive(_ effect: ShaderEffectDescriptor) {
        renderer.activateShader(effect)
        objectWillChange.send()
    }

    func reloadPackages() {
        renderer.reloadShaderPackages()
        if selectedShaderID == nil || !renderer.packageRegistry.effects.contains(where: { $0.id == selectedShaderID }) {
            selectedShaderID = renderer.packageRegistry.effects.first?.id
        }
        objectWillChange.send()
    }

    func openPackagesFolder() {
        let folderURL = ShaderPackageRegistryBuilder.installedShaderPackagesRoot()
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folderURL)
        } catch {
            renderer.packageDiagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .error,
                    code: .packageFolderOpenFailed,
                    message: "Could not open Shader Packages folder: \(error.localizedDescription)",
                    packageID: nil,
                    packageDisplayName: "Shader Packages Folder",
                    source: .installed,
                    packageURL: folderURL
                )
            )
            objectWillChange.send()
        }
    }

    func importPackage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            _ = try ShaderPackageInstaller.importPackage(from: url)
            reloadPackages()
        } catch {
            renderer.packageDiagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .error,
                    code: .importFailed,
                    message: "Import failed: \(error.localizedDescription)",
                    packageID: nil,
                    packageDisplayName: url.lastPathComponent,
                    source: .installed,
                    packageURL: url
                )
            )
            objectWillChange.send()
        }
    }

    func showDiagnostics() {
        let view = ShaderPackageDiagnosticsView(diagnostics: renderer.packageDiagnostics)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Shader Package Diagnostics"
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct ShaderLibraryWindowView: View {
    @ObservedObject var state: ShaderLibraryState

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Shader Library")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Import…") { state.importPackage() }
                    Button("Reload") { state.reloadPackages() }
                    Button("Open Packages Folder") { state.openPackagesFolder() }
                    if state.hasDiagnostics {
                        Button("Diagnostics") { state.showDiagnostics() }
                    }
                }

                Picker("Filter", selection: $state.selectedFilter) {
                    ForEach(ShaderLibraryFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Search shaders", text: $state.searchText)
                    .textFieldStyle(.roundedBorder)

                ShaderLibraryGrid(state: state)
            }
            .padding()
            .frame(minWidth: 360)

            ShaderLibraryDetailPane(state: state)
                .padding()
                .frame(minWidth: 320)
        }
        .frame(minWidth: 820, minHeight: 520)
    }
}

private struct ShaderLibraryGrid: View {
    @ObservedObject var state: ShaderLibraryState

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        let effects = filteredEffects
        Group {
            if effects.isEmpty {
                ContentUnavailableView(
                    "No Shader Effects",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text("Try another filter, clear search, install packages, or reload the library.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(effects, id: \.id) { effect in
                            ShaderEffectCard(
                                effect: effect,
                                isSelected: effect.id == state.selectedShaderID,
                                isActive: effect.id == state.activeShaderID
                            ) {
                                state.selectedShaderID = effect.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEffects: [ShaderEffectDescriptor] {
        state.renderer.packageRegistry.effects
            .filter(matchesFilter)
            .filter(matchesSearch)
            .sorted(by: sortEffects)
    }

    private func matchesFilter(_ effect: ShaderEffectDescriptor) -> Bool {
        switch state.selectedFilter {
        case .all:
            return true
        case .builtIn:
            return effect.source == .bundled
        case .installed:
            return effect.source == .installed
        case .warnings:
            return effect.hasWarnings
        }
    }

    private func matchesSearch(_ effect: ShaderEffectDescriptor) -> Bool {
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }

        return [
            effect.name,
            effect.id,
            effect.manifest.author ?? "",
            effect.manifest.description ?? ""
        ]
        .contains { $0.lowercased().contains(query) }
    }

    private func sortEffects(_ lhs: ShaderEffectDescriptor, _ rhs: ShaderEffectDescriptor) -> Bool {
        if lhs.source == .bundled, rhs.source == .bundled {
            let leftOrder = lhs.manifest.menuOrder ?? Int.max
            let rightOrder = rhs.manifest.menuOrder ?? Int.max
            if leftOrder != rightOrder { return leftOrder < rightOrder }
        }

        if lhs.source != rhs.source {
            return lhs.source == .bundled
        }

        if lhs.name != rhs.name { return lhs.name < rhs.name }
        return lhs.id < rhs.id
    }
}

private struct ShaderEffectCard: View {
    let effect: ShaderEffectDescriptor
    let isSelected: Bool
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ShaderEffectThumbnailPlaceholder(effect: effect)

                    HStack(spacing: 4) {
                        if effect.hasWarnings {
                            Badge(text: "⚠", color: .orange)
                        }
                        if isActive {
                            Badge(text: "Active", color: .green)
                        }
                    }
                    .padding(6)
                }

                Text(effect.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(effect.source == .bundled ? "Built-in" : "Installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ShaderEffectThumbnailPlaceholder: View {
    let effect: ShaderEffectDescriptor

    var body: some View {
        Group {
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.86))
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        }
    }

    private var previewImage: NSImage? {
        if let imagePath = effect.manifest.preview?.image {
            let imageURL = effect.packageURL.appendingPathComponent(imagePath)
            if let image = NSImage(contentsOf: imageURL) {
                return image
            }
        }

        return ShaderThumbnailCache.cachedOrGenerateThumbnail(for: effect, aspectRatio: currentDisplayAspectRatio)
    }

    private var currentDisplayAspectRatio: CGFloat {
        guard let screen = NSScreen.main, screen.frame.height > 0 else { return 16.0 / 9.0 }
        return screen.frame.width / screen.frame.height
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }
}

private struct ShaderLibraryDetailPane: View {
    @ObservedObject var state: ShaderLibraryState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.title3)
                .bold()

            ShaderLivePreviewView(effect: selectedEffect)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
                .aspectRatio(currentDisplayAspectRatio, contentMode: .fit)

            Divider()

            if let selectedEffect {
                HStack {
                    Text(selectedEffect.name)
                        .font(.headline)
                    if selectedEffect.id == state.activeShaderID {
                        Badge(text: "Active", color: .green)
                    }
                }
                Text(selectedEffect.manifest.description ?? "No description provided.")
                    .foregroundStyle(.secondary)
                Text(selectedEffect.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Button(selectedEffect.id == state.activeShaderID ? "Active" : "Set Active") {
                    state.setActive(selectedEffect)
                }
                .disabled(selectedEffect.id == state.activeShaderID)
            } else {
                Text("Select a Shader Effect")
                    .font(.headline)
                Text("Choose a card to preview its live shader output.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var selectedEffect: ShaderEffectDescriptor? {
        guard let selectedShaderID = state.selectedShaderID else { return nil }
        return state.renderer.packageRegistry.effects.first { $0.id == selectedShaderID }
    }

    private var currentDisplayAspectRatio: CGFloat {
        guard let screen = NSScreen.main, screen.frame.height > 0 else { return 16.0 / 9.0 }
        return screen.frame.width / screen.frame.height
    }
}

final class ShaderLibraryWindowController: NSWindowController, NSWindowDelegate {
    private static let frameAutosaveName = "ShaderLibraryWindowFrame"

    init(renderer: ShaderRenderer) {
        let state = ShaderLibraryState(renderer: renderer)
        let hostingController = NSHostingController(rootView: ShaderLibraryWindowView(state: state))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Shader Library"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrameAutosaveName(Self.frameAutosaveName)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
