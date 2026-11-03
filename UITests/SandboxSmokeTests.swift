import XCTest

final class SandboxSmokeTests: XCTestCase {
    func testPreviewCancelConfirmUndoAndSave() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-world", UUID().uuidString]
        app.launch()
        let preview = app.buttons["预览编辑"]
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        XCTAssertTrue(preview.isEnabled)
        XCTAssertEqual(app.staticTexts["worldCount"].label, "对象 0")
        preview.tap()
        XCTAssertEqual(app.staticTexts["worldCount"].label, "对象 0")
        XCTAssertTrue(app.buttons["确认编辑"].waitForExistence(timeout: 5))
        app.buttons["取消预览"].tap()
        XCTAssertTrue(preview.exists)
        preview.tap()
        app.buttons["确认编辑"].tap()
        XCTAssertEqual(app.staticTexts["worldCount"].label, "对象 1")
        app.buttons["撤销"].tap()
        XCTAssertEqual(app.staticTexts["worldCount"].label, "对象 0")
        app.buttons["重做"].tap()
        XCTAssertEqual(app.staticTexts["worldCount"].label, "对象 1")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["已保存"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        XCTAssertTrue(preview.isEnabled)
        XCTAssertEqual(app.staticTexts["worldCount"].label, "对象 1")
    }
}
