import SwiftUI
import AppKit

struct ShaderPackageDiagnosticsView: View {
    let diagnostics: [ShaderPackageDiagnostic]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shader Package Diagnostics")
                .font(.title2)
                .bold()

            if diagnostics.isEmpty {
                Text("No warnings or errors.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    diagnosticsSection(title: "Built-in", source: .bundled)
                    diagnosticsSection(title: "Installed", source: .installed)
                }
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 420)
    }

    @ViewBuilder
    private func diagnosticsSection(title: String, source: ShaderPackageSource) -> some View {
        let sourceDiagnostics = diagnostics.filter { $0.source == source }
        if !sourceDiagnostics.isEmpty {
            Section(title) {
                ForEach(Array(sourceDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    DiagnosticRow(diagnostic: diagnostic)
                }
            }
        }
    }
}

private struct DiagnosticRow: View {
    let diagnostic: ShaderPackageDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(diagnostic.severity == .error ? "Error" : "Warning")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                Text(diagnostic.code.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if diagnostic.source == .installed, let url = diagnostic.packageURL {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }

            Text(diagnostic.packageID ?? diagnostic.packageDisplayName)
                .font(.headline)
            Text(diagnostic.message)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
