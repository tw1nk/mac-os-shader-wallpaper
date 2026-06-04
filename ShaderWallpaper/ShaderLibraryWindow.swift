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

            ShaderLibraryDetailPlaceholder(state: state)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.86))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

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

private struct ShaderLibraryDetailPlaceholder: View {
    @ObservedObject var state: ShaderLibraryState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.title3)
                .bold()

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.largeTitle)
                    Text("Live preview placeholder")
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)

            Divider()

            Text("Details placeholder")
                .font(.headline)
            Text("Selected effect metadata and Set Active controls are added in later slices.")
                .foregroundStyle(.secondary)

            Spacer()
        }
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
