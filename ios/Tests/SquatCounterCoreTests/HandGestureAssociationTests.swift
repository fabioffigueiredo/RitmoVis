import XCTest
@testable import SquatCounterCore

final class HandGestureAssociationTests: XCTestCase {
    private func wrist(_ index: Int, x: Double = 0.5, confidence: Double = 0.9) -> GestureBodyWrist {
        .init(candidateIndex: index, x: x, y: 0.2, shoulderY: 0.4,
              confidence: confidence, bodyUsable: true)
    }

    func testAssociatesOnlyUniqueVisibleRaisedWrist() {
        XCTAssertEqual(HandGestureAssociation.candidateIndex(handX: 0.51, handY: 0.2,
            bodyWrists: [wrist(2)], aspectRatio: 1), 2)
    }

    func testOverlappingPeopleAreNotResolvedByArrayOrder() {
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2), wrist(7, x: 0.52)], aspectRatio: 1))
    }

    func testTwoWristsOfSamePersonDoNotCreateAnotherIdentity() {
        XCTAssertEqual(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2), wrist(2, x: 0.52)], aspectRatio: 1), 2)
    }

    func testCroppedRivalStillMakesWristOwnershipAmbiguous() {
        let rival = GestureBodyWrist(candidateIndex: 7, x: 0.51, y: 0.2,
            shoulderY: 0.4, confidence: 0.9, bodyUsable: false)
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2), rival], aspectRatio: 1))
    }

    func testRivalsShoulderHeightCannotRemoveAnOwnershipConflict() {
        let rival = GestureBodyWrist(candidateIndex: 7, x: 0.51, y: 0.2,
            shoulderY: 0.1, confidence: 0.9, bodyUsable: true)
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2), rival], aspectRatio: 1))
    }

    func testInvisibleShoulderDoesNotHideAConfidentRivalWrist() {
        let rival = GestureBodyWrist(candidateIndex: 7, x: 0.51, y: 0.2,
            shoulderY: .nan, confidence: 0.9, bodyUsable: true)
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2), rival], aspectRatio: 1))
    }

    func testRejectsUnusableBodyLowConfidenceAndLoweredHand() {
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2, confidence: 0.3)], aspectRatio: 1))
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [.init(candidateIndex: 2, x: 0.5, y: 0.2, shoulderY: 0.4,
                              confidence: 0.9, bodyUsable: false)], aspectRatio: 1))
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.42,
            bodyWrists: [.init(candidateIndex: 2, x: 0.5, y: 0.42, shoulderY: 0.4,
                              confidence: 0.9, bodyUsable: true)], aspectRatio: 1))
    }

    func testRejectsRemoteWristAndNonfiniteCoordinates() {
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.8, handY: 0.2,
            bodyWrists: [wrist(2)], aspectRatio: 1))
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: .nan, handY: 0.2,
            bodyWrists: [wrist(2)], aspectRatio: 1))
        XCTAssertNil(HandGestureAssociation.candidateIndex(handX: 0.5, handY: 0.2,
            bodyWrists: [wrist(2)], aspectRatio: .infinity))
    }
}
