import XCTest
import UIKit
import CoreImage
import AVFoundation
import SquatCounterCore
@testable import SquatCounter

final class HandGestureDetectorTests: XCTestCase {
    func testOfficialFistFixtureRunsRealVideoRecognizerButCannotOwnAnAbsentBody() throws {
        guard let url = Bundle.main.url(forResource: "fist", withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path), let cg = image.cgImage else {
            throw XCTSkip("Optional official fixture absent; see gesture QA download instructions")
        }
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, cg.width, cg.height,
            kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
            &pixel), kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixel)
        CIContext().render(CIImage(cgImage: cg), to: buffer)
        var format: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: buffer, formatDescriptionOut: &format), noErr)
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero,
                                       decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: buffer, formatDescription: try XCTUnwrap(format),
            sampleTiming: &timing, sampleBufferOut: &sample), noErr)
        let detector = try HandGestureDetector()
        let hands = try detector.recognizeHands(try XCTUnwrap(sample), timestamp: 0)
        XCTAssertEqual(hands.count, 1)
        XCTAssertEqual(hands.first?.gesture, .closedFist)
        XCTAssertGreaterThan(try XCTUnwrap(hands.first?.confidence), 0.8)
        let observations = try detector.detect(try XCTUnwrap(sample),
            batch: .init(poses: [], candidates: [], imageAspectRatio: 1), timestamp: 0.1)
        XCTAssertTrue(observations.isEmpty, "Recognizing a hand alone must not select an athlete")

        // A partial rival can retain a visible wrist without becoming selectable.
        // It must still prevent assigning this hand to the complete athlete.
        let hand = try XCTUnwrap(hands.first)
        var points = Array(repeating: PosePoint(x: 0, y: 0, visibility: 0, presence: 0), count: 33)
        points[15] = .init(x: hand.x, y: hand.y, visibility: 1, presence: 1)
        points[11] = .init(x: hand.x, y: hand.y + 0.2, visibility: 1, presence: 1)
        let full = PoseFrame(landmarks: points, confidence: 1, kneeAngle: 170, imageAspectRatio: 1)
        let partial = PoseFrame(landmarks: points, confidence: 0, kneeAngle: nil, imageAspectRatio: 1)
        let athlete = PoseCandidate(index: 0, centerX: 0.5, centerY: 0.5,
                                    width: 0.3, height: 0.8, confidence: 1)
        let ambiguous = try detector.detect(try XCTUnwrap(sample),
            batch: .init(poses: [full, partial], candidates: [athlete], imageAspectRatio: 1),
            timestamp: 0.2)
        XCTAssertTrue(ambiguous.isEmpty, "An unselectable rival wrist must still block ownership")
    }
}
