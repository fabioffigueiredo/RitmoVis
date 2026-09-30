import XCTest
@testable import SquatCounterCore

final class PushUpCounterTests: XCTestCase {
    private func sample(_ time: Double, _ angle: Double, observed: Bool = true,
                        confidence: Double = 0.9) -> PushUpSample {
        PushUpSample(timestamp: time, elbowAngle: angle, armAndTrunkObserved: observed,
                     confidence: confidence)
    }

    func testCompleteHighLowHighCycleCountsOnce() {
        var counter = PushUpCounter()
        let sequence = [sample(0, 170), sample(0.2, 130), sample(0.4, 85),
                        sample(0.6, 120), sample(0.8, 165), sample(1, 170)]
        let events = sequence.compactMap { counter.consume($0) }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(counter.repetitions, 1)
        XCTAssertEqual(events.first?.timestamp, 0.8)
    }

    func testPartialCycleAndNoiseCannotCreditRepetition() {
        var counter = PushUpCounter()
        for item in [sample(0, 170), sample(0.2, 135), sample(0.4, 120),
                     sample(0.6, 165), sample(0.8, 170)] {
            XCTAssertNil(counter.consume(item))
        }
        XCTAssertEqual(counter.repetitions, 0)
    }

    func testUnobservedTrunkInvalidatesPartialCycle() {
        var counter = PushUpCounter()
        _ = counter.consume(sample(0, 170))
        _ = counter.consume(sample(0.2, 130))
        _ = counter.consume(sample(0.4, 85))
        _ = counter.consume(sample(0.9, 120, observed: false))
        XCTAssertNil(counter.consume(sample(1.1, 165)))
        XCTAssertEqual(counter.repetitions, 0)
    }

    func testTrackingInterruptionAndOutOfOrderSamplesFailClosed() {
        var counter = PushUpCounter()
        _ = counter.consume(sample(0, 170))
        _ = counter.consume(sample(0.2, 130))
        _ = counter.consume(sample(0.4, 85))
        counter.interruptTracking(at: 0.5)
        XCTAssertNil(counter.consume(sample(0.45, 120)))
        XCTAssertNil(counter.consume(sample(0.7, 165)))
        XCTAssertEqual(counter.repetitions, 0)
    }

    func testLowConfidenceCannotAdvancePhase() {
        var counter = PushUpCounter()
        _ = counter.consume(sample(0, 170))
        _ = counter.consume(sample(0.2, 130))
        _ = counter.consume(sample(0.4, 85, confidence: 0.1))
        _ = counter.consume(sample(0.6, 120))
        XCTAssertNil(counter.consume(sample(0.8, 165)))
        XCTAssertEqual(counter.repetitions, 0)
    }

    func testNonFiniteAngleWithLostObservabilityDiscardsPartialCycle() {
        var counter = PushUpCounter()
        _ = counter.consume(sample(0, 170))
        _ = counter.consume(sample(0.2, 130))
        _ = counter.consume(sample(0.4, 85))
        _ = counter.consume(sample(0.5, .nan, observed: false))
        _ = counter.consume(sample(0.6, 120))
        XCTAssertNil(counter.consume(sample(0.8, 165)))
        XCTAssertEqual(counter.repetitions, 0)
    }
}

final class PushUpPoseGeometryTests: XCTestCase {
    private func landmarks(leftConfidence: Double = 0.9,
                           rightConfidence: Double = 0) -> [PushUpJoint] {
        var points = Array(repeating: PushUpJoint(x: 0, y: 0, confidence: 0), count: 33)
        for (index, x, y) in [(11, 0.2, 0.4), (13, 0.3, 0.5), (15, 0.4, 0.4),
                              (23, 0.1, 0.5), (27, 0.08, 0.7)] {
            points[index] = PushUpJoint(x: x, y: y, confidence: leftConfidence)
        }
        for (index, x, y) in [(12, 0.6, 0.4), (14, 0.7, 0.5), (16, 0.8, 0.4),
                              (24, 0.5, 0.5), (28, 0.48, 0.7)] {
            points[index] = PushUpJoint(x: x, y: y, confidence: rightConfidence)
        }
        return points
    }

    func testMeasuresVisibleSideElbowAngle() {
        let measurement = PushUpPoseGeometry.measure(landmarks: landmarks(), aspectRatio: 1)
        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.elbowAngle ?? 0, 90, accuracy: 0.01)
        XCTAssertEqual(measurement?.confidence ?? 0, 0.9, accuracy: 0.01)
    }

    func testCanUseOtherVisibleSide() {
        let measurement = PushUpPoseGeometry.measure(
            landmarks: landmarks(leftConfidence: 0, rightConfidence: 0.8), aspectRatio: 1)
        XCTAssertEqual(measurement?.elbowAngle ?? 0, 90, accuracy: 0.01)
        XCTAssertEqual(measurement?.confidence ?? 0, 0.8, accuracy: 0.01)
    }

    func testMissingTrunkOrInvalidGeometryAbstains() {
        var missing = landmarks()
        missing[23] = PushUpJoint(x: 0.1, y: 0.5, confidence: 0)
        XCTAssertNil(PushUpPoseGeometry.measure(landmarks: missing, aspectRatio: 1))
        XCTAssertNil(PushUpPoseGeometry.measure(landmarks: landmarks(), aspectRatio: .nan))
        XCTAssertNil(PushUpPoseGeometry.measure(landmarks: landmarks(leftConfidence: 0.4),
                                               aspectRatio: 1))
    }
}
