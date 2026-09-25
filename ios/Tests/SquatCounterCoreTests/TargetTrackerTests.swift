import XCTest
@testable import SquatCounterCore

final class TargetTrackerTests: XCTestCase {
    private func person(_ index: Int, x: Double, y: Double = 0.5, size: Double = 0.3) -> PoseCandidate {
        PoseCandidate(index: index, centerX: x, centerY: y, width: size, height: size, confidence: 0.9)
    }

    func testNoPersonIsCountableBeforeExplicitSelection() {
        var tracker = TargetTracker()
        XCTAssertEqual(tracker.update([person(0, x: 0.25)], at: 0), .noSelection)
    }

    func testReorderingPoseListDoesNotChangeTheSelectedPerson() {
        var tracker = TargetTracker()
        XCTAssertEqual(tracker.select(person(1, x: 0.2), at: 0), .selected(index: 1))
        XCTAssertEqual(tracker.update([person(0, x: 0.8), person(1, x: 0.21)], at: 0.1), .selected(index: 1))
        XCTAssertEqual(tracker.update([person(0, x: 0.22), person(1, x: 0.78)], at: 0.2), .selected(index: 0))
    }

    func testSimilarCandidatesDuringCrossingCauseAbstention() {
        var tracker = TargetTracker()
        _ = tracker.select(person(0, x: 0.40), at: 0)
        XCTAssertEqual(tracker.update([person(0, x: 0.43), person(1, x: 0.45)], at: 0.1), .uncertain)
        XCTAssertEqual(tracker.update([person(1, x: 0.45)], at: 0.2), .reselectionRequired)
    }

    func testShortDisappearanceCanRecoverButLongDisappearanceRequiresReselection() {
        var tracker = TargetTracker()
        _ = tracker.select(person(0, x: 0.2), at: 0)
        XCTAssertEqual(tracker.update([], at: 0.1), .uncertain)
        XCTAssertEqual(tracker.update([person(2, x: 0.21)], at: 0.2), .selected(index: 2))
        XCTAssertEqual(tracker.update([], at: 1.0), .reselectionRequired)
        XCTAssertEqual(tracker.update([person(3, x: 0.21)], at: 1.1), .reselectionRequired)
        XCTAssertEqual(tracker.select(person(3, x: 0.21), at: 1.2), .selected(index: 3))
    }

    func testDistantCandidateIsNotSilentlySubstitutedForTarget() {
        var tracker = TargetTracker()
        _ = tracker.select(person(0, x: 0.2), at: 0)
        XCTAssertEqual(tracker.update([person(1, x: 0.8)], at: 0.1), .uncertain)
    }

    func testAmbiguousCrossingInvalidatesPartialRepetition() {
        var tracker = TargetTracker()
        var counter = SquatCounter()
        counter.minimumPhaseDuration = 0
        _ = tracker.select(person(0, x: 0.40), at: 0)
        for (time, angle) in [(0.0, 170.0), (0.1, 145), (0.2, 100)] {
            XCTAssertEqual(tracker.update([person(0, x: 0.40)], at: time), .selected(index: 0))
            _ = counter.consume(.init(timestamp: time, kneeAngle: angle, confidence: 0.9))
        }
        XCTAssertEqual(counter.phase, .bottom)
        XCTAssertEqual(tracker.update([person(0, x: 0.43), person(1, x: 0.45)], at: 0.3), .uncertain)
        counter.interruptTracking(at: 0.3)
        _ = counter.consume(.init(timestamp: 0.4, kneeAngle: 120, confidence: 0.9))
        _ = counter.consume(.init(timestamp: 0.5, kneeAngle: 165, confidence: 0.9))
        XCTAssertEqual(counter.repetitions, 0)
    }

    func testAppearanceSeparatesCrossingAthletesWhenGeometryCannot() {
        var tracker = TargetTracker()
        let target = PoseCandidate(index: 0, centerX: 0.40, centerY: 0.5, width: 0.3,
                                   height: 0.5, confidence: 0.9, appearance: [0.1, 0.1, 0.1, 0.2, 0.2, 0.2])
        XCTAssertEqual(tracker.select(target, at: 0), .selected(index: 0))
        let rival = PoseCandidate(index: 1, centerX: 0.41, centerY: 0.5, width: 0.3,
                                  height: 0.5, confidence: 0.9, appearance: [0.8, 0.2, 0.2, 0.8, 0.2, 0.2])
        let movedTarget = PoseCandidate(index: 2, centerX: 0.44, centerY: 0.5, width: 0.3,
                                        height: 0.5, confidence: 0.9, appearance: [0.1, 0.1, 0.1, 0.2, 0.2, 0.2])
        XCTAssertEqual(tracker.update([rival, movedTarget], at: 0.1), .selected(index: 2))
    }

    func testIdenticalAppearanceDoesNotJustifyRecoveryAfterCrossing() {
        var tracker = TargetTracker()
        let target = PoseCandidate(index: 0, centerX: 0.40, centerY: 0.5, width: 0.3,
                                   height: 0.5, confidence: 0.9, appearance: Array(repeating: 0.1, count: 6))
        _ = tracker.select(target, at: 0)
        let a = PoseCandidate(index: 1, centerX: 0.43, centerY: 0.5, width: 0.3,
                              height: 0.5, confidence: 0.9, appearance: Array(repeating: 0.1, count: 6))
        let b = PoseCandidate(index: 2, centerX: 0.45, centerY: 0.5, width: 0.3,
                              height: 0.5, confidence: 0.9, appearance: Array(repeating: 0.1, count: 6))
        XCTAssertEqual(tracker.update([a, b], at: 0.1), .uncertain)
        XCTAssertEqual(tracker.update([b], at: 0.2), .reselectionRequired)
    }

    func testAppearanceRecoversTargetAfterShortDetectionGapWithoutCreditingTheRival() {
        var tracker = TargetTracker()
        let target = PoseCandidate(index: 0, centerX: 0.3, centerY: 0.5, width: 0.3,
                                   height: 0.5, confidence: 0.9, appearance: Array(repeating: 0.2, count: 6))
        _ = tracker.select(target, at: 0)
        XCTAssertEqual(tracker.update([], at: 0.3), .uncertain)
        let rival = PoseCandidate(index: 1, centerX: 0.32, centerY: 0.5, width: 0.3,
                                  height: 0.5, confidence: 0.9, appearance: Array(repeating: 0.8, count: 6))
        XCTAssertEqual(tracker.update([rival], at: 0.5), .uncertain)
        let recovered = PoseCandidate(index: 2, centerX: 0.36, centerY: 0.5, width: 0.3,
                                      height: 0.5, confidence: 0.9, appearance: Array(repeating: 0.2, count: 6))
        XCTAssertEqual(tracker.update([rival, recovered], at: 0.6), .uncertain)
        XCTAssertEqual(tracker.update([rival, recovered], at: 0.7), .selected(index: 2))
    }
}
