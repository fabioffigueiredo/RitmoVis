import XCTest
@testable import SquatCounterCore

final class VideoSelectionEligibilityTests: XCTestCase {
    private func candidate(_ index: Int, x: Double) -> PoseCandidate {
        PoseCandidate(index: index, centerX: x, centerY: 0.5,
                      width: 0.2, height: 0.4, confidence: 0.9)
    }

    func testStaticPosterWithoutAnalyzableKneesIsNotSelectable() {
        let frames = (0..<60).map { step in
            VideoPoseFrame(timestamp: Double(step) / 30, observations: [
                VideoPoseObservation(candidate: candidate(0, x: 0.3),
                                     kneeAngle: step == 0 ? 150 : nil, confidence: 0.9),
                VideoPoseObservation(candidate: candidate(1, x: 0.7),
                                     kneeAngle: 120 + Double(step % 25), confidence: 0.9)
            ])
        }
        XCTAssertFalse(VideoSelectionEligibility.isEligible(frames, selectedFrame: 0, candidateIndex: 0))
        XCTAssertTrue(VideoSelectionEligibility.isEligible(frames, selectedFrame: 0, candidateIndex: 1))
    }

    func testPartiallyOccludedAthleteRemainsSelectable() {
        let frames = (0..<60).map { step in
            VideoPoseFrame(timestamp: Double(step) / 30, observations: step < 20 ? [
                VideoPoseObservation(candidate: candidate(step % 2, x: 0.4),
                                     kneeAngle: 130, confidence: 0.9)
            ] : [])
        }
        XCTAssertTrue(VideoSelectionEligibility.isEligible(frames, selectedFrame: 0, candidateIndex: 0))
    }
}
