import XCTest
import AVFoundation
import SquatCounterCore
@testable import SquatCounter

@MainActor
final class RecordedCameraSourceTests: XCTestCase {
    #if DEBUG
    func testRawPoseCaptureKeepsRejectedPoseAndOriginalCandidateIndexWithoutAppearance() throws {
        let points = (0..<33).map { PosePoint(x: Double($0) / 33, y: 0.4,
                                             visibility: 0.8, presence: 0.9) }
        let rejected = PoseFrame(landmarks: points, confidence: 0, kneeAngle: nil, imageAspectRatio: 1)
        let accepted = PoseFrame(landmarks: points, confidence: 0.8, kneeAngle: 160, imageAspectRatio: 1)
        let candidate = PoseCandidate(index: 1, centerX: 0.5, centerY: 0.5, width: 0.3,
                                      height: 0.8, confidence: 0.8, appearance: [0.1, 0.2, 0.3])
        let frame = QARawPoseFrame.capture(pts: 2.0667, poses: [rejected, accepted], candidates: [candidate])
        XCTAssertEqual(frame.poses.map(\.index), [0, 1])
        XCTAssertEqual(frame.poses.map(\.hasTrackingCandidate), [false, true])
        XCTAssertEqual(frame.poses.map { $0.landmarks.count }, [33, 33])
        XCTAssertEqual(frame.poses.last?.kneeAngle, 160)
        let data = try JSONEncoder().encode(frame)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("appearance"))
        XCTAssertTrue(QARawPoseFrame.capture(pts: 8.0667, poses: [], candidates: []).poses.isEmpty)
    }
    #endif
    func testFrameWrapperPreservesPixelDimensionsAndMovieTime() throws {
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 48,
            kCVPixelFormatType_32BGRA, nil, &pixel), kCVReturnSuccess)
        let time = CMTime(value: 123, timescale: 30)
        let frame = try XCTUnwrap(RecordedCameraSource.sampleBuffer(pixels: try XCTUnwrap(pixel),
                                                                   presentationTime: time))
        XCTAssertEqual(CMSampleBufferGetPresentationTimeStamp(frame), time)
        let output = try XCTUnwrap(CMSampleBufferGetImageBuffer(frame))
        XCTAssertEqual(CVPixelBufferGetWidth(output), 64)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 48)
        XCTAssertTrue(output === pixel)
    }

    func testInvalidMovieTimeCannotEnterInference() throws {
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32,
            kCVPixelFormatType_32BGRA, nil, &pixel), kCVReturnSuccess)
        XCTAssertNil(RecordedCameraSource.sampleBuffer(pixels: try XCTUnwrap(pixel), presentationTime: .invalid))
        XCTAssertNil(RecordedCameraSource.sampleBuffer(pixels: try XCTUnwrap(pixel), presentationTime: .indefinite))
    }

    func testStopIsIdempotentAndSourceDoesNotRetainItself() {
        var source: RecordedCameraSource? = RecordedCameraSource(url: URL(fileURLWithPath: "/missing-qa-file.mov"),
            onFrame: { _ in XCTFail("Missing file must not emit pixels") }, onEnd: {})
        weak var retained = source
        source?.start()
        source?.start()
        source?.stop()
        source?.stop()
        XCTAssertEqual(source?.player.rate, 0)
        source = nil
        XCTAssertNil(retained)
    }
}
