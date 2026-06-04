import Foundation
import Yams

struct ShaderManifest: Decodable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case manifestVersion
        case shaderInterfaceVersion
        case id
        case name
        case version
        case description
        case author
        case homepage
        case license
        case fragmentFunction
        case source
        case library
        case resources
        case assets
        case preview
        case menuOrder
        case editable
    }

    let manifestVersion: Int
    let shaderInterfaceVersion: Int
    let id: String
    let name: String
    let version: SemanticVersion
    let description: String?
    let author: String?
    let homepage: URL?
    let license: String?
    let fragmentFunction: String
    let source: String?
    let library: String?
    let resources: [String]
    let assets: ShaderManifestAssets?
    let preview: ShaderManifestPreview?
    let menuOrder: Int?
    let editable: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manifestVersion = try container.decode(Int.self, forKey: .manifestVersion)
        shaderInterfaceVersion = try container.decode(Int.self, forKey: .shaderInterfaceVersion)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(SemanticVersion.self, forKey: .version)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        homepage = try container.decodeIfPresent(URL.self, forKey: .homepage)
        license = try container.decodeIfPresent(String.self, forKey: .license)
        fragmentFunction = try container.decode(String.self, forKey: .fragmentFunction)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        library = try container.decodeIfPresent(String.self, forKey: .library)
        resources = try container.decode([String].self, forKey: .resources)
        assets = try container.decodeIfPresent(ShaderManifestAssets.self, forKey: .assets)
        preview = try container.decodeIfPresent(ShaderManifestPreview.self, forKey: .preview)
        menuOrder = try container.decodeIfPresent(Int.self, forKey: .menuOrder)
        editable = (try? container.decodeIfPresent(Bool.self, forKey: .editable)) ?? nil
    }

    var artifact: ShaderArtifact? {
        if let source, library == nil {
            return .source(source)
        }

        if let library, source == nil {
            return .library(library)
        }

        return nil
    }

    static func decodeYAML(_ yaml: String) throws -> ShaderManifest {
        try YAMLDecoder().decode(ShaderManifest.self, from: yaml)
    }
}

struct ShaderManifestAssets: Decodable, Equatable {
    let textures: [ShaderTextureAsset]?
}

struct ShaderManifestPreview: Decodable, Equatable {
    let image: String?
}

struct ShaderTextureAsset: Decodable, Equatable {
    let name: String
    let path: String
}

enum ShaderArtifact: Equatable {
    case source(String)
    case library(String)
}

struct SemanticVersion: Decodable, Equatable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?
    let buildMetadata: String?

    var description: String {
        var value = "\(major).\(minor).\(patch)"
        if let prerelease {
            value += "-\(prerelease)"
        }
        if let buildMetadata {
            value += "+\(buildMetadata)"
        }
        return value
    }

    init(_ value: String) throws {
        let pattern = #"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)

        guard let match = regex.firstMatch(in: value, range: range) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid SemVer value: \(value)")
            )
        }

        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else {
                return nil
            }
            return String(value[swiftRange])
        }

        guard
            let major = group(1).flatMap(Int.init),
            let minor = group(2).flatMap(Int.init),
            let patch = group(3).flatMap(Int.init)
        else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid SemVer numeric component: \(value)")
            )
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = group(4)
        self.buildMetadata = group(5)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(value)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case let (left?, right?):
            return comparePrerelease(left, right) < 0
        }
    }

    private static func comparePrerelease(_ lhs: String, _ rhs: String) -> Int {
        let leftParts = lhs.split(separator: ".").map(String.init)
        let rightParts = rhs.split(separator: ".").map(String.init)

        for index in 0..<max(leftParts.count, rightParts.count) {
            guard index < leftParts.count else { return -1 }
            guard index < rightParts.count else { return 1 }

            let left = leftParts[index]
            let right = rightParts[index]
            let leftNumber = Int(left)
            let rightNumber = Int(right)

            switch (leftNumber, rightNumber) {
            case let (l?, r?) where l != r:
                return l < r ? -1 : 1
            case (_?, nil):
                return -1
            case (nil, _?):
                return 1
            default:
                if left != right {
                    return left < right ? -1 : 1
                }
            }
        }

        return 0
    }
}

struct UnknownYAMLFieldReporter {
    static func unknownFields(in yaml: String, allowedTopLevelKeys: Set<String>) throws -> [String] {
        guard let mapping = try Yams.load(yaml: yaml) as? [String: Any] else {
            return []
        }

        return mapping.keys.filter { !allowedTopLevelKeys.contains($0) }.sorted()
    }

    static let manifestV1TopLevelKeys: Set<String> = [
        "manifestVersion",
        "shaderInterfaceVersion",
        "id",
        "name",
        "version",
        "description",
        "author",
        "homepage",
        "license",
        "fragmentFunction",
        "source",
        "library",
        "resources",
        "assets",
        "preview",
        "menuOrder",
        "editable"
    ]
}
