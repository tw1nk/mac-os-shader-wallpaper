import Foundation

extension ShaderPackageRegistryBuilder {
    static func defaultBuilder(bundle: Bundle = .main) -> ShaderPackageRegistryBuilder {
        ShaderPackageRegistryBuilder(
            bundledRootURL: bundledShaderPackagesRoot(bundle: bundle),
            installedRootURL: installedShaderPackagesRoot()
        )
    }

    static func bundledShaderPackagesRoot(bundle: Bundle = .main) -> URL {
        bundle.resourceURL?.appendingPathComponent("Shaders", isDirectory: true)
            ?? URL(fileURLWithPath: "/__missing_bundled_shader_packages__")
    }

    static func installedShaderPackagesRoot() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupport
            .appendingPathComponent("Shader Wallpaper", isDirectory: true)
            .appendingPathComponent("Shaders", isDirectory: true)
    }
}
