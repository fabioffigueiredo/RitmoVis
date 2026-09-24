import XCTest
@testable import SquatCounterCore

final class RepEvaluationTests: XCTestCase {
    func testPerfectMatchCountsOnlyCompletedCycles() throws {
        let input = RepEvaluationInput(clipID: "synthetic", toleranceSeconds: 0.25,
            annotations: [
                .init(startSeconds: 0, endSeconds: 1, completed: true),
                .init(startSeconds: 2, endSeconds: 3, completed: false),
                .init(startSeconds: 4, endSeconds: 5, completed: true)
            ], detectedAtSeconds: [5.1, 1.0])
        let result = try RepEvaluator.evaluate(input)
        XCTAssertEqual(result.truePositives, 2)
        XCTAssertEqual(result.falsePositives, 0)
        XCTAssertEqual(result.falseNegatives, 0)
        XCTAssertEqual(result.annotatedIncomplete, 1)
        XCTAssertEqual(result.precision, 1)
        XCTAssertEqual(result.recall, 1)
    }

    func testDuplicateAndIncompleteAttemptAreFalsePositives() throws {
        let input = RepEvaluationInput(clipID: "synthetic", toleranceSeconds: 0.25,
            annotations: [
                .init(startSeconds: 0, endSeconds: 1, completed: true),
                .init(startSeconds: 3, endSeconds: 4, completed: true),
                .init(startSeconds: 6, endSeconds: 7, completed: false)
            ], detectedAtSeconds: [1.1, 1.2, 6.5])
        let result = try RepEvaluator.evaluate(input)
        XCTAssertEqual(result.truePositives, 1)
        XCTAssertEqual(result.falsePositives, 2)
        XCTAssertEqual(result.falseNegatives, 1)
        XCTAssertEqual(result.falsePositivesDuringIncompleteAttempts, 1)
        XCTAssertEqual(result.missedCompletionTimes, [4])
        XCTAssertEqual(result.meanAbsoluteTimingErrorSeconds ?? -1, 0.1, accuracy: 0.0001)
    }

    func testEmptyClipDoesNotClaimPerfectPrecision() throws {
        let result = try RepEvaluator.evaluate(.init(clipID: "empty", toleranceSeconds: 0.5,
            annotations: [], detectedAtSeconds: []))
        XCTAssertNil(result.precision)
        XCTAssertNil(result.recall)
        XCTAssertNil(result.meanAbsoluteTimingErrorSeconds)
    }

    func testRejectsOverlappingOrInvalidInput() {
        let input = RepEvaluationInput(clipID: "bad", toleranceSeconds: 0.3,
            annotations: [
                .init(startSeconds: 0, endSeconds: 2, completed: true),
                .init(startSeconds: 1, endSeconds: 3, completed: true)
            ], detectedAtSeconds: [])
        XCTAssertThrowsError(try RepEvaluator.evaluate(input)) { error in
            XCTAssertEqual(error as? RepEvaluationError, .overlappingAnnotations)
        }
        XCTAssertThrowsError(try RepEvaluator.evaluate(.init(clipID: "bad", toleranceSeconds: -1,
            annotations: [], detectedAtSeconds: [])))
    }
}
