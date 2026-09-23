import XCTest
@testable import SquatCounterCore

final class CaptureRotationPolicyTests: XCTestCase {
    func testRecordingKeepsInitialCaptureAngleUntilFinished() {
        var policy = CaptureRotationPolicy()
        XCTAssertEqual(policy.angle(for: 0), 0)
        policy.startRecording(at: 90)
        XCTAssertEqual(policy.angle(for: 0), 90)
        XCTAssertEqual(policy.angle(for: 180), 90)
        policy.endRecording()
        XCTAssertEqual(policy.angle(for: 180), 180)
    }
}
