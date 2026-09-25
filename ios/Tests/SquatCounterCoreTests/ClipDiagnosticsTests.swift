import XCTest
@testable import SquatCounterCore

final class ClipDiagnosticsTests: XCTestCase {
    func testDetectorAbsenceIsDistinctFromTrackerUncertaintyAndMissingAngle() {
        let summary = ClipDiagnostics.summarize([
            .init(candidateCount: 0, decision: .noSelection, hasKneeAngle: false),
            .init(candidateCount: 2, decision: .noSelection, hasKneeAngle: false),
            .init(candidateCount: 2, decision: .selected(index: 1), hasKneeAngle: false),
            .init(candidateCount: 2, decision: .uncertain, hasKneeAngle: false),
            .init(candidateCount: 1, decision: .reselectionRequired, hasKneeAngle: false)
        ])
        XCTAssertEqual(summary.noDetectedPeople, 1)
        XCTAssertEqual(summary.awaitingSelection, 2)
        XCTAssertEqual(summary.identityUncertain, 1)
        XCTAssertEqual(summary.reselectionRequired, 1)
        XCTAssertEqual(summary.selectedWithoutUsableAngle, 1)
    }
}
