import Foundation
import XCTest
@testable import AiBoxCore

final class WorldModelTests: XCTestCase {
    func testChunkBoundaries() {
        XCTAssertEqual(GridPosition(x: 0, z: 0).chunk, ChunkPosition(x: 0, z: 0))
        XCTAssertEqual(GridPosition(x: 31, z: 31).chunk, ChunkPosition(x: 0, z: 0))
        XCTAssertEqual(GridPosition(x: 32, z: 32).chunk, ChunkPosition(x: 1, z: 1))
        XCTAssertEqual(GridPosition(x: 255, z: 255).chunk, ChunkPosition(x: 7, z: 7))
        XCTAssertNil(GridPosition(x: 256, z: 0).chunk)
    }

    func testWorldRoundTrip() throws {
        let object = WorldObject(
            anchor: GridPosition(x: 12, z: 14),
            transform: WorldTransform(x: 12.5, y: 2, z: 14.5),
            media: MediaReference(assetID: "asset-1", kind: .video)
        )
        let original = AiBoxWorld(objects: [object])
        let decoded = try AiBoxWorldCodec.decode(AiBoxWorldCodec.encode(original))
        XCTAssertEqual(decoded.objects, [object])
    }

    func testDuplicateObjectIDsAreRejected() {
        let object = WorldObject(
            anchor: GridPosition(x: 1, z: 1),
            transform: WorldTransform(x: 1, z: 1)
        )
        XCTAssertThrowsError(try AiBoxWorld(objects: [object, object]).validate())
    }

    func testInvalidScaleIsRejected() {
        let object = WorldObject(
            anchor: GridPosition(x: 1, z: 1),
            transform: WorldTransform(x: 1, z: 1, scale: 0)
        )
        XCTAssertThrowsError(try AiBoxWorld(objects: [object]).validate())
    }
}
