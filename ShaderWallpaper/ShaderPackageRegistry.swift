import Foundation

struct ShaderEffectDescriptor: Equatable {
    let id: String
    let name: String
    let packageURL: URL
    let source: ShaderPackageSource
    let manifest: ShaderManifest
    let diagnostics: [ShaderPackageDiagnostic]

    var hasWarnings: Bool {
        diagnostics.contains { $0.severity == .warning }
    }
}

struct ShaderPackageRegistry: Equatable {
    let candidates: [ShaderPackageCandidate]
    let effects: [ShaderEffectDescriptor]

    var diagnostics: [ShaderPackageDiagnostic] {
        candidates.flatMap(\.diagnostics)
    }
}

struct ShaderPackageRegistryBuilder {
    let bundledRootURL: URL
    let installedRootURL: URL

    func build() -> ShaderPackageRegistry {
        let discoveredCandidates = discoverCandidates()
        let resolvedCandidates = resolveDuplicates(in: discoveredCandidates)
        let effects = resolvedCandidates.compactMap { candidate -> ShaderEffectDescriptor? in
            guard candidate.isSelectable, let manifest = candidate.manifest else {
                return nil
            }

            return ShaderEffectDescriptor(
                id: manifest.id,
                name: manifest.name,
                packageURL: candidate.packageURL,
                source: candidate.source,
                manifest: manifest,
                diagnostics: candidate.diagnostics
            )
        }

        return ShaderPackageRegistry(candidates: resolvedCandidates, effects: effects)
    }

    private func discoverCandidates() -> [ShaderPackageCandidate] {
        discoverPackageDirectories(in: bundledRootURL)
            .map { ShaderPackageValidator.validatePackage(at: $0, source: .bundled) }
        + discoverPackageDirectories(in: installedRootURL)
            .map { ShaderPackageValidator.validatePackage(at: $0, source: .installed) }
    }

    private func discoverPackageDirectories(in rootURL: URL) -> [URL] {
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return children
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.path < $1.path }
    }

    private func resolveDuplicates(in candidates: [ShaderPackageCandidate]) -> [ShaderPackageCandidate] {
        var firstSelectableIndexByID: [String: Int] = [:]
        var duplicateLoserIndicesByWinnerIndex: [Int: [Int]] = [:]
        var result = candidates

        for (index, candidate) in candidates.enumerated() {
            guard candidate.isSelectable, let manifest = candidate.manifest else {
                continue
            }

            if let winnerIndex = firstSelectableIndexByID[manifest.id] {
                duplicateLoserIndicesByWinnerIndex[winnerIndex, default: []].append(index)
            } else {
                firstSelectableIndexByID[manifest.id] = index
            }
        }

        for (winnerIndex, loserIndices) in duplicateLoserIndicesByWinnerIndex {
            guard let winnerManifest = candidates[winnerIndex].manifest else {
                continue
            }

            let winnerWarning = makeDiagnostic(
                severity: .warning,
                code: .duplicateIdWinner,
                message: "Other Shader Packages with id '\(winnerManifest.id)' were ignored.",
                candidate: candidates[winnerIndex],
                packageID: winnerManifest.id
            )
            result[winnerIndex] = result[winnerIndex].addingDiagnostics([winnerWarning])

            for loserIndex in loserIndices {
                guard let loserManifest = candidates[loserIndex].manifest else {
                    continue
                }

                let loserError = makeDiagnostic(
                    severity: .error,
                    code: .duplicateIdIgnored,
                    message: "Duplicate Shader Package id '\(loserManifest.id)' ignored; first package in discovery order wins.",
                    candidate: candidates[loserIndex],
                    packageID: loserManifest.id
                )
                result[loserIndex] = result[loserIndex].addingDiagnostics([loserError])
            }
        }

        return result
    }

    private func makeDiagnostic(
        severity: ShaderDiagnosticSeverity,
        code: ShaderDiagnosticCode,
        message: String,
        candidate: ShaderPackageCandidate,
        packageID: String?
    ) -> ShaderPackageDiagnostic {
        ShaderPackageDiagnostic(
            severity: severity,
            code: code,
            message: message,
            packageID: packageID,
            packageDisplayName: candidate.packageURL.lastPathComponent,
            source: candidate.source,
            packageURL: candidate.packageURL
        )
    }
}
