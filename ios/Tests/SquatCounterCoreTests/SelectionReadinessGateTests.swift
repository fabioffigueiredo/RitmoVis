import XCTest
@testable import SquatCounterCore

final class SelectionReadinessGateTests: XCTestCase {
    func testSelectionDelaysCountingAndThenStaysReady() {
        var gate = SelectionReadinessGate(delay: 3)
        gate.arm(at: 12)
        XCTAssertEqual(gate.remaining(at: 12), 3)
        XCTAssertFalse(gate.isReady(at: 14.9))
        XCTAssertTrue(gate.isReady(at: 15))
        XCTAssertTrue(gate.isReady(at: 17))
    }

    func testReselectionRestartsDelay() {
        var gate = SelectionReadinessGate(delay: 3)
        gate.arm(at: 12)
        gate.arm(at: 14)
        XCTAssertFalse(gate.isReady(at: 15))
        XCTAssertTrue(gate.isReady(at: 17))
    }

    func testDisarmPreventsCountingAndRejectsInvalidTime() {
        var gate = SelectionReadinessGate(delay: 3)
        gate.arm(at: .nan)
        XCTAssertFalse(gate.isReady(at: 10))
        gate.arm(at: 10)
        gate.disarm()
        XCTAssertFalse(gate.isReady(at: 100))
    }
}
