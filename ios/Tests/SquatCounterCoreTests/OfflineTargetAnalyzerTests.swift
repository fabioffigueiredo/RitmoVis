import XCTest
@testable import SquatCounterCore

final class OfflineTargetAnalyzerTests: XCTestCase {
    func testExplicitStandingCalibrationCountsViewLimitedCycleButDefaultDoesNot() throws {
        let frames = [146.0, 122, 98, 117, 145].enumerated().map { i, angle in
            VideoPoseFrame(timestamp: Double(i) * 0.25, observations: [person(0, 0.3, angle)])
        }
        let counter = try XCTUnwrap(OfflineTargetAnalyzer.calibratedCounter(standingAngle: 146, confidence: 0.9))
        XCTAssertEqual(OfflineTargetAnalyzer.analyze(frames, selectedFrame: 0, candidateIndex: 0).last?.count, 0)
        XCTAssertEqual(OfflineTargetAnalyzer.analyze(frames, selectedFrame: 0, candidateIndex: 0, counter: counter).last?.count, 1)
    }

    func testCalibrationRejectsBentUncertainAndInvalidReference() {
        for angle in [100.0, 129, .nan, .infinity, 181] {
            XCTAssertNil(OfflineTargetAnalyzer.calibratedCounter(standingAngle: angle, confidence: 0.9))
        }
        XCTAssertNil(OfflineTargetAnalyzer.calibratedCounter(standingAngle: 146, confidence: 0.4))
        XCTAssertNil(OfflineTargetAnalyzer.calibratedCounter(standingAngle: 146, confidence: .nan))
    }

    func testCalibratedCounterDoesNotCountSmallOscillations() throws {
        let counter = try XCTUnwrap(OfflineTargetAnalyzer.calibratedCounter(standingAngle: 146, confidence: 0.9))
        let frames = [146.0, 123, 120, 128, 145].enumerated().map { i, angle in
            VideoPoseFrame(timestamp: Double(i) * 0.25, observations: [person(0, 0.3, angle)])
        }
        XCTAssertEqual(OfflineTargetAnalyzer.analyze(frames, selectedFrame: 0, candidateIndex: 0, counter: counter).last?.count, 0)
    }
    private func person(_ index: Int, _ x: Double, _ angle: Double) -> VideoPoseObservation {
        .init(candidate: .init(index: index, centerX: x, centerY: 0.5,
                               width: 0.2, height: 0.6, confidence: 0.9),
              kneeAngle: angle, confidence: 0.9)
    }

    func testCachedSelectionFollowsGeometryWhenArrayOrderChangesAndCountsOnlyAfterSelection() {
        let angles = [170.0, 145, 100, 120, 165, 170, 145, 100, 120, 165]
        let frames = angles.enumerated().map { i, angle in
            VideoPoseFrame(timestamp: Double(i) * 0.25, observations: i.isMultiple(of: 2)
                ? [person(0, 0.3, angle), person(1, 0.8, 170)]
                : [person(0, 0.8, 170), person(1, 0.3, angle)])
        }
        let results = OfflineTargetAnalyzer.analyze(frames, selectedFrame: 5, candidateIndex: 1)
        XCTAssertEqual(results.count, frames.count)
        XCTAssertTrue(results.prefix(5).allSatisfy { $0.count == 0 && $0.decision == .noSelection })
        XCTAssertEqual(results.last?.count, 1)
        XCTAssertEqual(results.compactMap(\.event).count, 1)
    }

    func testMissingSelectedCandidateCannotFallBackToSomeoneElse() {
        let frames = [VideoPoseFrame(timestamp: 0, observations: [person(0, 0.3, 170)])]
        let results = OfflineTargetAnalyzer.analyze(frames, selectedFrame: 0, candidateIndex: 9)
        XCTAssertEqual(results.first?.decision, .noSelection)
        XCTAssertEqual(results.first?.count, 0)
    }
}
