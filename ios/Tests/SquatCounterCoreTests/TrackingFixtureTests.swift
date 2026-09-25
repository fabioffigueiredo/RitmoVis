import Foundation
import XCTest
@testable import SquatCounterCore

private struct TrackingFixture: Decodable {
    let schemaVersion: Int
    let fixtureID: String
    let synthetic: Bool
    let frames: [FixtureFrame]
}

private struct FixtureFrame: Decodable {
    let timeSeconds: Double
    let observations: [FixtureObservation]
    let expectedTracking: String
    let expectedIndex: Int?
    let expectedCount: Int
    let selectAfterIndex: Int?
}

private struct FixtureObservation: Decodable {
    let index: Int
    let centerX: Double
    let centerY: Double
    let width: Double
    let height: Double
    let confidence: Double
    let kneeAngle: Double

    var candidate: PoseCandidate {
        PoseCandidate(index: index, centerX: centerX, centerY: centerY,
                      width: width, height: height, confidence: confidence)
    }
}

final class TrackingFixtureTests: XCTestCase {
    func testSharedSyntheticContract() throws {
        let source = URL(fileURLWithPath: #filePath)
        let url = source.deletingLastPathComponent()
            .appendingPathComponent("../../../fixtures/tracking-v1-synthetic.json")
            .standardizedFileURL
        let fixture = try JSONDecoder().decode(TrackingFixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.schemaVersion, 1)
        XCTAssertTrue(fixture.synthetic)

        var tracker = TargetTracker()
        var counter = SquatCounter()
        counter.minimumPhaseDuration = 0
        for frame in fixture.frames {
            let decision = tracker.update(frame.observations.map(\.candidate), at: frame.timeSeconds)
            let state: String
            switch decision {
            case .noSelection: state = "noSelection"
            case .uncertain: state = "uncertain"
            case .reselectionRequired: state = "reselectionRequired"
            case .selected(let index):
                state = "selected"
                XCTAssertEqual(index, frame.expectedIndex, "\(fixture.fixtureID) at \(frame.timeSeconds)s")
                if let observation = frame.observations.first(where: { $0.index == index }) {
                    _ = counter.consume(.init(timestamp: frame.timeSeconds,
                                              kneeAngle: observation.kneeAngle,
                                              confidence: observation.confidence))
                } else {
                    XCTFail("Selected index is absent from frame")
                }
            }
            if state != "selected" { counter.interruptTracking(at: frame.timeSeconds) }
            XCTAssertEqual(state, frame.expectedTracking, "\(fixture.fixtureID) at \(frame.timeSeconds)s")
            XCTAssertEqual(counter.repetitions, frame.expectedCount, "\(fixture.fixtureID) at \(frame.timeSeconds)s")
            if let index = frame.selectAfterIndex {
                let candidate = try XCTUnwrap(frame.observations.first(where: { $0.index == index })?.candidate)
                counter.interruptTracking(at: frame.timeSeconds)
                XCTAssertEqual(tracker.select(candidate, at: frame.timeSeconds), .selected(index: index))
            }
        }
    }
}
