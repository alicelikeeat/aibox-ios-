import XCTest
@testable import AiBoxCore

final class GIFTimingTests: XCTestCase {
    func testInvalidAndFastFrameDelays() {
        XCTAssertEqual(GIFTiming.normalizedDelay(nil), 0.1)
        XCTAssertEqual(GIFTiming.normalizedDelay(.nan), 0.1)
        XCTAssertEqual(GIFTiming.normalizedDelay(0.001), 0.1)
        XCTAssertEqual(GIFTiming.normalizedDelay(50), 10)
    }
    func testFrameBoundariesLoopAndHold() {
        XCTAssertEqual(GIFTiming.frameIndex(elapsed: 0.1, delays: [0.1, 0.2], loop: true), 1)
        XCTAssertEqual(GIFTiming.frameIndex(elapsed: 0.31, delays: [0.1, 0.2], loop: true), 0)
        XCTAssertEqual(GIFTiming.frameIndex(elapsed: 5, delays: [0.1, 0.2], loop: false), 1)
        XCTAssertEqual(GIFTiming.offset(of: 1, delays: [0.1, 0.2]), 0.1)
    }
}
