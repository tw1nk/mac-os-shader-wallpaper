import XCTest
@testable import ShaderWallpaper

final class ShaderPackageValidationTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    func testValidSourceManifestIsSelectable() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.valid-source
        name: Valid Source
        version: 1.2.3
        fragmentFunction: validShader
        source: shader.metal
        resources: []
        """)
        try write("// shader", to: package.appendingPathComponent("shader.metal"))

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .installed)

        XCTAssertTrue(candidate.isSelectable)
        XCTAssertEqual(candidate.manifest?.artifact, .source("shader.metal"))
        XCTAssertTrue(candidate.diagnostics.isEmpty)
    }

    func testValidLibraryManifestIsSelectable() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.valid-library
        name: Valid Library
        version: 1.0.0
        fragmentFunction: validShader
        library: shader.metallib
        resources:
          - mouse
        """)
        try write("library", to: package.appendingPathComponent("shader.metallib"))

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .bundled)

        XCTAssertTrue(candidate.isSelectable)
        XCTAssertEqual(candidate.manifest?.artifact, .library("shader.metallib"))
        XCTAssertTrue(candidate.diagnostics.isEmpty)
    }

    func testSourceAndLibraryConflictIsInvalid() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.conflict
        name: Conflict
        version: 1.0.0
        fragmentFunction: conflictShader
        source: shader.metal
        library: shader.metallib
        resources: []
        """)
        try write("// shader", to: package.appendingPathComponent("shader.metal"))
        try write("library", to: package.appendingPathComponent("shader.metallib"))

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .installed)

        XCTAssertFalse(candidate.isSelectable)
        XCTAssertTrue(candidate.diagnostics.contains { $0.code == .sourceLibraryConflict && $0.severity == .error })
    }

    func testUnsafePathsAreInvalid() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.unsafe
        name: Unsafe
        version: 1.0.0
        fragmentFunction: unsafeShader
        source: ../shader.metal
        resources: []
        """)

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .installed)

        XCTAssertFalse(candidate.isSelectable)
        XCTAssertTrue(candidate.diagnostics.contains { $0.code == .unsafePath && $0.severity == .error })
    }

    func testSymlinkPackageIsInvalid() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.symlink
        name: Symlink
        version: 1.0.0
        fragmentFunction: symlinkShader
        source: shader.metal
        resources: []
        """)
        let target = package.appendingPathComponent("real.metal")
        try write("// shader", to: target)
        try FileManager.default.createSymbolicLink(
            at: package.appendingPathComponent("shader.metal"),
            withDestinationURL: target
        )

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .installed)

        XCTAssertFalse(candidate.isSelectable)
        XCTAssertTrue(candidate.diagnostics.contains { $0.code == .symlinkNotAllowed && $0.severity == .error })
    }

    func testUnknownResourcesAndFieldsWarnButDoNotInvalidate() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.warnings
        name: Warnings
        version: 1.0.0
        fragmentFunction: warningShader
        source: shader.metal
        resources:
          - futureResource
        extraTopLevel: true
        assets:
          textures:
            - name: noiseTexture
              path: noise.png
              colorSpace: linear
        """)
        try write("// shader", to: package.appendingPathComponent("shader.metal"))
        try write("png", to: package.appendingPathComponent("noise.png"))

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .installed)

        XCTAssertTrue(candidate.isSelectable)
        XCTAssertTrue(candidate.diagnostics.contains { $0.code == .unknownResource && $0.severity == .warning })
        XCTAssertTrue(candidate.diagnostics.contains { $0.message.contains("extraTopLevel") && $0.severity == .warning })
        XCTAssertTrue(candidate.diagnostics.contains { $0.message.contains("colorSpace") && $0.severity == .warning })
    }

    func testInstalledMenuOrderWarns() throws {
        let package = try makePackage(manifest: """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: com.example.wallshader.menu-order
        name: Menu Order
        version: 1.0.0
        fragmentFunction: menuOrderShader
        source: shader.metal
        resources: []
        menuOrder: 1
        """)
        try write("// shader", to: package.appendingPathComponent("shader.metal"))

        let candidate = ShaderPackageValidator.validatePackage(at: package, source: .installed)

        XCTAssertTrue(candidate.isSelectable)
        XCTAssertTrue(candidate.diagnostics.contains { $0.code == .userMenuOrderIgnored && $0.severity == .warning })
    }

    func testDuplicateRegistryFirstWins() throws {
        let bundledRoot = try makeTemporaryDirectory()
        let installedRoot = try makeTemporaryDirectory()
        let bundledPackage = bundledRoot.appendingPathComponent("a")
        let installedPackage = installedRoot.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: bundledPackage, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installedPackage, withIntermediateDirectories: true)
        try write(validManifest(id: "com.example.wallshader.duplicate", name: "Bundled"), to: bundledPackage.appendingPathComponent("shader.yaml"))
        try write("// shader", to: bundledPackage.appendingPathComponent("shader.metal"))
        try write(validManifest(id: "com.example.wallshader.duplicate", name: "Installed"), to: installedPackage.appendingPathComponent("shader.yaml"))
        try write("// shader", to: installedPackage.appendingPathComponent("shader.metal"))

        let registry = ShaderPackageRegistryBuilder(bundledRootURL: bundledRoot, installedRootURL: installedRoot).build()

        XCTAssertEqual(registry.effects.map(\.name), ["Bundled"])
        XCTAssertTrue(registry.candidates[0].diagnostics.contains { $0.code == .duplicateIdWinner && $0.severity == .warning })
        XCTAssertTrue(registry.candidates[1].diagnostics.contains { $0.code == .duplicateIdIgnored && $0.severity == .error })
    }

    private func makePackage(manifest: String) throws -> URL {
        let directory = try makeTemporaryDirectory()
        try write(manifest, to: directory.appendingPathComponent("shader.yaml"))
        return directory
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShaderWallpaperTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func validManifest(id: String, name: String) -> String {
        """
        manifestVersion: 1
        shaderInterfaceVersion: 1
        id: \(id)
        name: \(name)
        version: 1.0.0
        fragmentFunction: duplicateShader
        source: shader.metal
        resources: []
        """
    }
}
