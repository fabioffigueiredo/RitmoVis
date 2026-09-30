import Foundation

public enum HandGesture: Equatable, Sendable {
    case openPalm
    case closedFist
    case unknown
}

/// The adapter must associate the hand unambiguously with this frame's pose.
public struct GestureObservation: Equatable, Sendable {
    public let gesture: HandGesture
    public let confidence: Double
    public let candidate: PoseCandidate
    public let isAboveShoulder: Bool

    public init(gesture: HandGesture, confidence: Double, candidate: PoseCandidate,
                isAboveShoulder: Bool) {
        self.gesture = gesture
        self.confidence = confidence
        self.candidate = candidate
        self.isAboveShoulder = isAboveShoulder
    }
}

public enum HandGestureCommand: Equatable, Sendable {
    case select(candidateIndex: Int)
    case stop
}

/// Session-local experimental command recognition; it never changes repetition state.
public struct HandGestureControl: Sendable {
    public private(set) var holdProgress = 0.0
    public private(set) var isInitialSelectionExpired = false
    private var initialSelectionEnabled = true
    private var holdStartedAt: TimeInterval?
    private var initialTracker = TargetTracker()
    private var lastFrameAt: TimeInterval?
    private var stopEmitted = false
    private var firstFrameAt: TimeInterval?

    public init() {}

    /// Call for a manual selection, including one followed immediately by tracking loss.
    /// Automatic selection stays disabled until a new controller/session is created.
    public mutating func markSelected() {
        initialSelectionEnabled = false
        resetHold()
    }

    /// Cancel a gesture when a raw pose frame loses usable tracking, even when
    /// hand recognition is throttled. Session selection and clocks are preserved.
    public mutating func invalidatePendingHold() {
        resetHold()
    }

    /// Verify pending gesture ownership on every raw pose frame, independently
    /// of hand-recognition cadence. Pose-only frames never advance the countdown.
    public mutating func observePoseFrame(candidates: [PoseCandidate],
                                         tracking: TrackingDecision, at time: TimeInterval) {
        guard holdStartedAt != nil else { return }
        guard time.isFinite, let lastFrameAt, time >= lastFrameAt,
              time - lastFrameAt <= 0.25 else {
            resetHold()
            return
        }
        if initialSelectionEnabled {
            guard tracking == .noSelection else {
                if case .selected = tracking { markSelected() } else { resetHold() }
                return
            }
        } else {
            guard case .selected = tracking else {
                resetHold()
                return
            }
        }
        guard case let .selected(index) = initialTracker.update(candidates, at: time),
              candidates.filter({ $0.index == index }).count == 1,
              let candidate = candidates.first(where: { $0.index == index }),
              candidate.confidence.isFinite, (0.5...1).contains(candidate.confidence) else {
            resetHold()
            return
        }
        if !initialSelectionEnabled, tracking != .selected(index: index) { resetHold() }
    }

    public mutating func consume(_ observations: [GestureObservation], candidates: [PoseCandidate],
                                 tracking: TrackingDecision, selectedCandidate: PoseCandidate?,
                                 at time: TimeInterval) -> HandGestureCommand? {
        guard time.isFinite, lastFrameAt.map({ time > $0 }) ?? true else {
            resetHold()
            return nil
        }
        if let lastFrameAt, time - lastFrameAt > 0.25 { resetHold() }
        lastFrameAt = time
        if case .selected = tracking, initialSelectionEnabled {
            markSelected()
        }
        if firstFrameAt == nil { firstFrameAt = time }
        if initialSelectionEnabled, let firstFrameAt, time - firstFrameAt >= 30 {
            isInitialSelectionExpired = true
        }
        if initialSelectionEnabled && isInitialSelectionExpired {
            resetHold()
            return nil
        }
        let recognized = observations.filter {
            $0.confidence.isFinite && (0.8...1).contains($0.confidence) && $0.gesture != .unknown
        }
        guard !stopEmitted, let observation = recognized.first,
              recognized.allSatisfy({ $0.candidate == observation.candidate &&
                  $0.gesture == observation.gesture }),
              candidates.filter({ $0.index == observation.candidate.index }).count == 1,
              candidates.contains(observation.candidate),
              observation.candidate.confidence.isFinite,
              (0.5...1).contains(observation.candidate.confidence),
              observation.isAboveShoulder else {
            resetHold()
            return nil
        }
        let command: HandGestureCommand
        if initialSelectionEnabled {
            guard tracking == .noSelection, observation.gesture == .openPalm else {
                resetHold()
                return nil
            }
            command = .select(candidateIndex: observation.candidate.index)
        } else {
            guard case let .selected(index) = tracking,
                  let selectedCandidate, selectedCandidate.index == index,
                  selectedCandidate == observation.candidate,
                  observation.gesture == .closedFist else {
                resetHold()
                return nil
            }
            command = .stop
        }
        if holdStartedAt == nil {
            guard initialTracker.select(observation.candidate, at: time) ==
                    .selected(index: observation.candidate.index) else { return nil }
            holdStartedAt = time
        }
        // Seed rival observations on the first frame too: a nearby bystander must
        // not inherit the hold when the performer vanishes on the next frame.
        guard case let .selected(index) = initialTracker.update(candidates, at: time),
              candidates.filter({ $0.index == index }).count == 1,
              candidates.first(where: { $0.index == index }) == observation.candidate else {
            resetHold()
            return nil
        }
        guard let start = holdStartedAt else { return nil }
        holdProgress = min(1, max(0, (time - start) / 2))
        guard holdProgress >= 1 else { return nil }
        initialSelectionEnabled = false
        holdStartedAt = nil
        if command == .stop { stopEmitted = true }
        return command
    }

    private mutating func resetHold() {
        holdProgress = 0
        holdStartedAt = nil
        initialTracker = TargetTracker()
    }
}
