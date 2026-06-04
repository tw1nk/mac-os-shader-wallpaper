import Foundation
import Metal
import MetalKit

struct ShaderEffectLoadResult {
    let pipelineState: MTLRenderPipelineState
    let desktopTextureIndex: Int
    let packageTextures: [(index: Int, texture: MTLTexture)]
    let diagnostics: [ShaderPackageDiagnostic]
}

struct ShaderEffectLoader {
    let device: MTLDevice
    let pixelFormat: MTLPixelFormat
    let bundle: Bundle

    init(device: MTLDevice, pixelFormat: MTLPixelFormat, bundle: Bundle = .main) {
        self.device = device
        self.pixelFormat = pixelFormat
        self.bundle = bundle
    }

    func load(_ shader: ShaderEffectDescriptor) throws -> ShaderEffectLoadResult {
        guard
            let appLibrary = try? device.makeDefaultLibrary(bundle: bundle),
            let vertexFunction = appLibrary.makeFunction(name: "vertexShader")
        else {
            throw ShaderEffectLoaderError.missingVertexFunction
        }

        let packageLibrary: MTLLibrary
        switch shader.manifest.artifact {
        case let .library(libraryPath):
            packageLibrary = try device.makeLibrary(URL: shader.packageURL.appendingPathComponent(libraryPath))
        case .source:
            packageLibrary = try ShaderSourceCompiler.makeLibrary(for: shader, device: device)
        case nil:
            throw ShaderSourceCompilerError.notSourcePackage
        }

        guard let fragmentFunction = packageLibrary.makeFunction(name: shader.manifest.fragmentFunction) else {
            throw ShaderEffectLoaderError.missingFragmentFunction(shader.manifest.fragmentFunction)
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        var reflection: MTLAutoreleasedRenderPipelineReflection?
        let pipelineState = try device.makeRenderPipelineState(
            descriptor: pipelineDescriptor,
            options: [.bindingInfo],
            reflection: &reflection
        )
        let bindings = try loadPackageTextures(for: shader, reflection: reflection)

        return ShaderEffectLoadResult(
            pipelineState: pipelineState,
            desktopTextureIndex: bindings.desktopTextureIndex,
            packageTextures: bindings.packageTextures,
            diagnostics: bindings.diagnostics
        )
    }

    private func loadPackageTextures(
        for shader: ShaderEffectDescriptor,
        reflection: MTLAutoreleasedRenderPipelineReflection?
    ) throws -> (desktopTextureIndex: Int, packageTextures: [(index: Int, texture: MTLTexture)], diagnostics: [ShaderPackageDiagnostic]) {
        let declaredTextures = shader.manifest.assets?.textures ?? []
        let declaredByName = Dictionary(uniqueKeysWithValues: declaredTextures.map { ($0.name, $0) })
        let fragmentTextureArguments = (reflection?.fragmentBindings ?? []).filter { $0.type == .texture }
        let textureArgumentByName = Dictionary(uniqueKeysWithValues: fragmentTextureArguments.map { ($0.name, $0) })
        let reservedTextureNames: Set<String> = ["desktopTexture"]
        var loadedTextures: [(index: Int, texture: MTLTexture)] = []
        var desktopTextureIndex = 0
        var diagnostics: [ShaderPackageDiagnostic] = []

        for argument in fragmentTextureArguments {
            if reservedTextureNames.contains(argument.name) {
                guard shader.manifest.resources.contains(argument.name) else {
                    throw ShaderPackageLoadError.unsatisfiedTextureArgument(argument.name)
                }
                desktopTextureIndex = argument.index
                continue
            }

            guard let textureAsset = declaredByName[argument.name] else {
                throw ShaderPackageLoadError.unsatisfiedTextureArgument(argument.name)
            }

            let textureURL = shader.packageURL.appendingPathComponent(textureAsset.path)
            let loader = MTKTextureLoader(device: device)
            let texture = try loader.newTexture(
                URL: textureURL,
                options: [
                    .SRGB: false,
                    .textureUsage: MTLTextureUsage.shaderRead.rawValue
                ]
            )
            loadedTextures.append((index: argument.index, texture: texture))
        }

        for textureAsset in declaredTextures where textureArgumentByName[textureAsset.name] == nil {
            diagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .warning,
                    code: .unusedTextureAsset,
                    message: "Texture asset '\(textureAsset.name)' is declared but not used by the fragment function.",
                    packageID: shader.id,
                    packageDisplayName: shader.name,
                    source: shader.source,
                    packageURL: shader.packageURL
                )
            )
        }

        return (desktopTextureIndex, loadedTextures, diagnostics)
    }
}

enum ShaderEffectLoaderError: LocalizedError {
    case missingVertexFunction
    case missingFragmentFunction(String)

    var errorDescription: String? {
        switch self {
        case .missingVertexFunction:
            return "Failed to load app vertex function."
        case let .missingFragmentFunction(name):
            return "Shader package does not contain fragment function '\(name)'."
        }
    }
}
