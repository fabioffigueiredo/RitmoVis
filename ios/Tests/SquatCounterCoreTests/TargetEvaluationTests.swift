import XCTest
@testable import SquatCounterCore

final class TargetEvaluationTests: XCTestCase {
    func testWrongPersonSelectionAndCreditAreNotHiddenByAbstentions() throws {
        let input = TargetEvaluationInput(clipID: "group-1", targetTrackID: "A", samples: [
            .init(timeSeconds: 0, observability: .observable, selectedTrackID: "A", creditedRepetition: false),
            .init(timeSeconds: 1, observability: .observable, selectedTrackID: nil, creditedRepetition: false),
            .init(timeSeconds: 2, observability: .observable, selectedTrackID: "B", creditedRepetition: true),
            .init(timeSeconds: 3, observability: .unobservable, selectedTrackID: nil, creditedRepetition: false),
            .init(timeSeconds: 4, observability: .absent, selectedTrackID: nil, creditedRepetition: false)
        ])
        let result = try TargetEvaluator.evaluate(input)
        XCTAssertEqual(result.observableSamples, 3)
        XCTAssertEqual(result.correctTargetSamples, 1)
        XCTAssertEqual(result.wrongPersonSamples, 1)
        XCTAssertEqual(result.wrongPersonCredits, 1)
        XCTAssertEqual(try XCTUnwrap(result.coverage), 1.0 / 3.0, accuracy: 0.0001)
    }

    func testNoObservableTargetDoesNotInventPerfectCoverage() throws {
        let input = TargetEvaluationInput(clipID: "negative", targetTrackID: "A", samples: [
            .init(timeSeconds: 0, observability: .absent, selectedTrackID: nil, creditedRepetition: false),
            .init(timeSeconds: 1, observability: .unobservable, selectedTrackID: "B", creditedRepetition: false)
        ])
        let result = try TargetEvaluator.evaluate(input)
        XCTAssertNil(result.coverage)
        XCTAssertEqual(result.unsafeSelections, 1)
        XCTAssertEqual(result.wrongPersonSamples, 1)
    }

    func testInvalidChronologyAndUnattributedCreditsAreRejected() {
        XCTAssertThrowsError(try TargetEvaluator.evaluate(.init(clipID: "x", targetTrackID: "A", samples: [
            .init(timeSeconds: 1, observability: .observable, selectedTrackID: "A", creditedRepetition: false),
            .init(timeSeconds: 1, observability: .observable, selectedTrackID: "A", creditedRepetition: false)
        ])))
        XCTAssertThrowsError(try TargetEvaluator.evaluate(.init(clipID: "x", targetTrackID: "A", samples: [
            .init(timeSeconds: 0, observability: .observable, selectedTrackID: nil, creditedRepetition: true)
        ])))
    }
}
