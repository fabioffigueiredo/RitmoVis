import XCTest
@testable import SquatCounterCore

final class HandGestureControlTests: XCTestCase {
    private func person(_ index: Int = 0, x: Double = 0.3) -> PoseCandidate {
        PoseCandidate(index: index, centerX: x, centerY: 0.5,
                      width: 0.2, height: 0.4, confidence: 0.9)
    }

    private func observation(_ candidate: PoseCandidate, gesture: HandGesture = .openPalm,
                             confidence: Double = 0.9, above: Bool = true) -> GestureObservation {
        GestureObservation(gesture: gesture, confidence: confidence,
                           candidate: candidate, isAboveShoulder: above)
    }

    func testRaisedOpenPalmSelectsOnlyAfterTwoContinuousSecondsAndOnlyOnce() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0..<16 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
        XCTAssertEqual(controller.consume([observation(athlete)], candidates: [athlete],
                                          tracking: .noSelection, selectedCandidate: nil, at: 2),
                       .select(candidateIndex: 0))
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                        tracking: .noSelection, selectedCandidate: nil, at: 2.125))
    }

    func testAnotherPersonCannotInheritTheInitialGestureHold() {
        var controller = HandGestureControl()
        let first = person(0, x: 0.3)
        let rival = person(0, x: 0.8)
        for tick in 0..<16 {
            let athlete = tick < 8 ? first : rival
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
        XCTAssertNil(controller.consume([observation(rival)], candidates: [rival],
                                        tracking: .noSelection, selectedCandidate: nil, at: 2))
    }

    func testObservationGapRestartsTheTwoSecondHold() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...8 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
        for tick in 0..<16 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: 1.5 + Double(tick) / 8))
        }
        XCTAssertEqual(controller.consume([observation(athlete)], candidates: [athlete],
                                          tracking: .noSelection, selectedCandidate: nil, at: 3.5),
                       .select(candidateIndex: 0))
    }

    func testInvalidOrMissingHandEvidenceCancelsPartialHold() {
        let athlete = person()
        let interruptions: [[GestureObservation]] = [
            [], [observation(athlete, gesture: .unknown)],
            [observation(athlete, above: false)], [observation(athlete, confidence: 0.79)],
            [observation(athlete, confidence: .nan)],
            [observation(athlete, confidence: .infinity)],
            [observation(athlete, confidence: 1.1)]
        ]
        for interruption in interruptions {
            var controller = HandGestureControl()
            for tick in 0..<8 {
                XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                                tracking: .noSelection, selectedCandidate: nil,
                                                at: Double(tick) / 8))
            }
            XCTAssertNil(controller.consume(interruption, candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil, at: 1))
            for tick in 9...16 {
                XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                                tracking: .noSelection, selectedCandidate: nil,
                                                at: Double(tick) / 8))
            }
        }
    }

    func testTwoGesturePerformersCancelSelectionButTwoHandsOfOnePersonDoNot() {
        let athlete = person()
        let rival = person(1, x: 0.8)
        var ambiguous = HandGestureControl()
        var bothHands = HandGestureControl()
        for tick in 0...16 {
            let time = Double(tick) / 8
            XCTAssertNil(ambiguous.consume([observation(athlete), observation(rival)],
                                            candidates: [athlete, rival], tracking: .noSelection,
                                            selectedCandidate: nil, at: time))
            let command = bothHands.consume([observation(athlete), observation(athlete)],
                                            candidates: [athlete, rival], tracking: .noSelection,
                                            selectedCandidate: nil, at: time)
            XCTAssertEqual(command, tick == 16 ? .select(candidateIndex: 0) : nil)
        }
    }

    func testSelectedAthletesRaisedFistStopsOnlyAfterTwoSecondsAndOnlyOnce() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0..<16 {
            XCTAssertNil(controller.consume([observation(athlete, gesture: .closedFist)],
                                            candidates: [athlete], tracking: .selected(index: 0),
                                            selectedCandidate: athlete, at: Double(tick) / 8))
        }
        XCTAssertEqual(controller.consume([observation(athlete, gesture: .closedFist)],
                                          candidates: [athlete], tracking: .selected(index: 0),
                                          selectedCandidate: athlete, at: 2), .stop)
        XCTAssertNil(controller.consume([observation(athlete, gesture: .closedFist)],
                                        candidates: [athlete], tracking: .selected(index: 0),
                                        selectedCandidate: athlete, at: 2.125))
    }

    func testManualSelectionCancelsCountdownAndPreventsAutomaticReselectionAfterLoss() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...8 {
            _ = controller.consume([observation(athlete)], candidates: [athlete],
                                   tracking: .noSelection, selectedCandidate: nil,
                                   at: Double(tick) / 8)
        }
        XCTAssertEqual(controller.holdProgress, 0.5)
        controller.markSelected()
        XCTAssertEqual(controller.holdProgress, 0)
        for tick in 9...32 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .reselectionRequired, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
        XCTAssertEqual(controller.holdProgress, 0)
    }

    func testInitialSelectionExpiresThirtySecondsAfterFirstFrameEvenDuringHold() {
        var controller = HandGestureControl()
        let athlete = person()
        _ = controller.consume([], candidates: [], tracking: .noSelection,
                               selectedCandidate: nil, at: 0)
        XCTAssertFalse(controller.isInitialSelectionExpired)
        for tick in 0...18 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: 29 + Double(tick) / 8))
        }
        XCTAssertTrue(controller.isInitialSelectionExpired)
        XCTAssertEqual(controller.holdProgress, 0)
    }

    func testHandWithoutExactCurrentPoseCannotStartOrContributeToHold() {
        var controller = HandGestureControl()
        let athlete = person()
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [],
                                        tracking: .noSelection, selectedCandidate: nil, at: 0))
        for tick in 1...16 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
        XCTAssertEqual(controller.consume([observation(athlete)], candidates: [athlete],
                                          tracking: .noSelection, selectedCandidate: nil, at: 2.125),
                       .select(candidateIndex: 0))
    }

    func testInvalidPoseScoresCannotProduceCommands() {
        for score in [Double.nan, .infinity, -0.1, 1.1] {
            var controller = HandGestureControl()
            let invalid = PoseCandidate(index: 0, centerX: 0.3, centerY: 0.5,
                                        width: 0.2, height: 0.4, confidence: score)
            for tick in 0...16 {
                XCTAssertNil(controller.consume([observation(invalid)], candidates: [invalid],
                                                tracking: .noSelection, selectedCandidate: nil,
                                                at: Double(tick) / 8))
            }
        }
    }

    func testKnownNearbyRivalCannotInheritHoldAfterFirstFrameTargetLoss() {
        var controller = HandGestureControl()
        let athlete = person(0, x: 0.3)
        let rival = person(1, x: 0.4)
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete, rival],
                                        tracking: .noSelection, selectedCandidate: nil, at: 0))
        for tick in 1...16 {
            let movingRival = person(tick % 2, x: 0.38)
            XCTAssertNil(controller.consume([observation(movingRival)], candidates: [movingRival],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
    }

    func testFrameIndicesCanReorderThroughoutSelectionAndStopHold() {
        var controller = HandGestureControl()
        for tick in 0...16 {
            let athlete = person(tick % 2, x: 0.3)
            let rival = person(1 - tick % 2, x: 0.8)
            let command = controller.consume([observation(athlete)], candidates: [rival, athlete],
                                             tracking: .noSelection, selectedCandidate: nil,
                                             at: Double(tick) / 8)
            XCTAssertEqual(command, tick == 16 ? .select(candidateIndex: 0) : nil)
        }
        for tick in 17...33 {
            let athlete = person(tick % 2, x: 0.3)
            let rival = person(1 - tick % 2, x: 0.8)
            let command = controller.consume([observation(athlete, gesture: .closedFist)],
                                             candidates: [rival, athlete],
                                             tracking: .selected(index: athlete.index),
                                             selectedCandidate: athlete, at: Double(tick) / 8)
            XCTAssertEqual(command, tick == 33 ? .stop : nil)
        }
    }

    func testFistBeforeSelectionAndAnotherPersonsFistAfterSelectionCannotStop() {
        var unselected = HandGestureControl()
        var selected = HandGestureControl()
        let athlete = person()
        let impostor = person(0, x: 0.8)
        for tick in 0...16 {
            let time = Double(tick) / 8
            XCTAssertNil(unselected.consume([observation(athlete, gesture: .closedFist)],
                                              candidates: [athlete], tracking: .noSelection,
                                              selectedCandidate: nil, at: time))
            XCTAssertNil(selected.consume([observation(impostor, gesture: .closedFist)],
                                            candidates: [impostor], tracking: .selected(index: 0),
                                            selectedCandidate: athlete, at: time))
        }
    }

    func testAutomaticSelectionNeverRepeatsAfterTargetLossEvenIfCallerReturnsNoSelection() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...16 {
            _ = controller.consume([observation(athlete)], candidates: [athlete],
                                   tracking: .noSelection, selectedCandidate: nil,
                                   at: Double(tick) / 8)
        }
        let rival = person(0, x: 0.8)
        for tick in 17...40 {
            XCTAssertNil(controller.consume([observation(rival)], candidates: [rival],
                                            tracking: tick == 17 ? .reselectionRequired : .noSelection,
                                            selectedCandidate: nil, at: Double(tick) / 8))
        }
    }

    func testUncertainTrackingCancelsPartialStopHold() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...16 {
            XCTAssertNil(controller.consume([observation(athlete, gesture: .closedFist)],
                                            candidates: [athlete],
                                            tracking: tick == 8 ? .uncertain : .selected(index: 0),
                                            selectedCandidate: athlete, at: Double(tick) / 8))
        }
    }

    func testAmbiguousCrossingCancelsPartialInitialHold() {
        var controller = HandGestureControl()
        for tick in 0...16 {
            let athlete = person(0, x: 0.4)
            let rival = person(1, x: tick == 8 ? 0.41 : 0.8)
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete, rival],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
    }

    func testInvalidAndNonIncreasingTimestampsCancelPartialHold() {
        let athlete = person()
        for invalidTime in [Double.nan, .infinity, -.infinity, 0.5, 0.875] {
            var controller = HandGestureControl()
            for tick in 0..<8 {
                _ = controller.consume([observation(athlete)], candidates: [athlete],
                                       tracking: .noSelection, selectedCandidate: nil,
                                       at: Double(tick) / 8)
            }
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: invalidTime))
            XCTAssertEqual(controller.holdProgress, 0)
            for tick in 9...16 {
                XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                                tracking: .noSelection, selectedCandidate: nil,
                                                at: Double(tick) / 8))
            }
        }
    }

    func testQuarterSecondGapsAndThresholdConfidenceAreAccepted() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...8 {
            let command = controller.consume([observation(athlete, confidence: 0.8)],
                                             candidates: [athlete], tracking: .noSelection,
                                             selectedCandidate: nil, at: Double(tick) / 4)
            XCTAssertEqual(command, tick == 8 ? .select(candidateIndex: 0) : nil)
        }
    }

    func testShortRaisedHandsDuringJumpingJacksNeverTriggerSelection() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...40 {
            XCTAssertNil(controller.consume([observation(athlete, above: tick % 4 < 2)],
                                            candidates: [athlete], tracking: .noSelection,
                                            selectedCandidate: nil, at: Double(tick) / 8))
        }
    }

    func testManualSelectionAfterInitialWindowCanStillStop() {
        var controller = HandGestureControl()
        let athlete = person()
        _ = controller.consume([], candidates: [], tracking: .noSelection,
                               selectedCandidate: nil, at: 0)
        _ = controller.consume([], candidates: [], tracking: .noSelection,
                               selectedCandidate: nil, at: 30)
        controller.markSelected()
        for tick in 0...16 {
            let command = controller.consume([observation(athlete, gesture: .closedFist)],
                                             candidates: [athlete], tracking: .selected(index: 0),
                                             selectedCandidate: athlete, at: 31 + Double(tick) / 8)
            XCTAssertEqual(command, tick == 16 ? .stop : nil)
        }
    }

    func testPoseLossBetweenHandTicksCancelsPendingStopWithoutRearmingSelection() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0..<16 {
            XCTAssertNil(controller.consume([observation(athlete, gesture: .closedFist)],
                                            candidates: [athlete], tracking: .selected(index: 0),
                                            selectedCandidate: athlete, at: Double(tick) / 8))
        }
        XCTAssertEqual(controller.holdProgress, 0.9375)
        controller.invalidatePendingHold()
        XCTAssertEqual(controller.holdProgress, 0)
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                        tracking: .noSelection, selectedCandidate: nil, at: 2))
        for tick in 17...33 {
            let command = controller.consume([observation(athlete, gesture: .closedFist)],
                                             candidates: [athlete], tracking: .selected(index: 0),
                                             selectedCandidate: athlete, at: Double(tick) / 8)
            XCTAssertEqual(command, tick == 33 ? .stop : nil)
        }
    }

    func testPoseLossBetweenHandTicksCancelsInitialHoldAndPreservesArmingClock() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0..<16 {
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil,
                                            at: Double(tick) / 8))
        }
        controller.invalidatePendingHold()
        XCTAssertEqual(controller.holdProgress, 0)
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                        tracking: .noSelection, selectedCandidate: nil, at: 2))
        controller.invalidatePendingHold()
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                        tracking: .noSelection, selectedCandidate: nil, at: 30))
        XCTAssertTrue(controller.isInitialSelectionExpired)
    }

    func testPendingHoldInvalidationPreservesTimestampAndAlreadyEmittedStop() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...16 {
            _ = controller.consume([observation(athlete, gesture: .closedFist)],
                                   candidates: [athlete], tracking: .selected(index: 0),
                                   selectedCandidate: athlete, at: Double(tick) / 8)
        }
        controller.invalidatePendingHold()
        for tick in 17...40 {
            XCTAssertNil(controller.consume([observation(athlete, gesture: .closedFist)],
                                            candidates: [athlete], tracking: .selected(index: 0),
                                            selectedCandidate: athlete, at: Double(tick) / 8))
        }

        var initial = HandGestureControl()
        _ = initial.consume([observation(athlete)], candidates: [athlete], tracking: .noSelection,
                            selectedCandidate: nil, at: 1)
        initial.invalidatePendingHold()
        XCTAssertNil(initial.consume([observation(athlete)], candidates: [athlete],
                                     tracking: .noSelection, selectedCandidate: nil, at: 0.5))
        XCTAssertEqual(initial.holdProgress, 0)
        for tick in 5...24 {
            XCTAssertNil(initial.consume([observation(athlete)], candidates: [athlete],
                                         tracking: .noSelection, selectedCandidate: nil,
                                         at: Double(tick) / 8))
        }
    }

    func testRawPoseFrameCancelsInitialHoldWhenPerformerVanishesButRivalRemains() {
        var controller = HandGestureControl()
        let athlete = person()
        let rival = person(1, x: 0.8)
        for tick in 0..<16 {
            _ = controller.consume([observation(athlete)], candidates: [athlete, rival],
                                   tracking: .noSelection, selectedCandidate: nil,
                                   at: Double(tick) / 8)
        }
        controller.observePoseFrame(candidates: [rival], tracking: .noSelection, at: 1.9375)
        XCTAssertEqual(controller.holdProgress, 0)
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete, rival],
                                        tracking: .noSelection, selectedCandidate: nil, at: 2))
    }

    func testRawPoseAmbiguityCancelsBothSelectionAndStopBetweenHandTicks() {
        let athlete = person()
        let rival = person(1, x: 0.8)
        for selected in [false, true] {
            var controller = HandGestureControl()
            let tracking: TrackingDecision = selected ? .selected(index: 0) : .noSelection
            let gesture: HandGesture = selected ? .closedFist : .openPalm
            for tick in 0..<16 {
                _ = controller.consume([observation(athlete, gesture: gesture)],
                                       candidates: [athlete, rival], tracking: tracking,
                                       selectedCandidate: selected ? athlete : nil,
                                       at: Double(tick) / 8)
            }
            controller.observePoseFrame(candidates: [athlete, person(1, x: 0.31)],
                                        tracking: tracking, at: 1.9375)
            XCTAssertEqual(controller.holdProgress, 0)
            XCTAssertNil(controller.consume([observation(athlete, gesture: gesture)],
                                            candidates: [athlete, rival], tracking: tracking,
                                            selectedCandidate: selected ? athlete : nil, at: 2))
        }
    }

    func testRawPoseTrackingLossCancelsStopAndNeverRearmsAutomaticSelection() {
        let athlete = person()
        for loss: TrackingDecision in [.uncertain, .reselectionRequired, .noSelection] {
            var controller = HandGestureControl()
            for tick in 0..<16 {
                _ = controller.consume([observation(athlete, gesture: .closedFist)],
                                       candidates: [athlete], tracking: .selected(index: 0),
                                       selectedCandidate: athlete, at: Double(tick) / 8)
            }
            controller.observePoseFrame(candidates: [athlete], tracking: loss, at: 1.9375)
            XCTAssertEqual(controller.holdProgress, 0)
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil, at: 2))
        }
    }

    func testHealthyRawPoseFramesPreserveHoldAcrossIndexReorderingWithoutAdvancingProgress() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0..<16 {
            _ = controller.consume([observation(athlete)], candidates: [athlete],
                                   tracking: .noSelection, selectedCandidate: nil,
                                   at: Double(tick) / 8)
        }
        controller.observePoseFrame(candidates: [person(2)], tracking: .noSelection, at: 1.9375)
        XCTAssertEqual(controller.holdProgress, 0.9375)
        XCTAssertEqual(controller.consume([observation(athlete)], candidates: [athlete],
                                          tracking: .noSelection, selectedCandidate: nil, at: 2),
                       .select(candidateIndex: 0))
    }

    func testPoseOnlyFramesCannotExtendMissingHandEvidencePastMaximumGap() {
        var controller = HandGestureControl()
        let athlete = person()
        for tick in 0...8 {
            _ = controller.consume([observation(athlete)], candidates: [athlete],
                                   tracking: .noSelection, selectedCandidate: nil,
                                   at: Double(tick) / 8)
        }
        for tick in 9...15 {
            controller.observePoseFrame(candidates: [athlete], tracking: .noSelection,
                                        at: Double(tick) / 8)
        }
        XCTAssertEqual(controller.holdProgress, 0)
        XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                        tracking: .noSelection, selectedCandidate: nil, at: 2))
    }

    func testInvalidRawPoseTimestampsAndSelectedOwnerMismatchCancelHold() {
        let athlete = person()
        for invalidTime in [Double.nan, .infinity, 0.5] {
            var controller = HandGestureControl()
            for tick in 0..<16 {
                _ = controller.consume([observation(athlete)], candidates: [athlete],
                                       tracking: .noSelection, selectedCandidate: nil,
                                       at: Double(tick) / 8)
            }
            controller.observePoseFrame(candidates: [athlete], tracking: .noSelection, at: invalidTime)
            XCTAssertEqual(controller.holdProgress, 0)
            XCTAssertNil(controller.consume([observation(athlete)], candidates: [athlete],
                                            tracking: .noSelection, selectedCandidate: nil, at: 2))
        }
        var stop = HandGestureControl()
        for tick in 0..<16 {
            _ = stop.consume([observation(athlete, gesture: .closedFist)], candidates: [athlete],
                             tracking: .selected(index: 0), selectedCandidate: athlete,
                             at: Double(tick) / 8)
        }
        stop.observePoseFrame(candidates: [athlete, person(1, x: 0.8)],
                              tracking: .selected(index: 1), at: 1.9375)
        XCTAssertEqual(stop.holdProgress, 0)
        XCTAssertNil(stop.consume([observation(athlete, gesture: .closedFist)],
                                  candidates: [athlete], tracking: .selected(index: 0),
                                  selectedCandidate: athlete, at: 2))
    }
}
