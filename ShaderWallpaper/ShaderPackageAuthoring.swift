import Foundation

struct ShaderPackageAuthoring {
    static func createNewPackage(name: String, id: String, existingRegistry: ShaderPackageRegistry) throws -> ShaderEffectDescriptor {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ShaderPackageAuthoringError.emptyName }
        guard isValidPackageID(trimmedID) else { throw ShaderPackageAuthoringError.invalidID }
        guard !existingRegistry.effects.contains(where: { $0.id == trimmedID }) else { throw ShaderPackageAuthoringError.duplicateID }

        let installedRoot = ShaderPackageRegistryBuilder.installedShaderPackagesRoot()
        let destination = installedRoot.appendingPathComponent(trimmedID, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw ShaderPackageAuthoringError.destinationExists }

        let stagingRoot = installedRoot.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        let sourcePath = "shaders/\(trimmedID.split(separator: ".").last ?? "shader").metal"
        let fragmentFunction = fragmentFunctionName(from: trimmedName)
        do {
            try FileManager.default.createDirectory(at: stagingRoot.appendingPathComponent("shaders", isDirectory: true), withIntermediateDirectories: true)
            try manifest(name: trimmedName, id: trimmedID, fragmentFunction: fragmentFunction, sourcePath: sourcePath)
                .write(to: stagingRoot.appendingPathComponent("shader.yaml"), atomically: true, encoding: .utf8)
            try starterShader(fragmentFunction: fragmentFunction)
                .write(to: stagingRoot.appendingPathComponent(sourcePath), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: installedRoot, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: stagingRoot, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: stagingRoot)
            throw error
        }

        let candidate = ShaderPackageValidator.validatePackage(at: destination, source: .installed)
        guard candidate.isSelectable, let manifest = candidate.manifest else {
            throw ShaderPackageAuthoringError.createdPackageInvalid
        }
        return ShaderEffectDescriptor(id: manifest.id, name: manifest.name, packageURL: destination, source: .installed, manifest: manifest, diagnostics: candidate.diagnostics)
    }

    private static func manifest(name: String, id: String, fragmentFunction: String, sourcePath: String) -> String {
        """
        # yaml-language-server: $schema=https://tw1nk.github.io/mac-os-shader-wallpaper/schemas/shader-manifest.schema.json
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: \(id)
        name: \(name)
        version: 0.1.0
        fragmentFunction: \(fragmentFunction)
        source: \(sourcePath)
        resources: []
        editable: true
        """
    }

    private static func starterShader(fragmentFunction: String) -> String {
        """
        #include <metal_stdlib>
        #include "ShaderWallpaper.h"
        using namespace metal;

        // Minimal Shader Interface v1 fragment. Time and resolution are always available in uniforms.
        fragment float4 \(fragmentFunction)(
            ShaderWallpaperVertexOut in [[stage_in]],
            constant ShaderWallpaperUniforms& u [[buffer(0)]]
        ) {
            float2 uv = in.uv;
            float wave = 0.5 + 0.5 * sin(u.time + uv.x * 6.28318);
            float3 color = mix(float3(0.08, 0.12, 0.35), float3(0.95, 0.35, 0.85), uv.y);
            color += float3(0.2, 0.45, 0.55) * wave;
            return float4(color, 1.0);
        }
        """
    }

    private static func fragmentFunctionName(from name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let base = words.enumerated().map { index, word in
            let lower = word.lowercased()
            if index == 0 { return lower }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined()
        let candidate = base.isEmpty ? "newShader" : base + "Shader"
        if candidate.first?.isNumber == true { return "shader\(candidate)" }
        return candidate
    }

    private static func isValidPackageID(_ value: String) -> Bool {
        let pattern = #"^[a-z0-9-]+(\.[a-z0-9-]+)+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum ShaderPackageAuthoringError: LocalizedError {
    case emptyName
    case invalidID
    case duplicateID
    case destinationExists
    case createdPackageInvalid

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Name must not be empty."
        case .invalidID: return "Package id must be lowercase reverse-DNS style using letters, numbers, dots, and hyphens."
        case .duplicateID: return "A discovered Shader Package already uses that id."
        case .destinationExists: return "A package folder already exists for that id."
        case .createdPackageInvalid: return "The generated Shader Package was invalid."
        }
    }
}
