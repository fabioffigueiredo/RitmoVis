import XCTest
@testable import SquatCounterCore

final class CameraFrameHealthTests: XCTestCase {
    func testWarnsAfterThirtyConsecutiveNearBlackFrames() {
        var health = CameraFrameHealth()
        for _ in 0..<29 { health.observe(isNearBlack: true) }
        XCTAssertFalse(health.shouldWarn)
        health.observe(isNearBlack: true)
        XCTAssertTrue(health.shouldWarn)
        XCTAssertEqual(health.nearBlackFrames, 30)
    }

    func testUsefulFrameClearsStreakWithoutErasingTotal() {
        var health = CameraFrameHealth()
        for _ in 0..<30 { health.observe(isNearBlack: true) }
        health.observe(isNearBlack: false)
        XCTAssertFalse(health.shouldWarn)
        XCTAssertEqual(health.consecutiveNearBlackFrames, 0)
        XCTAssertEqual(health.nearBlackFrames, 30)
    }
}
