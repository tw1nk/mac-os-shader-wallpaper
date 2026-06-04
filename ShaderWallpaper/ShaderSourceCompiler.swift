import Foundation
import Metal

struct ShaderSourceIncludeValidator {
    private static let includePattern = #"^\s*#\s*include\s+([<"])([^>"]+)[>"]"#
    private static let allowedExtensions: Set<String> = ["metal", "h", "metalh"]

    static func validate(sourceURL: URL, packageURL: URL) -> [String] {
        var errors: [String] = []
        var visited: Set<String> = []
        validateFile(sourceURL, packageURL: packageURL, visited: &visited, errors: &errors)
        return errors
    }

    private static func validateFile(
        _ fileURL: URL,
        packageURL: URL,
        visited: inout Set<String>,
        errors: inout [String]
    ) {
        let standardized = fileURL.standardizedFileURL
        let key = standardized.path
        guard !visited.contains(key) else { return }
        visited.insert(key)

        guard isPackageLocal(standardized, packageURL: packageURL) else {
            errors.append("Include resolves outside the package: \(fileURL.path)")
            return
        }

        guard allowedExtensions.contains(standardized.pathExtension) else {
            errors.append("Included file has unsupported extension: \(standardized.lastPathComponent)")
            return
        }

        guard (try? standardized.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            errors.append("Included file may not be a symlink: \(standardized.lastPathComponent)")
            return
        }

        guard let source = try? String(contentsOf: standardized, encoding: .utf8) else {
            errors.append("Could not read included source file: \(standardized.lastPathComponent)")
            return
        }

        let regex = try? NSRegularExpression(pattern: includePattern, options: [])
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        regex?.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match else { return }
            let delimiterRange = match.range(at: 1)
            let pathRange = match.range(at: 2)
            guard
                let delimiterSwiftRange = Range(delimiterRange, in: source),
                let pathSwiftRange = Range(pathRange, in: source)
            else { return }

            let delimiter = String(source[delimiterSwiftRange])
            let includePath = String(source[pathSwiftRange])

            if delimiter == "<" {
                if includePath != "metal_stdlib" {
                    errors.append("Only <metal_stdlib> angle include is allowed: <\(includePath)>")
                }
                return
            }

            if includePath == "ShaderWallpaper.h" {
                return
            }

            guard isSafeRelativeInclude(includePath) else {
                errors.append("Include must be a relative package-local path without '..': \(includePath)")
                return
            }

            guard allowedExtensions.contains(URL(fileURLWithPath: includePath).pathExtension) else {
                errors.append("Include has unsupported extension: \(includePath)")
                return
            }

            let includedURL = standardized.deletingLastPathComponent().appendingPathComponent(includePath).standardizedFileURL
            guard FileManager.default.fileExists(atPath: includedURL.path) else {
                errors.append("Included file does not exist: \(includePath)")
                return
            }

            validateFile(includedURL, packageURL: packageURL, visited: &visited, errors: &errors)
        }
    }

    private static func isSafeRelativeInclude(_ includePath: String) -> Bool {
        !includePath.isEmpty &&
        !includePath.hasPrefix("/") &&
        !includePath.split(separator: "/").contains("..")
    }

    private static func isPackageLocal(_ fileURL: URL, packageURL: URL) -> Bool {
        let root = packageURL.standardizedFileURL.resolvingSymlinksInPath().path
        let resolved = fileURL.resolvingSymlinksInPath().path
        return resolved == root || resolved.hasPrefix(root + "/")
    }
}

struct ShaderSourceCompiler {
    static func makeLibrary(
        for shader: ShaderEffectDescriptor,
        device: MTLDevice
    ) throws -> MTLLibrary {
        guard case let .source(sourcePath) = shader.manifest.artifact else {
            throw ShaderSourceCompilerError.notSourcePackage
        }

        let sourceURL = shader.packageURL.appendingPathComponent(sourcePath)
        let includeErrors = ShaderSourceIncludeValidator.validate(sourceURL: sourceURL, packageURL: shader.packageURL)
        guard includeErrors.isEmpty else {
            throw ShaderSourceCompilerError.includeValidationFailed(includeErrors.joined(separator: "\n"))
        }

        var source = try String(contentsOf: sourceURL, encoding: .utf8)
        source = source.replacingOccurrences(
            of: #"(?m)^\s*#\s*include\s+"ShaderWallpaper\.h"\s*$\n?"#,
            with: "",
            options: .regularExpression
        )
        if let header = publicHeaderSource() {
            source = "#line 1 \"ShaderWallpaper.h\"\n\(header)\n#line 1 \"\(sourceURL.path)\"\n\(source)"
        }

        let options = MTLCompileOptions()
        options.mathMode = .fast
        if options.responds(to: Selector(("setIncludeSearchPaths:"))) {
            options.setValue([shader.packageURL.path], forKey: "includeSearchPaths")
        }

        return try device.makeLibrary(source: source, options: options)
    }

    private static func publicHeaderSource() -> String? {
        if let bundledURL = Bundle.main.url(forResource: "ShaderWallpaper", withExtension: "h") {
            return try? String(contentsOf: bundledURL, encoding: .utf8)
        }

        let sourceTreeURL = URL(fileURLWithPath: "ShaderWallpaper/Shaders/ShaderWallpaper.h")
        return try? String(contentsOf: sourceTreeURL, encoding: .utf8)
    }
}

enum ShaderSourceCompilerError: Error, LocalizedError {
    case notSourcePackage
    case includeValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSourcePackage:
            return "Package does not declare source."
        case let .includeValidationFailed(message):
            return message
        }
    }
}
