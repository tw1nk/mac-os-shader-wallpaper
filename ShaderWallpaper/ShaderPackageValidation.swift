import Foundation
import Yams

enum ShaderPackageSource: String, Equatable {
    case bundled
    case installed
}

enum ShaderDiagnosticSeverity: String, Equatable {
    case warning
    case error
}

enum ShaderDiagnosticCode: String, Equatable {
    case invalidManifestYaml
    case missingRequiredField
    case invalidManifestVersion
    case invalidShaderInterfaceVersion
    case invalidPackageId
    case sourceLibraryConflict
    case missingShaderArtifact
    case unsafePath
    case missingReferencedFile
    case symlinkNotAllowed
    case unknownResource
    case userMenuOrderIgnored
    case invalidTextureAsset
    case unknownManifestField
    case duplicateIdWinner
    case duplicateIdIgnored
    case compileFailed
    case unusedTextureAsset
    case packageFolderOpenFailed
    case importFailed
}

struct ShaderPackageDiagnostic: Equatable {
    let severity: ShaderDiagnosticSeverity
    let code: ShaderDiagnosticCode
    let message: String
    let packageID: String?
    let packageDisplayName: String
    let source: ShaderPackageSource
    let packageURL: URL?
}

struct ShaderPackageCandidate: Equatable {
    let packageURL: URL
    let source: ShaderPackageSource
    let manifest: ShaderManifest?
    let manifestURL: URL?
    let diagnostics: [ShaderPackageDiagnostic]

    var isSelectable: Bool {
        manifest != nil && !diagnostics.contains { $0.severity == .error }
    }

    func addingDiagnostics(_ additionalDiagnostics: [ShaderPackageDiagnostic]) -> ShaderPackageCandidate {
        ShaderPackageCandidate(
            packageURL: packageURL,
            source: source,
            manifest: manifest,
            manifestURL: manifestURL,
            diagnostics: diagnostics + additionalDiagnostics
        )
    }
}

struct ShaderPackageValidator {
    private static let knownResources: Set<String> = ["mouse", "desktopTexture"]
    private static let requiredFields: Set<String> = [
        "manifestVersion",
        "shaderInterfaceVersion",
        "id",
        "name",
        "version",
        "fragmentFunction",
        "resources"
    ]

    static func validatePackage(at packageURL: URL, source: ShaderPackageSource) -> ShaderPackageCandidate {
        var diagnostics: [ShaderPackageDiagnostic] = []
        let displayName = packageURL.lastPathComponent

        func diagnostic(
            _ severity: ShaderDiagnosticSeverity,
            _ code: ShaderDiagnosticCode,
            _ message: String,
            packageID: String? = nil
        ) -> ShaderPackageDiagnostic {
            ShaderPackageDiagnostic(
                severity: severity,
                code: code,
                message: message,
                packageID: packageID,
                packageDisplayName: displayName,
                source: source,
                packageURL: packageURL
            )
        }

        if containsSymlink(in: packageURL) {
            diagnostics.append(diagnostic(.error, .symlinkNotAllowed, "Shader Packages may not contain symlinks."))
        }

        let yamlURL = packageURL.appendingPathComponent("shader.yaml")
        let ymlURL = packageURL.appendingPathComponent("shader.yml")
        let hasYAML = FileManager.default.fileExists(atPath: yamlURL.path)
        let hasYML = FileManager.default.fileExists(atPath: ymlURL.path)

        guard hasYAML || hasYML else {
            diagnostics.append(diagnostic(.error, .missingRequiredField, "Missing shader.yaml manifest."))
            return ShaderPackageCandidate(packageURL: packageURL, source: source, manifest: nil, manifestURL: nil, diagnostics: diagnostics)
        }

        guard !(hasYAML && hasYML) else {
            diagnostics.append(diagnostic(.error, .invalidManifestYaml, "Package contains both shader.yaml and shader.yml; use exactly one."))
            return ShaderPackageCandidate(packageURL: packageURL, source: source, manifest: nil, manifestURL: nil, diagnostics: diagnostics)
        }

        let manifestURL = hasYAML ? yamlURL : ymlURL
        let yaml: String
        do {
            yaml = try String(contentsOf: manifestURL, encoding: .utf8)
        } catch {
            diagnostics.append(diagnostic(.error, .invalidManifestYaml, "Could not read manifest: \(error.localizedDescription)"))
            return ShaderPackageCandidate(packageURL: packageURL, source: source, manifest: nil, manifestURL: manifestURL, diagnostics: diagnostics)
        }

        let rawMapping: [String: Any]
        do {
            rawMapping = try (Yams.load(yaml: yaml) as? [String: Any]) ?? [:]
        } catch {
            diagnostics.append(diagnostic(.error, .invalidManifestYaml, "Invalid YAML: \(error.localizedDescription)"))
            return ShaderPackageCandidate(packageURL: packageURL, source: source, manifest: nil, manifestURL: manifestURL, diagnostics: diagnostics)
        }

        for field in requiredFields.sorted() where rawMapping[field] == nil {
            diagnostics.append(diagnostic(.error, .missingRequiredField, "Missing required manifest field: \(field)."))
        }

        for field in unknownFields(in: rawMapping, allowed: UnknownYAMLFieldReporter.manifestV1TopLevelKeys) {
            diagnostics.append(diagnostic(.warning, .unknownManifestField, "Unknown manifest field ignored: \(field)."))
        }
        diagnostics.append(contentsOf: nestedUnknownFieldDiagnostics(in: rawMapping, displayName: displayName, source: source))

        let manifest: ShaderManifest
        do {
            manifest = try ShaderManifest.decodeYAML(yaml)
        } catch {
            diagnostics.append(diagnostic(.error, .invalidManifestYaml, "Could not decode manifest: \(error.localizedDescription)"))
            return ShaderPackageCandidate(packageURL: packageURL, source: source, manifest: nil, manifestURL: manifestURL, diagnostics: diagnostics)
        }

        func manifestDiagnostic(
            _ severity: ShaderDiagnosticSeverity,
            _ code: ShaderDiagnosticCode,
            _ message: String
        ) -> ShaderPackageDiagnostic {
            diagnostic(severity, code, message, packageID: manifest.id)
        }

        if manifest.manifestVersion < 1 {
            diagnostics.append(manifestDiagnostic(.error, .invalidManifestVersion, "manifestVersion must be a positive integer."))
        }

        if manifest.shaderInterfaceVersion < 1 {
            diagnostics.append(manifestDiagnostic(.error, .invalidShaderInterfaceVersion, "shaderInterfaceVersion must be a positive integer."))
        }

        if !isValidPackageID(manifest.id) {
            diagnostics.append(manifestDiagnostic(.error, .invalidPackageId, "Package id must be lowercase reverse-DNS style using letters, numbers, dots, and hyphens."))
        }

        switch (manifest.source, manifest.library) {
        case (.some, .some):
            diagnostics.append(manifestDiagnostic(.error, .sourceLibraryConflict, "Specify exactly one of source or library, not both."))
        case (nil, nil):
            diagnostics.append(manifestDiagnostic(.error, .missingShaderArtifact, "Specify exactly one of source or library."))
        default:
            break
        }

        if let sourcePath = manifest.source {
            diagnostics.append(contentsOf: validateManifestPath(sourcePath, field: "source", packageURL: packageURL, manifest: manifest, displayName: displayName, source: source))
        }

        if let libraryPath = manifest.library {
            diagnostics.append(contentsOf: validateManifestPath(libraryPath, field: "library", packageURL: packageURL, manifest: manifest, displayName: displayName, source: source))
        }

        var textureNames: Set<String> = []
        for texture in manifest.assets?.textures ?? [] {
            if !isValidIdentifier(texture.name) {
                diagnostics.append(manifestDiagnostic(.error, .invalidTextureAsset, "Texture asset name '\(texture.name)' must be a valid identifier."))
            }
            if texture.name == "desktopTexture" {
                diagnostics.append(manifestDiagnostic(.error, .invalidTextureAsset, "Texture asset name 'desktopTexture' is reserved."))
            }
            if !textureNames.insert(texture.name).inserted {
                diagnostics.append(manifestDiagnostic(.error, .invalidTextureAsset, "Texture asset name '\(texture.name)' is duplicated."))
            }
            diagnostics.append(contentsOf: validateManifestPath(texture.path, field: "assets.textures.\(texture.name).path", packageURL: packageURL, manifest: manifest, displayName: displayName, source: source))
        }

        for resource in manifest.resources where !knownResources.contains(resource) {
            diagnostics.append(manifestDiagnostic(.warning, .unknownResource, "Unknown resource '\(resource)' will be ignored."))
        }

        if source == .installed, manifest.menuOrder != nil {
            diagnostics.append(manifestDiagnostic(.warning, .userMenuOrderIgnored, "Installed packages cannot set menuOrder; it will be ignored."))
        }

        return ShaderPackageCandidate(packageURL: packageURL, source: source, manifest: manifest, manifestURL: manifestURL, diagnostics: diagnostics)
    }

    private static func isValidPackageID(_ id: String) -> Bool {
        id.range(of: #"^[a-z0-9-]+(\.[a-z0-9-]+)+$"#, options: .regularExpression) != nil
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil
    }

    private static func containsSymlink(in rootURL: URL) -> Bool {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey]

        if (try? rootURL.resourceValues(forKeys: Set(keys)).isSymbolicLink) == true {
            return true
        }

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: nil
        ) else {
            return false
        }

        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: Set(keys)).isSymbolicLink) == true {
                return true
            }
        }

        return false
    }

    private static func validateManifestPath(
        _ path: String,
        field: String,
        packageURL: URL,
        manifest: ShaderManifest,
        displayName: String,
        source: ShaderPackageSource
    ) -> [ShaderPackageDiagnostic] {
        func diagnostic(_ code: ShaderDiagnosticCode, _ message: String) -> ShaderPackageDiagnostic {
            ShaderPackageDiagnostic(
                severity: .error,
                code: code,
                message: message,
                packageID: manifest.id,
                packageDisplayName: displayName,
                source: source,
                packageURL: packageURL
            )
        }

        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            return [diagnostic(.unsafePath, "\(field) must be a relative package-local path.")]
        }

        let root = packageURL.standardizedFileURL.resolvingSymlinksInPath().path
        let fileURL = packageURL.appendingPathComponent(path).standardizedFileURL
        let resolved = fileURL.resolvingSymlinksInPath().path

        guard resolved == root || resolved.hasPrefix(root + "/") else {
            return [diagnostic(.unsafePath, "\(field) resolves outside the package.")]
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [diagnostic(.missingReferencedFile, "\(field) references a missing file: \(path).")]
        }

        if (try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            return [diagnostic(.symlinkNotAllowed, "\(field) may not reference a symlink.")]
        }

        return []
    }

    private static func unknownFields(in mapping: [String: Any], allowed: Set<String>) -> [String] {
        mapping.keys.filter { !allowed.contains($0) }.sorted()
    }

    private static func nestedUnknownFieldDiagnostics(
        in mapping: [String: Any],
        displayName: String,
        source: ShaderPackageSource
    ) -> [ShaderPackageDiagnostic] {
        var diagnostics: [ShaderPackageDiagnostic] = []

        func warning(_ field: String) {
            diagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .warning,
                    code: .unknownManifestField,
                    message: "Unknown manifest field ignored: \(field).",
                    packageID: mapping["id"] as? String,
                    packageDisplayName: displayName,
                    source: source,
                    packageURL: nil
                )
            )
        }

        if let assets = mapping["assets"] as? [String: Any] {
            for key in assets.keys where key != "textures" {
                warning("assets.\(key)")
            }

            if let textures = assets["textures"] as? [[String: Any]] {
                for (index, texture) in textures.enumerated() {
                    for key in texture.keys where key != "name" && key != "path" {
                        warning("assets.textures[\(index)].\(key)")
                    }
                }
            }
        }

        return diagnostics
    }
}
