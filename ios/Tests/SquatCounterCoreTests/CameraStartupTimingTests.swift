import XCTest
@testable import SquatCounterCore

final class CameraStartupTimingTests: XCTestCase {
    func testSeparatesPermissionWaitFromStartupLatency() {
        var timing = CameraStartupTiming()
        timing.start(at: 100)
        timing.visualResponse(at: 100.05)
        timing.permissionRequested(at: 100.1)
        timing.permissionResolved(at: 105.1)
        timing.captureRunning(at: 106)
        timing.firstFrame(at: 106.4)
        timing.firstPose(at: 106.7)

        XCTAssertEqual(timing.permissionWaitMs, 5_000, accuracy: 0.01)
        XCTAssertEqual(timing.tapToVisualResponseMs, 50, accuracy: 0.01)
        XCTAssertEqual(timing.tapToCaptureMs, 6_000, accuracy: 0.01)
        XCTAssertEqual(timing.tapToFirstFrameMs, 6_400, accuracy: 0.01)
        XCTAssertEqual(timing.startupExcludingPermissionMs, 1_400, accuracy: 0.01)
        XCTAssertEqual(timing.tapToFirstPoseMs, 6_700, accuracy: 0.01)
    }

    func testDuplicateCallbacksDoNotReplaceFirstFrameOrPose() {
        var timing = CameraStartupTiming()
        timing.start(at: 10)
        timing.visualResponse(at: 10.1)
        timing.visualResponse(at: 10.3)
        timing.permissionResolved(at: 10)
        timing.firstFrame(at: 11)
        timing.firstFrame(at: 12)
        timing.firstPose(at: 11.5)
        timing.firstPose(at: 12.5)

        XCTAssertEqual(timing.tapToFirstFrameMs, 1_000, accuracy: 0.01)
        XCTAssertEqual(timing.tapToVisualResponseMs, 100, accuracy: 0.01)
        XCTAssertEqual(timing.tapToFirstPoseMs, 1_500, accuracy: 0.01)
    }
}
