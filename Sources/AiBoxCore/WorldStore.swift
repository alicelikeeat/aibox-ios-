import Foundation

/// Standalone JSON persistence. Import of Moonlight's schema 8 is intentionally
/// deferred to a separate, versioned migration adapter.
public enum AiBoxWorldCodec {
    public static let maximumBytes = 16 * 1024 * 1024

    public static func encode(_ world: AiBoxWorld) throws -> Data {
        try world.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(world)
        guard data.count <= maximumBytes else { throw WorldStoreError.oversized }
        return data
    }

    public static func decode(_ data: Data) throws -> AiBoxWorld {
        guard data.count <= maximumBytes else { throw WorldStoreError.oversized }
        let world = try JSONDecoder().decode(AiBoxWorld.self, from: data)
        try world.validate()
        return world
    }
}

public enum WorldStoreError: Error, Equatable {
    case oversized
}

public actor AiBoxWorldStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> AiBoxWorld? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try AiBoxWorldCodec.decode(Data(contentsOf: fileURL))
    }

    public func save(_ world: AiBoxWorld) throws {
        let data = try AiBoxWorldCodec.encode(world)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
