import AppKit
import Foundation
import ZIPFoundation

struct ShaderPackageInstaller {
    static let maxArchiveBytes: UInt64 = 25 * 1024 * 1024
    static let maxExtractedBytes: UInt64 = 75 * 1024 * 1024
    static let maxFileBytes: UInt64 = 25 * 1024 * 1024

    static func importPackage(from url: URL) throws -> ShaderPackageCandidate {
        let stagingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShaderWallpaperImport", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingRoot) }

        let packageURL: URL
        if url.pathExtension == "wallshader" {
            try validateFileSize(url, maxBytes: maxArchiveBytes)
            packageURL = try extractArchive(url, to: stagingRoot)
        } else {
            packageURL = stagingRoot.appendingPathComponent(url.lastPathComponent, isDirectory: true)
            try copyDirectorySafely(from: url, to: packageURL)
        }

        try validatePackageSize(packageURL)
        let candidate = ShaderPackageValidator.validatePackage(at: packageURL, source: .installed)
        guard candidate.isSelectable, let manifest = candidate.manifest else {
            throw ShaderPackageInstallerError.invalidPackage(candidate.diagnostics)
        }

        let installedRoot = ShaderPackageRegistryBuilder.installedShaderPackagesRoot()
        try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
        let destination = installedRoot.appendingPathComponent(manifest.id, isDirectory: true)
        let bundledRegistry = ShaderPackageRegistryBuilder(
            bundledRootURL: ShaderPackageRegistryBuilder.bundledShaderPackagesRoot(),
            installedRootURL: URL(fileURLWithPath: "/__no_installed_packages__")
        ).build()
        guard !bundledRegistry.effects.contains(where: { $0.id == manifest.id }) else {
            throw ShaderPackageInstallerError.bundledIDCollision(manifest.id)
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: packageURL, to: destination)
        return ShaderPackageValidator.validatePackage(at: destination, source: .installed)
    }

    private static func extractArchive(_ archiveURL: URL, to stagingRoot: URL) throws -> URL {
        let archive = try Archive(url: archiveURL, accessMode: .read)
        let extractRoot = stagingRoot.appendingPathComponent("archive", isDirectory: true)
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)

        for entry in archive {
            try validateArchiveEntry(entry)
            _ = try archive.extract(entry, to: extractRoot.appendingPathComponent(entry.path))
        }
        return try findSinglePackageRoot(in: extractRoot)
    }

    private static func validateArchiveEntry(_ entry: Entry) throws {
        guard !entry.path.hasPrefix("/"), !entry.path.split(separator: "/").contains("..") else {
            throw ShaderPackageInstallerError.invalidArchive("Archive contains unsafe path: \(entry.path)")
        }
        guard entry.type != .symlink else {
            throw ShaderPackageInstallerError.invalidArchive("Archive contains symlink: \(entry.path)")
        }
        guard entry.uncompressedSize <= maxFileBytes else {
            throw ShaderPackageInstallerError.invalidArchive("Archive file exceeds size limit: \(entry.path)")
        }
    }

    private static func findSinglePackageRoot(in extractRoot: URL) throws -> URL {
        let rootManifests = manifestURLs(in: extractRoot)
        let childDirs = (try FileManager.default.contentsOfDirectory(at: extractRoot, includingPropertiesForKeys: [.isDirectoryKey]))
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        let childManifests = childDirs.flatMap { manifestURLs(in: $0) }
        let manifests = rootManifests + childManifests
        guard manifests.count == 1 else {
            throw ShaderPackageInstallerError.invalidArchive("Archive must contain exactly one shader manifest at root or one level down.")
        }
        return manifests[0].deletingLastPathComponent()
    }

    private static func manifestURLs(in directory: URL) -> [URL] {
        ["shader.yaml", "shader.yml"]
            .map { directory.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func copyDirectorySafely(from source: URL, to destination: URL) throws {
        try validateNoSymlinks(source)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private static func validateNoSymlinks(_ root: URL) throws {
        if (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            throw ShaderPackageInstallerError.invalidPackage([])
        }
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey])
        for case let url as URL in enumerator ?? FileManager.default.enumerator(atPath: root.path)! {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw ShaderPackageInstallerError.invalidPackage([])
            }
        }
    }

    private static func validateFileSize(_ url: URL, maxBytes: UInt64) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if UInt64(values.fileSize ?? 0) > maxBytes {
            throw ShaderPackageInstallerError.sizeLimitExceeded
        }
    }

    private static func validatePackageSize(_ packageURL: URL) throws {
        var total: UInt64 = 0
        let enumerator = FileManager.default.enumerator(at: packageURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
        for case let url as URL in enumerator ?? FileManager.default.enumerator(atPath: packageURL.path)! {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let size = UInt64(values.fileSize ?? 0)
            if size > maxFileBytes { throw ShaderPackageInstallerError.sizeLimitExceeded }
            total += size
            if total > maxExtractedBytes { throw ShaderPackageInstallerError.sizeLimitExceeded }
        }
    }
}

enum ShaderPackageInstallerError: LocalizedError {
    case invalidArchive(String)
    case invalidPackage([ShaderPackageDiagnostic])
    case bundledIDCollision(String)
    case sizeLimitExceeded

    var errorDescription: String? {
        switch self {
        case let .invalidArchive(message): return message
        case .invalidPackage: return "Imported package is invalid."
        case let .bundledIDCollision(id): return "Package id '\(id)' is already used by a built-in shader."
        case .sizeLimitExceeded: return "Imported package exceeds size limits."
        }
    }
}
