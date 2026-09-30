import XCTest
@testable import SquatCounter

@MainActor
final class LiveInferenceResultDeliveryTests: XCTestCase {
    func testEOFReportIncludesDelayedTerminalRepetitionAndMetrics() async {
        let delivery = LiveInferenceResultDelivery()
        let inferenceQueue = DispatchQueue(label: "test.terminal.inference")
        let terminalStarted = expectation(description: "terminal update awaits delivery")
        let prematureReport = expectation(description: "report must wait for terminal result")
        prematureReport.isInverted = true
        let reportSaved = expectation(description: "EOF report saved")
        let release = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let state = TerminalWorkoutState()

        inferenceQueue.async {
            delivery.deliver {
                terminalStarted.fulfill()
                for await _ in release.stream { break }
                state.repetitions = 5
                state.metrics.processedFrames = 12
            }
        }
        await fulfillment(of: [terminalStarted], timeout: 2)

        delivery.afterDraining(on: inferenceQueue) {
            if state.isHoldingTerminalResult { prematureReport.fulfill() }
            state.reportRepetitions = state.repetitions
            state.reportProcessedFrames = state.metrics.processedFrames
            reportSaved.fulfill()
        }
        // The result is held by a controllable gate, not an inference timing guess.
        // EOF is allowed to run while that final result is deliberately suspended.
        await fulfillment(of: [prematureReport], timeout: 0.1)
        state.isHoldingTerminalResult = false
        release.continuation.yield(())
        release.continuation.finish()
        await fulfillment(of: [reportSaved], timeout: 2)

        XCTAssertEqual(state.reportRepetitions, 5)
        XCTAssertEqual(state.reportProcessedFrames, 12)
    }

    func testEOFWithoutAcceptedFramesStillFinishes() async {
        let delivery = LiveInferenceResultDelivery()
        let finished = expectation(description: "empty source finishes")
        delivery.afterDraining(on: DispatchQueue(label: "test.empty.inference")) { finished.fulfill() }
        await fulfillment(of: [finished], timeout: 2)
    }

    func testEOFWaitsForAcceptedInferenceBeforeItsDeliveryIsScheduled() async {
        let delivery = LiveInferenceResultDelivery()
        let inferenceQueue = DispatchQueue(label: "test.accepted.inference")
        let acceptedFrame = expectation(description: "terminal inference accepted")
        let prematureReport = expectation(description: "accepted inference must finish first")
        prematureReport.isInverted = true
        let reportSaved = expectation(description: "accepted terminal result reported")
        let releaseInference = DispatchSemaphore(value: 0)
        let state = TerminalWorkoutState()

        inferenceQueue.async {
            acceptedFrame.fulfill()
            releaseInference.wait()
            delivery.deliver {
                state.repetitions = 5
                state.metrics.processedFrames = 12
            }
        }
        await fulfillment(of: [acceptedFrame], timeout: 2)
        delivery.afterDraining(on: inferenceQueue) {
            if state.isHoldingTerminalResult { prematureReport.fulfill() }
            state.reportRepetitions = state.repetitions
            state.reportProcessedFrames = state.metrics.processedFrames
            reportSaved.fulfill()
        }
        await fulfillment(of: [prematureReport], timeout: 0.1)
        state.isHoldingTerminalResult = false
        releaseInference.signal()
        await fulfillment(of: [reportSaved], timeout: 2)

        XCTAssertEqual(state.reportRepetitions, 5)
        XCTAssertEqual(state.reportProcessedFrames, 12)
    }
}

@MainActor
private final class TerminalWorkoutState {
    var repetitions = 4
    var metrics = BenchmarkMetrics(processedFrames: 11)
    var isHoldingTerminalResult = true
    var reportRepetitions: Int?
    var reportProcessedFrames: Int?
}
