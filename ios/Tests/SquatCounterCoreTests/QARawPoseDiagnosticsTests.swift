import Foundation
import XCTest
@testable import SquatCounterCore

#if DEBUG
final class QARawPoseDiagnosticsTests: XCTestCase {
    func testSourceMustMatchActualPrivateFileNotLiveOrOtherImports() {
        let directory = URL(fileURLWithPath: "/private/app/Documents", isDirectory: true)
        let policy = QARawPoseCapturePolicy(launchArguments: [
            "--qa-raw-pose-diagnostics", "--qa-private-clip=synthetic.mp4"])
        XCTAssertTrue(policy.permits(source: directory.appendingPathComponent("synthetic.mp4"), privateDirectory: directory))
        XCTAssertFalse(policy.permits(source: directory.appendingPathComponent("other.mp4"), privateDirectory: directory))
        XCTAssertFalse(policy.permits(source: URL(fileURLWithPath: "/tmp/synthetic.mp4"), privateDirectory: directory))
        XCTAssertFalse(policy.permits(source: URL(string: "https://example.test/synthetic.mp4")!, privateDirectory: directory))
        let traversal = QARawPoseCapturePolicy(launchArguments: [
            "--qa-raw-pose-diagnostics", "--qa-private-clip=../synthetic.mp4"])
        XCTAssertFalse(traversal.permits(source: directory.appendingPathComponent("../synthetic.mp4"), privateDirectory: directory))
    }
    func testRequiresOptInAndPrivateClipAndCapturesOnlyCriticalWindows() {
        for args in [[], ["--qa-raw-pose-diagnostics"], ["--qa-private-clip=synthetic.mp4"]] {
            var policy = QARawPoseCapturePolicy(launchArguments: args)
            XCTAssertFalse(policy.accept(at: 2.0667))
        }
        var policy = QARawPoseCapturePolicy(launchArguments: [
            "--qa-raw-pose-diagnostics", "--qa-private-clip=synthetic.mp4"])
        XCTAssertFalse(policy.accept(at: 0))
        XCTAssertTrue(policy.accept(at: 2.0))
        XCTAssertTrue(policy.accept(at: 2.0667))
        XCTAssertFalse(policy.accept(at: 2.0667), "Do not capture duplicate PTS")
        XCTAssertFalse(policy.accept(at: 3))
        XCTAssertTrue(policy.accept(at: 8.0))
        XCTAssertTrue(policy.accept(at: 8.0667))
        XCTAssertFalse(policy.accept(at: 9))
        XCTAssertFalse(policy.accept(at: .nan))
    }

    func testBoundsEachWindowIndependentlySoFirstWindowCannotConsumeSecondBudget() {
        var policy = QARawPoseCapturePolicy(launchArguments: [
            "--qa-raw-pose-diagnostics", "--qa-private-clip=synthetic.mp4"])
        let first = (0..<30).filter { policy.accept(at: 2.0 + Double($0) / 1000) }
        let second = (0..<30).filter { policy.accept(at: 8.0 + Double($0) / 1000) }
        XCTAssertEqual(first.count, 16)
        XCTAssertEqual(second.count, 16)
    }

    func testSerializationKeepsAllPointsAndRejectedPosesWithoutAppearance() throws {
        let points = (0..<33).map { index in
            QARawPosePoint(index: index, x: Double(index) / 33, y: 0.4,
                           visibility: 0.8, presence: 0.9)
        }
        let captured = QARawPoseFrame(pts: 2.0667, poses: [
            QARawPose(index: 0, landmarks: points, confidence: 0.8,
                      kneeAngle: 160, hasTrackingCandidate: true),
            QARawPose(index: 1, landmarks: points, confidence: 0,
                      kneeAngle: nil, hasTrackingCandidate: false)])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(captured))
            as? [String: Any])
        let poses = try XCTUnwrap(object["poses"] as? [[String: Any]])
        XCTAssertEqual(poses.count, 2)
        XCTAssertEqual(poses[1]["index"] as? Int, 1)
        XCTAssertEqual(poses[1]["hasTrackingCandidate"] as? Bool, false)
        let landmarks = try XCTUnwrap(poses[1]["landmarks"] as? [[String: Any]])
        XCTAssertEqual(landmarks.count, 33)
        XCTAssertEqual(landmarks[32]["index"] as? Int, 32)
        XCTAssertEqual(landmarks[32]["x"] as? Double, 32.0 / 33)
        XCTAssertEqual(landmarks[0]["visibility"] as? Double, 0.8)
        XCTAssertEqual(landmarks[0]["presence"] as? Double, 0.9)
        XCTAssertEqual(Set(poses[0].keys), ["index", "landmarks", "confidence", "kneeAngle", "hasTrackingCandidate"])
    }

    func testNonfiniteMeasurementsEncodeWithoutCrashingOrInventingValues() throws {
        let captured = QARawPoseFrame(pts: 8.0667, poses: [QARawPose(index: 0,
            landmarks: [QARawPosePoint(index: 0, x: .nan, y: -0.2,
                                       visibility: .infinity, presence: 0.3)],
            confidence: .infinity, kneeAngle: .nan, hasTrackingCandidate: false)])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(captured))
            as? [String: Any])
        let pose = try XCTUnwrap((object["poses"] as? [[String: Any]])?.first)
        let point = try XCTUnwrap((pose["landmarks"] as? [[String: Any]])?.first)
        XCTAssertNil(point["x"])
        XCTAssertNil(point["visibility"])
        XCTAssertEqual(point["y"] as? Double, -0.2, "Do not clamp raw finite coordinates")
        XCTAssertEqual(point["presence"] as? Double, 0.3)
        XCTAssertNil(pose["confidence"])
        XCTAssertNil(pose["kneeAngle"])
    }

    func testMissingPosesRemainAnEmptyDiagnosticFrame() throws {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(
            QARawPoseFrame(pts: 2.0667, poses: []))) as? [String: Any])
        XCTAssertEqual(object["pts"] as? Double, 2.0667)
        XCTAssertEqual((object["poses"] as? [Any])?.count, 0)
    }
}
#endif
