import AppKit
import CryptoKit
import Foundation
import Metal

struct ShaderThumbnailCache {
    static let baselineWidth: CGFloat = 320

    static func thumbnailURL(for effect: ShaderEffectDescriptor, aspectRatio: CGFloat) -> URL {
        cacheRoot()
            .appendingPathComponent(cacheKey(for: effect, aspectRatio: aspectRatio))
            .appendingPathExtension("png")
    }

    static func cachedOrGenerateThumbnail(for effect: ShaderEffectDescriptor, aspectRatio: CGFloat) -> NSImage? {
        let url = thumbnailURL(for: effect, aspectRatio: aspectRatio)
        if let image = NSImage(contentsOf: url) {
            return image
        }

        guard let image = renderShaderThumbnail(for: effect, aspectRatio: aspectRatio) ?? generatePlaceholderThumbnail(for: effect, aspectRatio: aspectRatio),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: url)
        return image
    }

    static func cacheRoot() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches
            .appendingPathComponent("Shader Wallpaper", isDirectory: true)
            .appendingPathComponent("Shader Thumbnails", isDirectory: true)
    }

    private static func cacheKey(for effect: ShaderEffectDescriptor, aspectRatio: CGFloat) -> String {
        let artifactPath: String
        switch effect.manifest.artifact {
        case let .source(path), let .library(path): artifactPath = path
        case nil: artifactPath = "none"
        }
        let artifactURL = effect.packageURL.appendingPathComponent(artifactPath)
        let artifactMTime = ((try? artifactURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0)
        let previewPath = effect.manifest.preview?.image ?? ""
        let previewURL = effect.packageURL.appendingPathComponent(previewPath)
        let previewMTime = ((try? previewURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0)
        let raw = "\(effect.id)|\(effect.manifest.version)|\(effect.manifest.shaderInterfaceVersion)|\(aspectRatio)|\(artifactPath)|\(artifactMTime)|\(previewPath)|\(previewMTime)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func renderShaderThumbnail(for effect: ShaderEffectDescriptor, aspectRatio: CGFloat) -> NSImage? {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let appLibrary = try? device.makeDefaultLibrary(bundle: .main),
            let vertexFunction = appLibrary.makeFunction(name: "vertexShader")
        else { return nil }

        let packageLibrary: MTLLibrary
        do {
            switch effect.manifest.artifact {
            case let .library(path):
                packageLibrary = try device.makeLibrary(URL: effect.packageURL.appendingPathComponent(path))
            case .source:
                packageLibrary = try ShaderSourceCompiler.makeLibrary(for: effect, device: device)
            case nil:
                return nil
            }
        } catch {
            return nil
        }

        guard let fragmentFunction = packageLibrary.makeFunction(name: effect.manifest.fragmentFunction) else {
            return nil
        }

        let width = Int(baselineWidth)
        let height = max(1, Int(baselineWidth / max(aspectRatio, 0.1)))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else { return nil }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        guard
            let commandBuffer = queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return nil }

        var uniforms = Uniforms(
            time: 1,
            resolution: SIMD2(Float(width), Float(height)),
            mouse: .zero
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: width * 4,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private static func generatePlaceholderThumbnail(for effect: ShaderEffectDescriptor, aspectRatio: CGFloat) -> NSImage? {
        let width = baselineWidth
        let height = max(1, width / max(aspectRatio, 0.1))
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let hueSeed = CGFloat(abs(effect.id.hashValue % 10_000)) / 10_000.0
        let start = NSColor(calibratedHue: hueSeed, saturation: 0.75, brightness: 0.32, alpha: 1)
        let end = NSColor(calibratedHue: fmod(hueSeed + 0.25, 1), saturation: 0.9, brightness: 0.08, alpha: 1)
        NSGradient(starting: start, ending: end)?.draw(in: NSRect(origin: .zero, size: size), angle: 35)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.88)
        ]
        let text = effect.name as NSString
        let textSize = text.size(withAttributes: attrs)
        text.draw(
            at: NSPoint(x: 16, y: max(12, (height - textSize.height) / 2)),
            withAttributes: attrs
        )
        return image
    }
}
