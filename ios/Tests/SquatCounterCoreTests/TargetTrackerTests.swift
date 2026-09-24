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
}
