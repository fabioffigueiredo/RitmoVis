import Foundation

public struct VideoPoseObservation: Sendable {
    public let candidate: PoseCandidate
    public let kneeAngle: Double?
    public let confidence: Double
    public init(candidate: PoseCandidate, kneeAngle: Double?, confidence: Double) {
        self.candidate = candidate; self.kneeAngle = kneeAngle; self.confidence = confidence
    }
}

public struct VideoPoseFrame: Sendable {
    public let timestamp: TimeInterval
    public let observations: [VideoPoseObservation]
    public init(timestamp: TimeInterval, observations: [VideoPoseObservation]) {
        self.timestamp = timestamp; self.observations = observations
    }
}

public struct TrackedVideoResult: Sendable {
    public let decision: TrackingDecision
    public let count: Int
    public let event: RepEvent?
    public let phase: SquatPhase
}

/// Replays cached observations without decoding media or recreating its player.
public enum OfflineTargetAnalyzer {
    public static func calibratedCounter(standingAngle: Double, confidence: Double) -> SquatCounter? {
        // Experimental v1: only an explicitly confirmed standing reference is eligible.
        // This adjusts cycle detection, not an assessment of exercise quality.
        guard standingAngle.isFinite, (130...180).contains(standingAngle),
              confidence.isFinite, confidence >= 0.65 else { return nil }
        var counter = SquatCounter()
        counter.standingAngle = min(155, standingAngle - 10)
        counter.bottomAngle = min(105, counter.standingAngle - 35)
        return counter
    }
    public static func analyze(_ frames: [VideoPoseFrame], selectedFrame: Int,
                               candidateIndex: Int, counter initialCounter: SquatCounter = SquatCounter()) -> [TrackedVideoResult] {
        var tracker = TargetTracker()
        var counter = initialCounter
        return frames.enumerated().map { index, frame in
            if index == selectedFrame,
               let chosen = frame.observations.first(where: { $0.candidate.index == candidateIndex }) {
                _ = tracker.select(chosen.candidate, at: frame.timestamp)
            }
            let decision = index < selectedFrame ? TrackingDecision.noSelection
                : tracker.update(frame.observations.map(\.candidate), at: frame.timestamp)
            var event: RepEvent?
            if case .selected(let selectedIndex) = decision,
               let pose = frame.observations.first(where: { $0.candidate.index == selectedIndex }),
               let angle = pose.kneeAngle {
                event = counter.consume(.init(timestamp: frame.timestamp, kneeAngle: angle,
                                               confidence: pose.confidence))
            } else {
                counter.interruptTracking(at: frame.timestamp)
            }
            return TrackedVideoResult(decision: decision, count: counter.repetitions,
                                      event: event, phase: counter.phase)
        }
    }
}
