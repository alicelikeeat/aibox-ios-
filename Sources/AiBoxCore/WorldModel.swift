import Foundation

/// AiBox uses a two-dimensional editing grid with three-dimensional object placement.
/// This model deliberately has no dependency on a renderer or on Moonlight UI code.
public enum AiBoxWorldGeometry {
    public static let width = 256
    public static let chunkSide = 32
    public static let chunkColumns = width / chunkSide
}

public struct GridPosition: Codable, Hashable, Sendable {
    public var x: Int
    public var z: Int

    public init(x: Int, z: Int) {
        self.x = x
        self.z = z
    }

    public var isValid: Bool {
        (0..<AiBoxWorldGeometry.width).contains(x) &&
        (0..<AiBoxWorldGeometry.width).contains(z)
    }

    public var chunk: ChunkPosition? {
        guard isValid else { return nil }
        return ChunkPosition(x: x / AiBoxWorldGeometry.chunkSide,
                             z: z / AiBoxWorldGeometry.chunkSide)
    }
}

public struct ChunkPosition: Codable, Hashable, Sendable {
    public var x: Int
    public var z: Int

    public init(x: Int, z: Int) {
        self.x = x
        self.z = z
    }

    public var isValid: Bool {
        (0..<AiBoxWorldGeometry.chunkColumns).contains(x) &&
        (0..<AiBoxWorldGeometry.chunkColumns).contains(z)
    }
}

/// Positions are expressed in grid-cell units; Y is vertical elevation.
public struct WorldTransform: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var yawRadians: Double
    public var scale: Double

    public init(x: Double, y: Double = 0, z: Double,
                yawRadians: Double = 0, scale: Double = 1) {
        self.x = x
        self.y = y
        self.z = z
        self.yawRadians = yawRadians
        self.scale = scale
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && z.isFinite &&
        yawRadians.isFinite && scale.isFinite && scale > 0
    }
}

public enum MediaKind: String, Codable, Sendable {
    case image, gif, video, text, number, icon, model3D
}

public struct MediaReference: Codable, Equatable, Sendable {
    public var assetID: String
    public var kind: MediaKind

    public init(assetID: String, kind: MediaKind) {
        self.assetID = assetID
        self.kind = kind
    }
}

public struct WorldObject: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var anchor: GridPosition
    public var transform: WorldTransform
    public var media: MediaReference?

    public init(id: UUID = UUID(), anchor: GridPosition,
                transform: WorldTransform, media: MediaReference? = nil) {
        self.id = id
        self.anchor = anchor
        self.transform = transform
        self.media = media
    }

    public var isValid: Bool {
        anchor.isValid && transform.isValid &&
        (media == nil || !(media?.assetID.isEmpty ?? true))
    }
}

public struct AiBoxWorld: Codable, Sendable {
    public static let schemaVersion = 1
    public var schemaVersion: Int
    public var objects: [WorldObject]

    public init(objects: [WorldObject] = []) {
        self.schemaVersion = Self.schemaVersion
        self.objects = objects
    }

    public func validate() throws {
        guard schemaVersion == Self.schemaVersion else {
            throw WorldValidationError.unsupportedSchema
        }
        guard objects.allSatisfy(\.isValid) else {
            throw WorldValidationError.invalidObject
        }
        guard Set(objects.map(\.id)).count == objects.count else {
            throw WorldValidationError.duplicateObjectID
        }
    }
}

public enum WorldValidationError: Error, Equatable {
    case unsupportedSchema
    case invalidObject
    case duplicateObjectID
}
