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
import UniformTypeIdentifiers

// MARK: - Shader Type
struct ShaderResources: OptionSet {
    let rawValue: Int

    static let mouse = ShaderResources(rawValue: 1 << 0)
    static let desktopTexture = ShaderResources(rawValue: 1 << 1)
}

extension ShaderEffectDescriptor {
    static let storageKey = "selectedShaderID"

    var displayName: String {
        hasWarnings ? "\(name) ⚠" : name
    }

    var resources: ShaderResources {
        var resources: ShaderResources = []
        if manifest.resources.contains("mouse") {
            resources.insert(.mouse)
        }
        if manifest.resources.contains("desktopTexture") {
            resources.insert(.desktopTexture)
        }
        return resources
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
    var packageRegistry: ShaderPackageRegistry
    var currentShader: ShaderEffectDescriptor?
    var packageDiagnostics: [ShaderPackageDiagnostic] = []
    private(set) var isShowingErrorShader = false
    private weak var metalView: MTKView?
    private var desktopTexture: MTLTexture?
    private var activeDesktopTextureIndex = 0
    private var activePackageTextures: [(index: Int, texture: MTLTexture)] = []
    private var lastDesktopTextureRefresh = Date.distantPast
    private let desktopTextureRefreshInterval: TimeInterval = 300
    private var isLoadingDesktopTexture = false
    private var activeSpaceObserver: NSObjectProtocol?
    private var lastMousePosition = SIMD4<Float>(0, 0, 0, 0)
    
    init?(metalView: MTKView) {
        let registry = ShaderPackageRegistryBuilder.defaultBuilder().build()
        self.packageRegistry = registry
        self.packageDiagnostics = registry.diagnostics
        self.currentShader = ShaderRenderer.initialShader(from: registry)

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
        
        if let currentShader {
            loadShader(currentShader, for: metalView, isInitialLoad: true)
        } else {
            loadErrorShader(for: metalView, reason: "No valid shader packages found.")
        }
    }
    
    deinit {
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
        }
    }
    
    private static func initialShader(from registry: ShaderPackageRegistry) -> ShaderEffectDescriptor? {
        if
            let persistedID = UserDefaults.standard.string(forKey: ShaderEffectDescriptor.storageKey),
            let persistedShader = registry.effects.first(where: { $0.id == persistedID })
        {
            return persistedShader
        }

        return registry.effects.first
    }

    func activateShader(_ shader: ShaderEffectDescriptor) {
        guard let metalView else { return }
        loadShader(shader, for: metalView)
    }

    func reloadShaderPackages() {
        let selectedID = currentShader?.id ?? UserDefaults.standard.string(forKey: ShaderEffectDescriptor.storageKey)
        packageRegistry = ShaderPackageRegistryBuilder.defaultBuilder().build()
        packageDiagnostics = packageRegistry.diagnostics

        guard let selectedID else { return }
        guard let reloadedShader = packageRegistry.effects.first(where: { $0.id == selectedID }) else {
            if let metalView {
                currentShader = nil
                loadErrorShader(for: metalView, reason: "Selected shader package '\(selectedID)' is no longer available.")
            }
            return
        }

        if let metalView {
            loadShader(reloadedShader, for: metalView, isInitialLoad: true)
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
        guard currentShader?.resources.contains(.desktopTexture) == true else {
            return
        }

        requestDesktopTextureLoad()

        for delay in [0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard self?.currentShader?.resources.contains(.desktopTexture) == true else {
                    return
                }

                self?.requestDesktopTextureLoad()
            }
        }
    }

    private func reloadDesktopTextureAfterSpaceChange() {
        resyncDesktopTexture()
    }
    
    private func requestDesktopTextureLoad() {
        guard !isLoadingDesktopTexture else {
            return
        }

        lastDesktopTextureRefresh = Date()
        isLoadingDesktopTexture = true

        if desktopTexture == nil {
            desktopTexture = makeFallbackDesktopTexture()
        }

        guard
            let screen = metalView?.window?.screen ?? NSScreen.main,
            let imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
        else {
            print("Failed to find desktop image URL")
            isLoadingDesktopTexture = false
            return
        }

        let candidateURLs = desktopTextureCandidateURLs(for: imageURL)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let texture = makeDesktopTexture(from: candidateURLs)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isLoadingDesktopTexture = false

                guard currentShader?.resources.contains(.desktopTexture) == true else {
                    return
                }

                if let texture {
                    desktopTexture = texture
                } else {
                    print("Failed to load desktop texture from \(imageURL.path)")
                    desktopTexture = makeFallbackDesktopTexture()
                }
            }
        }
    }

    private func refreshDesktopTextureIfNeeded() {
        guard
            currentShader?.resources.contains(.desktopTexture) == true,
            Date().timeIntervalSince(lastDesktopTextureRefresh) >= desktopTextureRefreshInterval
        else {
            return
        }

        requestDesktopTextureLoad()
    }

    private func makeDesktopTexture(from candidateURLs: [URL]) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        let textureOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .textureUsage: MTLTextureUsage.shaderRead.rawValue
        ]

        for candidateURL in candidateURLs {
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
    
    private func prepareResources(for shader: ShaderEffectDescriptor) {
        if shader.resources.contains(.desktopTexture) {
            if desktopTexture == nil {
                requestDesktopTextureLoad()
            }
        } else {
            desktopTexture = nil
        }

        activePackageTextures = []
        activeDesktopTextureIndex = 0

        if !shader.resources.contains(.mouse) {
            lastMousePosition = .zero
        }
    }
    
    func loadShader(_ shader: ShaderEffectDescriptor, for metalView: MTKView, isInitialLoad: Bool = false, persistSelection: Bool = true) {
        do {
            let result = try ShaderEffectLoader(device: device, pixelFormat: metalView.colorPixelFormat).load(shader)

            pipelineState = result.pipelineState
            currentShader = shader
            isShowingErrorShader = false
            prepareResources(for: shader)
            activeDesktopTextureIndex = result.desktopTextureIndex
            activePackageTextures = result.packageTextures
            packageDiagnostics.append(contentsOf: result.diagnostics)
            if persistSelection {
                UserDefaults.standard.set(shader.id, forKey: ShaderEffectDescriptor.storageKey)
            }
            print("Loaded shader: \(shader.name)")
        } catch {
            recordLoadFailure(for: shader, message: "Failed to create pipeline for shader package '\(shader.name)': \(error.localizedDescription)")
            if isInitialLoad {
                loadErrorShader(for: metalView, reason: "Selected shader package '\(shader.id)' could not render.")
            }
        }
    }
    
    private func recordLoadFailure(for shader: ShaderEffectDescriptor, message: String) {
        packageDiagnostics.append(
            ShaderPackageDiagnostic(
                severity: .error,
                code: .compileFailed,
                message: message,
                packageID: shader.id,
                packageDisplayName: shader.name,
                source: shader.source,
                packageURL: shader.packageURL
            )
        )
        print(message)
    }

    private func loadErrorShader(for metalView: MTKView, reason: String) {
        guard
            let library = try? device.makeDefaultLibrary(bundle: Bundle.main),
            let vertexFunction = library.makeFunction(name: "vertexShader"),
            let fragmentFunction = library.makeFunction(name: "errorShader")
        else {
            print("Failed to load Error Shader")
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            isShowingErrorShader = true
            desktopTexture = nil
            lastMousePosition = .zero
            packageDiagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .error,
                    code: .compileFailed,
                    message: reason,
                    packageID: currentShader?.id,
                    packageDisplayName: currentShader?.name ?? "Error Shader",
                    source: currentShader?.source ?? .bundled,
                    packageURL: currentShader?.packageURL
                )
            )
            print(reason)
        } catch {
            print("Failed to create Error Shader pipeline state: \(error)")
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
            Float((view.bounds.height - viewPoint.y) * scaleY),
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
        let resources = currentShader?.resources ?? []
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
                requestDesktopTextureLoad()
            }

            if let desktopTexture {
                renderEncoder.setFragmentTexture(desktopTexture, index: activeDesktopTextureIndex)
            }
        }

        for packageTexture in activePackageTextures {
            renderEncoder.setFragmentTexture(packageTexture.texture, index: packageTexture.index)
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
    var statusItem: NSStatusItem?
    var diagnosticsWindow: NSWindow?
    var shaderLibraryWindowController: ShaderLibraryWindowController?
    var shaderEditorWindowControllers: [URL: ShaderEditorWindowController] = [:]
    var isVisible = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupMenuBar()
        NSApp.setActivationPolicy(.accessory)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        importShaderPackageURL(URL(fileURLWithPath: filename))
        return true
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
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        
        if let button = statusItem?.button {
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

        let shaderLibraryItem = NSMenuItem(
            title: "Open Shader Library…",
            action: #selector(openShaderLibrary),
            keyEquivalent: ""
        )
        shaderLibraryItem.target = self
        menu.addItem(shaderLibraryItem)
        
        let shaderMenuItem = NSMenuItem(title: "Select Shader", action: nil, keyEquivalent: "")
        shaderMenuItem.submenu = makeShaderMenu()
        menu.addItem(shaderMenuItem)
        
        menu.addItem(NSMenuItem.separator())

        let openPackagesFolderItem = NSMenuItem(
            title: "Open Shader Packages Folder",
            action: #selector(openShaderPackagesFolder),
            keyEquivalent: ""
        )
        openPackagesFolderItem.target = self
        menu.addItem(openPackagesFolderItem)

        let newPackageItem = NSMenuItem(
            title: "New Shader Package…",
            action: #selector(newShaderPackage),
            keyEquivalent: ""
        )
        newPackageItem.target = self
        menu.addItem(newPackageItem)

        let importPackagesItem = NSMenuItem(
            title: "Import .wallshader or Folder…",
            action: #selector(importShaderPackage),
            keyEquivalent: ""
        )
        importPackagesItem.target = self
        menu.addItem(importPackagesItem)

        let reloadPackagesItem = NSMenuItem(
            title: "Reload Shader Packages",
            action: #selector(reloadShaderPackages),
            keyEquivalent: ""
        )
        reloadPackagesItem.target = self
        menu.addItem(reloadPackagesItem)

        if hasDiagnostics {
            let diagnosticsItem = NSMenuItem(
                title: "Shader Package Diagnostics…",
                action: #selector(showShaderPackageDiagnostics),
                keyEquivalent: ""
            )
            diagnosticsItem.target = self
            menu.addItem(diagnosticsItem)
        }

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
        
        statusItem?.menu = menu
    }
    
    @objc func openShaderLibrary() {
        NSApp.setActivationPolicy(.regular)

        if shaderLibraryWindowController == nil {
            shaderLibraryWindowController = ShaderLibraryWindowController(renderer: renderer) { [weak self] effect in
                self?.openShaderEditor(for: effect)
            }
            shaderLibraryWindowController?.onClose = { [weak self] in
                self?.shaderLibraryWindowController = nil
                NSApp.setActivationPolicy(.accessory)
            }
        }
        shaderLibraryWindowController?.showAndFocus()
    }

    private func openShaderEditor(for effect: ShaderEffectDescriptor) {
        NSApp.setActivationPolicy(.regular)
        let packageURL = effect.packageURL.standardizedFileURL
        if let controller = shaderEditorWindowControllers[packageURL] {
            controller.showAndFocus()
            return
        }

        let controller = ShaderEditorWindowController(effect: effect)
        controller.onClose = { [weak self] url in
            self?.shaderEditorWindowControllers[url.standardizedFileURL] = nil
            if self?.shaderLibraryWindowController == nil && self?.shaderEditorWindowControllers.isEmpty == true {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        shaderEditorWindowControllers[packageURL] = controller
        controller.showAndFocus()
    }

    private var hasDiagnostics: Bool {
        renderer.packageDiagnostics.contains { $0.severity == .warning || $0.severity == .error }
    }

    private func rebuildMenu() {
        setupMenuBar()
    }

    private func makeShaderMenu() -> NSMenu {
        let shaderMenu = NSMenu()
        addShaderSection(title: "Built-in", shaders: sortedShaders(source: .bundled), to: shaderMenu)
        addShaderSection(title: "Installed", shaders: sortedShaders(source: .installed), to: shaderMenu)
        return shaderMenu
    }

    private func sortedShaders(source: ShaderPackageSource) -> [ShaderEffectDescriptor] {
        let shaders = renderer.packageRegistry.effects.filter { $0.source == source }
        return shaders.sorted { lhs, rhs in
            if source == .bundled {
                let leftOrder = lhs.manifest.menuOrder ?? Int.max
                let rightOrder = rhs.manifest.menuOrder ?? Int.max
                if leftOrder != rightOrder { return leftOrder < rightOrder }
            }

            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.id < rhs.id
        }
    }

    private func addShaderSection(title: String, shaders: [ShaderEffectDescriptor], to menu: NSMenu) {
        guard !shaders.isEmpty else { return }

        if !menu.items.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for shader in shaders {
            let item = NSMenuItem(
                title: shader.displayName,
                action: #selector(changeShader(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = shader
            item.state = shader.id == renderer.currentShader?.id ? .on : .off
            menu.addItem(item)
        }
    }

    @objc func toggleVisibility() {
        isVisible.toggle()
        
        if isVisible {
            window.orderFront(nil)
            statusItem?.menu?.item(at: 0)?.title = "Hide Wallpaper"
        } else {
            window.orderOut(nil)
            statusItem?.menu?.item(at: 0)?.title = "Show Wallpaper"
        }
    }
    
    @objc func changeShader(_ sender: NSMenuItem) {
        guard let shader = sender.representedObject as? ShaderEffectDescriptor else { return }
        
        renderer.loadShader(shader, for: metalView)
        refreshShaderMenu()
    }

    @objc func openShaderPackagesFolder() {
        let folderURL = ShaderPackageRegistryBuilder.installedShaderPackagesRoot()
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folderURL)
        } catch {
            renderer.packageDiagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .error,
                    code: .packageFolderOpenFailed,
                    message: "Could not open Shader Packages folder: \(error.localizedDescription)",
                    packageID: nil,
                    packageDisplayName: "Shader Packages Folder",
                    source: .installed,
                    packageURL: folderURL
                )
            )
            rebuildMenu()
        }
    }

    @objc func newShaderPackage() {
        NSApp.setActivationPolicy(.regular)
        let alert = NSAlert()
        alert.messageText = "New Shader Package"
        alert.informativeText = "Create an editable installed source-backed Shader Package."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: 96)
        let nameField = NSTextField(string: "")
        nameField.placeholderString = "Name, e.g. Aurora Ripple"
        let idField = NSTextField(string: "")
        idField.placeholderString = "id, e.g. com.example.wallshader.aurora-ripple"
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(idField)
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let effect = try ShaderPackageAuthoring.createNewPackage(
                name: nameField.stringValue,
                id: idField.stringValue,
                existingRegistry: renderer.packageRegistry
            )
            renderer.reloadShaderPackages()
            rebuildMenu()
            openShaderEditor(for: effect)
        } catch {
            let errorAlert = NSAlert(error: error)
            errorAlert.messageText = "Could not create Shader Package"
            errorAlert.runModal()
        }
    }

    @objc func importShaderPackage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip, .folder]
        panel.allowsOtherFileTypes = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        importShaderPackageURL(url)
    }

    private func importShaderPackageURL(_ url: URL) {
        do {
            _ = try ShaderPackageInstaller.importPackage(from: url)
            renderer.reloadShaderPackages()
        } catch {
            renderer.packageDiagnostics.append(
                ShaderPackageDiagnostic(
                    severity: .error,
                    code: .importFailed,
                    message: "Import failed: \(error.localizedDescription)",
                    packageID: nil,
                    packageDisplayName: url.lastPathComponent,
                    source: .installed,
                    packageURL: url
                )
            )
        }

        rebuildMenu()
    }

    @objc func reloadShaderPackages() {
        renderer.reloadShaderPackages()
        rebuildMenu()
    }

    @objc func showShaderPackageDiagnostics() {
        let view = ShaderPackageDiagnosticsView(diagnostics: renderer.packageDiagnostics)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Shader Package Diagnostics"
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        diagnosticsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshShaderMenu() {
        statusItem?.menu?.item(at: 2)?.submenu = makeShaderMenu()
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

