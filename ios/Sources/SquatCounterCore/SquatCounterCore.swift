import Foundation

public enum SquatPhase: Equatable, Sendable { case unknown, standing, descending, bottom, ascending, trackingLost }

public struct SquatSample: Sendable {
    public let timestamp: TimeInterval
    public let kneeAngle: Double
    public let confidence: Double
    public init(timestamp: TimeInterval, kneeAngle: Double, confidence: Double) {
        self.timestamp = timestamp; self.kneeAngle = kneeAngle; self.confidence = confidence
    }
}

public struct RepEvent: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let confidence: Double
    public init(timestamp: TimeInterval, confidence: Double) { self.id = UUID(); self.timestamp = timestamp; self.confidence = confidence }
}

/// Conta ciclos observados; não classifica qualidade, amplitude segura ou técnica.
public struct SquatCounter: Sendable {
    public private(set) var phase: SquatPhase = .unknown
    public private(set) var repetitions = 0
    public private(set) var events: [RepEvent] = []
    public var minimumConfidence = 0.55
    public var standingAngle = 155.0
    public var bottomAngle = 105.0
    public var minimumPhaseDuration: TimeInterval = 0.18
    public var occlusionTimeout: TimeInterval = 0.45
    private var phaseSince: TimeInterval = 0
    private var lastValidTimestamp: TimeInterval?
    private var bottomConfidence: Double = 0

    public init() {}

    public mutating func consume(_ sample: SquatSample) -> RepEvent? {
        if let last = lastValidTimestamp, sample.timestamp <= last { return nil }
        guard sample.confidence >= minimumConfidence else {
            if let last = lastValidTimestamp, sample.timestamp - last >= occlusionTimeout { transition(to: .trackingLost, at: sample.timestamp) }
            return nil
        }
        if let last = lastValidTimestamp, sample.timestamp - last >= occlusionTimeout {
            transition(to: .trackingLost, at: sample.timestamp)
        }
        lastValidTimestamp = sample.timestamp
        if phase == .trackingLost || phase == .unknown { transition(to: sample.kneeAngle >= standingAngle ? .standing : .unknown, at: sample.timestamp); return nil }
        guard sample.timestamp - phaseSince >= minimumPhaseDuration else { return nil }
        switch phase {
        case .standing where sample.kneeAngle < standingAngle - 8: transition(to: .descending, at: sample.timestamp)
        case .descending where sample.kneeAngle <= bottomAngle: bottomConfidence = sample.confidence; transition(to: .bottom, at: sample.timestamp)
        case .bottom where sample.kneeAngle > bottomAngle + 8: transition(to: .ascending, at: sample.timestamp)
        case .ascending where sample.kneeAngle >= standingAngle:
            transition(to: .standing, at: sample.timestamp)
            repetitions += 1
            let event = RepEvent(timestamp: sample.timestamp, confidence: min(sample.confidence, bottomConfidence))
            events.append(event); return event
        default: break
        }
        return nil
    }

    public mutating func reset() { self = SquatCounter() }
    private mutating func transition(to newPhase: SquatPhase, at timestamp: TimeInterval) { phase = newPhase; phaseSince = timestamp }
}

public struct WorkoutPlan: Sendable { public var targetRepetitions: Int; public var duration: TimeInterval; public init(targetRepetitions: Int = 12, duration: TimeInterval = 60) { self.targetRepetitions = targetRepetitions; self.duration = duration } }

public enum Exercise: String, CaseIterable, Identifiable, Sendable { case bodyweightSquat = "Agachamento livre"; public var id: String { rawValue } }
