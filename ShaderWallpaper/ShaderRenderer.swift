//
//  ShaderRenderer.swift
//  ShaderWallpaper
//
//  Created by Barnando Akbarto on 21/01/26.
//

import Cocoa
import ImageIO
import MetalKit
import SwiftUI

// MARK: - Shader Type
struct ShaderResources: OptionSet {
    let rawValue: Int

    static let mouse = ShaderResources(rawValue: 1 << 0)
    static let desktopTexture = ShaderResources(rawValue: 1 << 1)
}

struct ShaderRegistration {
    let functionName: String
    let resources: ShaderResources
}

enum ShaderType: String, CaseIterable {
    case balatro = "Balatro (Original)"
    case mulBox = "Multi Box"
    case tile = "Tiles"
    case pilar = "Pillars"
    case marble = "Marbles"
    case blackHole = "Black Hole"
    case shiny = "Shiny Color"
    case heavenly = "Heavenly"
    case appleLogo = "Apple Logo"
    case mouseRipple = "Mouse Ripple"
    case desktopWarp = "Desktop Warp"
    
    var registration: ShaderRegistration {
        switch self {
        case .balatro:
            return ShaderRegistration(functionName: "balatroShader", resources: [])
        case .mulBox:
            return ShaderRegistration(functionName: "multiBoxShader", resources: [])
        case .tile:
            return ShaderRegistration(functionName: "tileShader", resources: [])
        case .pilar:
            return ShaderRegistration(functionName: "pilarShader", resources: [])
        case .marble:
            return ShaderRegistration(functionName: "marbleShader", resources: [])
        case .blackHole:
            return ShaderRegistration(functionName: "blackHoleShader", resources: [])
        case .shiny:
            return ShaderRegistration(functionName: "shinyShader", resources: [])
        case .heavenly:
            return ShaderRegistration(functionName: "heavenlyShader", resources: [])
        case .appleLogo:
            return ShaderRegistration(functionName: "appleLogoShader", resources: [])
        case .mouseRipple:
            return ShaderRegistration(functionName: "mouseRippleShader", resources: [.mouse])
        case .desktopWarp:
            return ShaderRegistration(functionName: "desktopWarpShader", resources: [.mouse, .desktopTexture])
        }
    }

    var resources: ShaderResources {
        registration.resources
    }

    static let storageKey = "selectedShader"

    static var persistedSelection: ShaderType {
        guard
            let rawValue = UserDefaults.standard.string(forKey: storageKey),
            let shader = ShaderType(rawValue: rawValue)
        else {
            return ShaderType.allCases[0]
        }

        return shader
    }
}

struct Uniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var mouse: SIMD4<Float>
}

// MARK: - Shader Renderer
class ShaderRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var startTime: Date!
    var currentShader: ShaderType = ShaderType.persistedSelection
    private weak var metalView: MTKView?
    private var desktopTexture: MTLTexture?
    private var lastDesktopTextureRefresh = Date.distantPast
    private let desktopTextureRefreshInterval: TimeInterval = 300
    private var activeSpaceObserver: NSObjectProtocol?
    private var lastMousePosition = SIMD4<Float>(0, 0, 0, 0)
    
    init?(metalView: MTKView) {
        super.init()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        self.device = device
        self.metalView = metalView
        metalView.device = device
        self.commandQueue = device.makeCommandQueue()
        
        startTime = Date()
        observeActiveSpaceChanges()
        
        // Load the persisted shader when available, otherwise fall back to index 0.
        loadShader(currentShader, for: metalView)
    }
    
    deinit {
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
        }
    }
    
    private func observeActiveSpaceChanges() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            self?.reloadDesktopTextureAfterSpaceChange()
        }
    }

    func resyncDesktopTexture() {
        guard currentShader.resources.contains(.desktopTexture) else {
            return
        }

        loadDesktopTexture()

        for delay in [0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard self?.currentShader.resources.contains(.desktopTexture) == true else {
                    return
                }

                self?.loadDesktopTexture()
            }
        }
    }

    private func reloadDesktopTextureAfterSpaceChange() {
        resyncDesktopTexture()
    }
    
    private func loadDesktopTexture() {
        lastDesktopTextureRefresh = Date()

        guard
            let screen = metalView?.window?.screen ?? NSScreen.main,
            let imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
        else {
            print("Failed to find desktop image URL")
            desktopTexture = makeFallbackDesktopTexture()
            return
        }

        if let texture = makeDesktopTexture(from: imageURL) {
            desktopTexture = texture
            return
        }

        print("Failed to load desktop texture from \(imageURL.path)")
        desktopTexture = makeFallbackDesktopTexture()
    }

    private func refreshDesktopTextureIfNeeded() {
        guard
            currentShader.resources.contains(.desktopTexture),
            Date().timeIntervalSince(lastDesktopTextureRefresh) >= desktopTextureRefreshInterval
        else {
            return
        }

        loadDesktopTexture()
    }

    private func makeDesktopTexture(from imageURL: URL) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        let textureOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .textureUsage: MTLTextureUsage.shaderRead.rawValue
        ]

        for candidateURL in desktopTextureCandidateURLs(for: imageURL) {
            if let texture = makeTexture(
                from: candidateURL,
                textureLoader: textureLoader,
                options: textureOptions
            ) {
                return texture
            }
        }

        return nil
    }

    private func makeTexture(
        from imageURL: URL,
        textureLoader: MTKTextureLoader,
        options: [MTKTextureLoader.Option: Any]
    ) -> MTLTexture? {
        guard FileManager.default.isReadableFile(atPath: imageURL.path) else {
            return nil
        }

        if
            let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
            let cgImage = makeDesktopImage(from: source)
        {
            return try? textureLoader.newTexture(cgImage: cgImage, options: options)
        }

        return try? textureLoader.newTexture(URL: imageURL, options: options)
    }

    private func desktopTextureCandidateURLs(for imageURL: URL) -> [URL] {
        let path = imageURL.path

        guard path.contains("/com.apple.mobileAssetDesktop/") else {
            return [imageURL]
        }

        let desktopPicturesURL = URL(fileURLWithPath: "/System/Library/Desktop Pictures")
        let thumbnailsURL = desktopPicturesURL.appendingPathComponent(".thumbnails")
        let baseName = imageURL.deletingPathExtension().lastPathComponent
        let usesDarkAppearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let appearanceName = usesDarkAppearance ? "Dark" : "Light"

        return [
            thumbnailsURL.appendingPathComponent("\(baseName) \(appearanceName).heic"),
            thumbnailsURL.appendingPathComponent("\(baseName).heic"),
            desktopPicturesURL.appendingPathComponent("\(baseName).heic"),
            desktopPicturesURL.appendingPathComponent("\(baseName).madesktop")
        ]
    }

    private func makeDesktopImage(from source: CGImageSource) -> CGImage? {
        let imageCount = CGImageSourceGetCount(source)
        guard imageCount > 0 else {
            return nil
        }

        let imageIndex = desktopImageIndex(forImageCount: imageCount, source: source)
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, imageIndex, options)
    }

    private func desktopImageIndex(forImageCount imageCount: Int, source: CGImageSource) -> Int {
        guard imageCount > 1 else {
            return CGImageSourceGetPrimaryImageIndex(source)
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let secondsIntoDay =
            (components.hour ?? 0) * 3600 +
            (components.minute ?? 0) * 60 +
            (components.second ?? 0)
        let dayProgress = Double(secondsIntoDay) / 86_400.0
        let timeBasedIndex = Int(dayProgress * Double(imageCount))

        return min(max(timeBasedIndex, 0), imageCount - 1)
    }

    private func makeFallbackDesktopTexture() -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        var pixel: UInt32 = 0xFF111111
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &pixel,
            bytesPerRow: MemoryLayout<UInt32>.size
        )

        return texture
    }
    
    private func prepareResources(for shaderType: ShaderType) {
        if shaderType.resources.contains(.desktopTexture) {
            if desktopTexture == nil {
                loadDesktopTexture()
            }
        } else {
            desktopTexture = nil
        }

        if !shaderType.resources.contains(.mouse) {
            lastMousePosition = .zero
        }
    }
    
    func loadShader(_ shaderType: ShaderType, for metalView: MTKView) {
        let registration = shaderType.registration

        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: registration.functionName) else {
            print("Failed to load shader: \(shaderType.rawValue)")
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            currentShader = shaderType
            prepareResources(for: shaderType)
            UserDefaults.standard.set(shaderType.rawValue, forKey: ShaderType.storageKey)
            print("Loaded shader: \(shaderType.rawValue)")
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    private func mouseUniform(for view: MTKView) -> SIMD4<Float> {
        guard let window = view.window else {
            return lastMousePosition
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let viewPoint = view.convert(windowPoint, from: nil)

        guard view.bounds.contains(viewPoint), view.bounds.width > 0, view.bounds.height > 0 else {
            return lastMousePosition
        }

        let scaleX = view.drawableSize.width / view.bounds.width
        let scaleY = view.drawableSize.height / view.bounds.height

        lastMousePosition = SIMD4(
            Float(viewPoint.x * scaleX),
            Float(viewPoint.y * scaleY),
            0,
            0
        )

        return lastMousePosition
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        let time = Float(Date().timeIntervalSince(startTime))
        let resources = currentShader.resources
        var uniforms = Uniforms(
            time: time,
            resolution: SIMD2(
                Float(view.drawableSize.width),
                Float(view.drawableSize.height)
            ),
            mouse: resources.contains(.mouse) ? mouseUniform(for: view) : .zero
        )
        
        renderEncoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            index: 0
        )

        if resources.contains(.desktopTexture) {
            refreshDesktopTextureIfNeeded()

            if desktopTexture == nil {
                loadDesktopTexture()
            }

            if let desktopTexture {
                renderEncoder.setFragmentTexture(desktopTexture, index: 0)
            }
        }

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Window Controller
class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: WallpaperWindow!
    var metalView: MTKView!
    var renderer: ShaderRenderer!
    var statusItem: NSStatusItem!
    var isVisible = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupMenuBar()
        NSApp.setActivationPolicy(.accessory)
    }
    
    func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        
        window = WallpaperWindow(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.backgroundColor = .black
        window.isOpaque = true
        
        metalView = MTKView(frame: screenRect)
        metalView.autoresizingMask = [.width, .height]
        metalView.drawableSize = CGSize(
            width: screenRect.width * 0.5,
            height: screenRect.height * 0.5
        )
        
        renderer = ShaderRenderer(metalView: metalView)
        metalView.delegate = renderer
        metalView.preferredFramesPerSecond = 60
        
        window.contentView = metalView
        window.makeKeyAndOrderFront(nil)
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Shader Wallpaper")
        }
        
        let menu = NSMenu()
        
        // Visibility toggle
        let visibilityItem = NSMenuItem(
            title: "Hide Wallpaper",
            action: #selector(toggleVisibility),
            keyEquivalent: "h"
        )
        visibilityItem.target = self
        menu.addItem(visibilityItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Shader selection submenu
        let shaderMenu = NSMenu()
        for shader in ShaderType.allCases {
            let item = NSMenuItem(
                title: shader.rawValue,
                action: #selector(changeShader(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = shader
            item.state = shader == renderer.currentShader ? .on : .off
            shaderMenu.addItem(item)
        }
        
        let shaderMenuItem = NSMenuItem(title: "Select Shader", action: nil, keyEquivalent: "")
        shaderMenuItem.submenu = shaderMenu
        menu.addItem(shaderMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let resyncItem = NSMenuItem(
            title: "Re-sync Background",
            action: #selector(resyncBackground),
            keyEquivalent: "r"
        )
        resyncItem.target = self
        menu.addItem(resyncItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Shader Wallpaper",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func toggleVisibility() {
        isVisible.toggle()
        
        if isVisible {
            window.orderFront(nil)
            statusItem.menu?.item(at: 0)?.title = "Hide Wallpaper"
        } else {
            window.orderOut(nil)
            statusItem.menu?.item(at: 0)?.title = "Show Wallpaper"
        }
    }
    
    @objc func changeShader(_ sender: NSMenuItem) {
        guard let shader = sender.representedObject as? ShaderType else { return }
        
        renderer.loadShader(shader, for: metalView)
        
        // Update checkmarks
        if let shaderMenu = statusItem.menu?.item(at: 2)?.submenu {
            for item in shaderMenu.items {
                item.state = .off
            }
            sender.state = .on
        }
    }

    @objc func resyncBackground() {
        renderer.resyncDesktopTexture()
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

