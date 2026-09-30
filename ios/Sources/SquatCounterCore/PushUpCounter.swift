import Foundation

public struct PushUpJoint: Sendable {
    public let x: Double
    public let y: Double
    public let confidence: Double

    public init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public struct PushUpPoseMeasurement: Sendable {
    public let elbowAngle: Double
    public let confidence: Double
}

/// Extracts an elbow angle only if one full arm and same-side trunk/ankle are
/// visible. This does not recognize a push-up or assess exercise technique.
public enum PushUpPoseGeometry {
    public static func measure(landmarks: [PushUpJoint],
                               aspectRatio: Double,
                               minimumConfidence: Double = 0.55) -> PushUpPoseMeasurement? {
        guard landmarks.count >= 29, aspectRatio.isFinite, aspectRatio > 0 else { return nil }
        let left = side(landmarks, indices: [11, 13, 15, 23, 27],
                        aspectRatio: aspectRatio, minimumConfidence: minimumConfidence)
        let right = side(landmarks, indices: [12, 14, 16, 24, 28],
                         aspectRatio: aspectRatio, minimumConfidence: minimumConfidence)
        return [left, right].compactMap { $0 }.max { $0.confidence < $1.confidence }
    }

    private static func side(_ landmarks: [PushUpJoint], indices: [Int],
                             aspectRatio: Double, minimumConfidence: Double) -> PushUpPoseMeasurement? {
        let joints = indices.map { landmarks[$0] }
        guard joints.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.confidence.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y) &&
            $0.confidence >= minimumConfidence }) else { return nil }
        let shoulder = joints[0], elbow = joints[1], wrist = joints[2]
        let hip = joints[3], ankle = joints[4]
        func distance(_ a: PushUpJoint, _ b: PushUpJoint) -> Double {
            hypot((a.x - b.x) * aspectRatio, a.y - b.y)
        }
        guard distance(shoulder, elbow) > 0.015,
              distance(elbow, wrist) > 0.015,
              distance(shoulder, hip) > 0.04,
              distance(hip, ankle) > 0.04 else { return nil }
        let ax = (shoulder.x - elbow.x) * aspectRatio
        let ay = shoulder.y - elbow.y
        let bx = (wrist.x - elbow.x) * aspectRatio
        let by = wrist.y - elbow.y
        let cosine = (ax * bx + ay * by) / (hypot(ax, ay) * hypot(bx, by))
        guard cosine.isFinite else { return nil }
        let angle = acos(min(1, max(-1, cosine))) * 180 / .pi
        return PushUpPoseMeasurement(elbowAngle: angle,
                                     confidence: joints.map(\.confidence).min() ?? 0)
    }
}

/// Side-view, one-person experimental measurement. The caller must establish that
/// the same selected person's arm and trunk are observable; it is not a technique
/// or injury-risk assessment.
public struct PushUpSample: Sendable {
    public let timestamp: TimeInterval
    public let elbowAngle: Double
    public let armAndTrunkObserved: Bool
    public let confidence: Double

    public init(timestamp: TimeInterval, elbowAngle: Double,
                armAndTrunkObserved: Bool, confidence: Double) {
        self.timestamp = timestamp
        self.elbowAngle = elbowAngle
        self.armAndTrunkObserved = armAndTrunkObserved
        self.confidence = confidence
    }
}

public enum PushUpPhase: Equatable, Sendable {
    case unknown, high, lowering, low, rising, trackingLost
}

/// Counts observable high → low → high cycles. Missing joints or uncertain ID
/// discard an unfinished cycle; previously completed repetitions are preserved.
public struct PushUpCounter: Sendable {
    public private(set) var phase: PushUpPhase = .unknown
    public private(set) var repetitions = 0
    public private(set) var events: [RepEvent] = []
    public var minimumConfidence = 0.55
    public var highAngle = 155.0
    public var lowAngle = 95.0
    public var minimumPhaseDuration: TimeInterval = 0.18
    public var occlusionTimeout: TimeInterval = 0.45

    private var phaseSince: TimeInterval = 0
    private var lastTimestamp: TimeInterval?
    private var lastValidTimestamp: TimeInterval?
    private var lowConfidence: Double = 0

    public init() {}

    public mutating func consume(_ sample: PushUpSample) -> RepEvent? {
        guard sample.timestamp.isFinite,
              lastTimestamp.map({ sample.timestamp > $0 }) ?? true else {
            // Bad frame ordering cannot contribute to a cycle in progress.
            lastValidTimestamp = nil
            lowConfidence = 0
            transition(to: .trackingLost, at: lastTimestamp ?? 0)
            return nil
        }
        lastTimestamp = sample.timestamp
        guard sample.elbowAngle.isFinite, sample.confidence.isFinite,
              sample.armAndTrunkObserved, sample.confidence >= minimumConfidence,
              (0...180).contains(sample.elbowAngle) else {
            interruptTracking(at: sample.timestamp)
            return nil
        }
        if let lastValidTimestamp,
           sample.timestamp - lastValidTimestamp >= occlusionTimeout {
            phase = .trackingLost
            lowConfidence = 0
        }
        lastValidTimestamp = sample.timestamp
        if phase == .unknown || phase == .trackingLost {
            transition(to: sample.elbowAngle >= highAngle ? .high : .unknown,
                       at: sample.timestamp)
            return nil
        }
        guard sample.timestamp - phaseSince >= minimumPhaseDuration else { return nil }
        switch phase {
        case .high where sample.elbowAngle < highAngle - 8:
            transition(to: .lowering, at: sample.timestamp)
        case .lowering where sample.elbowAngle <= lowAngle:
            lowConfidence = sample.confidence
            transition(to: .low, at: sample.timestamp)
        case .low where sample.elbowAngle > lowAngle + 8:
            transition(to: .rising, at: sample.timestamp)
        case .rising where sample.elbowAngle >= highAngle:
            transition(to: .high, at: sample.timestamp)
            repetitions += 1
            let event = RepEvent(timestamp: sample.timestamp,
                                 confidence: min(sample.confidence, lowConfidence))
            events.append(event)
            return event
        default: break
        }
        return nil
    }

    public mutating func interruptTracking(at timestamp: TimeInterval) {
        guard timestamp.isFinite,
              lastTimestamp.map({ timestamp >= $0 }) ?? true else { return }
        lastTimestamp = timestamp
        lastValidTimestamp = nil
        lowConfidence = 0
        transition(to: .trackingLost, at: timestamp)
    }

    public mutating func reset() { self = PushUpCounter() }

    private mutating func transition(to newPhase: PushUpPhase, at timestamp: TimeInterval) {
        phase = newPhase
        phaseSince = timestamp
    }
}
