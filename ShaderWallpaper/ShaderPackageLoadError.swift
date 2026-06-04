import Foundation

enum ShaderPackageLoadError: LocalizedError {
    case unsatisfiedTextureArgument(String)

    var errorDescription: String? {
        switch self {
        case let .unsatisfiedTextureArgument(name):
            return "Fragment texture argument '\(name)' is not declared as a package texture asset or app resource."
        }
    }
}
