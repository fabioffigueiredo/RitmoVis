import XCTest
@testable import SquatCounterCore

final class ImportedClipPolicyTests: XCTestCase {
    func testMultiplePeopleAtAnyPointRequireSelection() {
        XCTAssertTrue(ImportedClipPolicy.requiresSelection(candidateCounts: [1, 1, 2, 1]))
    }

    func testOnePersonClipKeepsProvisionalCounting() {
        XCTAssertFalse(ImportedClipPolicy.requiresSelection(candidateCounts: [0, 1, 1, 0]))
    }
}
