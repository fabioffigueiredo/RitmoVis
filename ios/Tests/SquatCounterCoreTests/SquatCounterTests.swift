import XCTest
@testable import SquatCounterCore

final class SquatCounterTests: XCTestCase {
    func testCountsOneCompleteCycleWithHysteresis() {
        var counter = SquatCounter(); counter.minimumPhaseDuration = 0
        let inputs = [(0.0, 170.0), (0.1, 145.0), (0.2, 100.0), (0.3, 118.0), (0.4, 160.0)]
        let events = inputs.compactMap { counter.consume(.init(timestamp: $0.0, kneeAngle: $0.1, confidence: 0.9)) }
        XCTAssertEqual(counter.repetitions, 1); XCTAssertEqual(events.count, 1); XCTAssertEqual(events[0].confidence, 0.9)
    }
    func testDoesNotCountPartialOrNoisyMovement() {
        var counter = SquatCounter(); counter.minimumPhaseDuration = 0
        [(0.0, 170.0), (0.1, 151.0), (0.2, 149.0), (0.3, 160.0)].forEach { _ = counter.consume(.init(timestamp: $0.0, kneeAngle: $0.1, confidence: 0.9)) }
        XCTAssertEqual(counter.repetitions, 0)
    }
    func testOcclusionMovesToTrackingLostAndRequiresFreshStandingPose() {
        var counter = SquatCounter(); counter.minimumPhaseDuration = 0
        _ = counter.consume(.init(timestamp: 0, kneeAngle: 170, confidence: 0.9))
        _ = counter.consume(.init(timestamp: 1, kneeAngle: 0, confidence: 0.1))
        XCTAssertEqual(counter.phase, .trackingLost)
        _ = counter.consume(.init(timestamp: 1.1, kneeAngle: 100, confidence: 0.9))
        XCTAssertEqual(counter.repetitions, 0)
    }
    func testCountsTwoDistinctCompleteCycles() {
        var counter = SquatCounter(); counter.minimumPhaseDuration = 0
        let angles = [170.0, 145, 100, 120, 165, 145, 100, 120, 165]
        for (index, angle) in angles.enumerated() {
            _ = counter.consume(.init(timestamp: Double(index) * 0.1, kneeAngle: angle, confidence: 0.9))
        }
        XCTAssertEqual(counter.repetitions, 2)
        XCTAssertEqual(counter.events.count, 2)
    }
    func testMinimumPhaseDurationBlocksFastJitter() {
        var counter = SquatCounter()
        for (time, angle) in [(0.0, 170.0), (0.05, 145), (0.10, 100), (0.15, 120), (0.20, 165)] {
            _ = counter.consume(.init(timestamp: time, kneeAngle: angle, confidence: 0.9))
        }
        XCTAssertEqual(counter.repetitions, 0)
        XCTAssertEqual(counter.phase, .standing)
    }
    func testRejectsOldTimestampAndResetsAfterLongGap() {
        var counter = SquatCounter(); counter.minimumPhaseDuration = 0
        _ = counter.consume(.init(timestamp: 0, kneeAngle: 170, confidence: 0.9))
        _ = counter.consume(.init(timestamp: 0.1, kneeAngle: 145, confidence: 0.9))
        _ = counter.consume(.init(timestamp: 0.05, kneeAngle: 100, confidence: 0.9))
        XCTAssertEqual(counter.phase, .descending)
        _ = counter.consume(.init(timestamp: 1.0, kneeAngle: 100, confidence: 0.9))
        XCTAssertEqual(counter.phase, .unknown)
        XCTAssertEqual(counter.repetitions, 0)
    }
    func testLowConfidenceDoesNotCompleteRep() {
        var counter = SquatCounter(); counter.minimumPhaseDuration = 0
        for (time, angle) in [(0.0, 170.0), (0.1, 145), (0.2, 100)] {
            _ = counter.consume(.init(timestamp: time, kneeAngle: angle, confidence: 0.9))
        }
        _ = counter.consume(.init(timestamp: 0.3, kneeAngle: 120, confidence: 0.1))
        _ = counter.consume(.init(timestamp: 0.4, kneeAngle: 165, confidence: 0.1))
        XCTAssertEqual(counter.repetitions, 0)
    }
}
