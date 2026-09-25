import Foundation

/// A frame-local pose observation. `index` is never an identity across frames.
public struct PoseCandidate: Equatable, Sendable, Codable {
    public let index: Int
    public let centerX: Double
    public let centerY: Double
    public let width: Double
    public let height: Double
    public let confidence: Double

    public init(index: Int, centerX: Double, centerY: Double, width: Double, height: Double, confidence: Double) {
        self.index = index
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.confidence = confidence
    }
}

public enum TrackingDecision: Equatable, Sendable {
    case noSelection
    case selected(index: Int)
    case uncertain
    case reselectionRequired
}

/// Conservative, session-local geometry association. This is a baseline, not proof of identity.
/// When candidates overlap or the target disappears, callers must abstain from counting.
public struct TargetTracker: Sendable {
    private var anchor: PoseCandidate?
    private var lastConfirmedAt: TimeInterval?
    private var requiresReselection = false

    public init() {}

    public mutating func select(_ candidate: PoseCandidate, at time: TimeInterval) -> TrackingDecision {
        guard isValid(candidate), time.isFinite else { return .uncertain }
        anchor = candidate
        lastConfirmedAt = time
        requiresReselection = false
        return .selected(index: candidate.index)
    }

    public mutating func update(_ candidates: [PoseCandidate], at time: TimeInterval) -> TrackingDecision {
        guard let anchor, let lastConfirmedAt else {
            return requiresReselection ? .reselectionRequired : .noSelection
        }
        guard time.isFinite, time >= lastConfirmedAt else { return .uncertain }
        if time - lastConfirmedAt > 0.45 {
            self.anchor = nil
            self.lastConfirmedAt = nil
            requiresReselection = true
            return .reselectionRequired
        }

        let ranked = candidates.compactMap { candidate -> (candidate: PoseCandidate, score: Double)? in
            guard isValid(candidate) else { return nil }
            let distance = hypot(candidate.centerX - anchor.centerX, candidate.centerY - anchor.centerY)
            let sizeChange = abs(candidate.width - anchor.width) + abs(candidate.height - anchor.height)
            guard distance <= 0.22, sizeChange <= 0.24 else { return nil }
            return (candidate, distance + 0.2 * sizeChange)
        }.sorted { $0.score < $1.score }

        guard let best = ranked.first else {
            if !candidates.isEmpty { invalidateSelection() }
            return .uncertain
        }
        if ranked.count > 1 && ranked[1].score - best.score < 0.06 {
            invalidateSelection()
            return .uncertain
        }
        self.anchor = best.candidate
        self.lastConfirmedAt = time
        return .selected(index: best.candidate.index)
    }

    private func isValid(_ candidate: PoseCandidate) -> Bool {
        candidate.index >= 0 &&
        candidate.centerX.isFinite && (0...1).contains(candidate.centerX) &&
        candidate.centerY.isFinite && (0...1).contains(candidate.centerY) &&
        candidate.width.isFinite && candidate.width > 0 && candidate.width <= 1 &&
        candidate.height.isFinite && candidate.height > 0 && candidate.height <= 1 &&
        candidate.confidence.isFinite && candidate.confidence >= 0.5
    }

    private mutating func invalidateSelection() {
        anchor = nil
        lastConfirmedAt = nil
        requiresReselection = true
    }
}
