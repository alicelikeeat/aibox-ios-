import Foundation
import XCTest
@testable import AiBoxCore

final class NavigationAndStoreTests: XCTestCase {
    func testSweptMovementCannotTunnelAndSlidesAlongWall() {
        let wall = WorldObject(anchor: .init(x: 2, z: 2), transform: .init(x: 2.5, z: 2.5))
        let world = AiBoxWorld(objects: [wall])
        let stopped = WorldNavigation.move(x: 1, z: 2.5, dx: 4, dz: 0, world: world)
        XCTAssertLessThanOrEqual(stopped.x, 1.75 + 0.000001)
        let slide = WorldNavigation.move(x: 1.7, z: 2.2, dx: 1, dz: 0.5, world: world)
        XCTAssertLessThanOrEqual(slide.x, 1.75 + 0.000001)
        XCTAssertGreaterThan(slide.z, 2.6)
    }

    func testWorldBoundsAndNonfiniteInput() {
        let bounded = WorldNavigation.move(x: 0.3, z: 0.3, dx: -1, dz: -1, world: .init())
        XCTAssertGreaterThanOrEqual(bounded.x, 0.25)
        XCTAssertGreaterThanOrEqual(bounded.z, 0.25)
        XCTAssertEqual(WorldNavigation.clamp(.infinity), 0)
    }

    func testStoreRoundTripAndCorruptionIsNotSilentlyReset() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("world.json")
        let store = AiBoxWorldStore(fileURL: url)
        let missing = try await store.load()
        XCTAssertNil(missing)
        let object = WorldObject(anchor: .init(x: 1, z: 2), transform: .init(x: 1.5, z: 2.5))
        try await store.save(AiBoxWorld(objects: [object]))
        let loaded = try await store.load()
        XCTAssertEqual(loaded?.objects, [object])
        try Data("invalid".utf8).write(to: url)
        do { _ = try await store.load(); XCTFail("Corruption must surface") } catch { }
        try Data(repeating: 32, count: AiBoxWorldCodec.maximumBytes + 1).write(to: url)
        do {
            _ = try await store.load()
            XCTFail("Oversized files must be rejected")
        } catch { XCTAssertEqual(error as? WorldStoreError, .oversized) }
    }

    func testStalePreviewAndNewEditClearsRedo() throws {
        var editor = try WorldEditor()
        let first = WorldObject(anchor: .init(x: 1, z: 1), transform: .init(x: 1.5, z: 1.5))
        let edit = WorldEdit(operations: [.place(first)])
        let preview = try editor.preview(edit)
        let other = WorldEdit(operations: [.place(.init(anchor: .init(x: 2, z: 2), transform: .init(x: 2.5, z: 2.5)))])
        try editor.commit(other, expectedPreview: editor.preview(other))
        XCTAssertThrowsError(try editor.commit(edit, expectedPreview: preview))
        XCTAssertTrue(editor.undo())
        try editor.commit(edit, expectedPreview: editor.preview(edit))
        XCTAssertFalse(editor.redo())
    }
}
