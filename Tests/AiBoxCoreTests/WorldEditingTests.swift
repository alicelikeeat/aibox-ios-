import XCTest
@testable import AiBoxCore

final class WorldEditingTests: XCTestCase {
    func testPreviewDoesNotMutateAndCommitCanUndo() throws {
        var editor = try WorldEditor()
        let object = WorldObject(anchor: GridPosition(x: 4, z: 5),
                                 transform: WorldTransform(x: 4.5, z: 5.5))
        let edit = WorldEdit(operations: [.place(object)])
        let preview = try editor.preview(edit)
        XCTAssertTrue(editor.world.objects.isEmpty)
        XCTAssertEqual(preview.objects.count, 1)
        try editor.commit(edit, expectedPreview: preview)
        XCTAssertEqual(editor.world.objects.count, 1)
        XCTAssertTrue(editor.undo())
        XCTAssertTrue(editor.world.objects.isEmpty)
        XCTAssertTrue(editor.redo())
        XCTAssertEqual(editor.world.objects.count, 1)
    }

    func testBatchIsAtomicOnFailure() throws {
        let editor = try WorldEditor()
        let object = WorldObject(anchor: GridPosition(x: 0, z: 0),
                                 transform: WorldTransform(x: 0, z: 0))
        let edit = WorldEdit(operations: [.place(object), .remove(UUID())])
        XCTAssertThrowsError(try editor.preview(edit))
        XCTAssertTrue(editor.world.objects.isEmpty)
    }

    func testInvalidPlacementRejected() throws {
        let editor = try WorldEditor()
        let object = WorldObject(anchor: GridPosition(x: 256, z: 0),
                                 transform: WorldTransform(x: 256, z: 0))
        XCTAssertThrowsError(try editor.preview(WorldEdit(operations: [.place(object)])))
    }
}
