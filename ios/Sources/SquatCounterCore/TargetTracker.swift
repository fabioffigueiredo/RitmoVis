import Foundation

/// A frame-local pose observation. `index` is never an identity across frames.
public struct PoseCandidate: Equatable, Sendable, Codable {
    public let index: Int
    public let centerX: Double
    public let centerY: Double
    public let width: Double
    public let height: Double
    public let confidence: Double
    /// Six normalized RGB means (upper and lower torso); session-local evidence, not an identity.
    public let appearance: [Double]?

    public init(index: Int, centerX: Double, centerY: Double, width: Double, height: Double,
                confidence: Double, appearance: [Double]? = nil) {
        self.index = index
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.confidence = confidence
        self.appearance = appearance
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
    private var referenceAppearance: [Double]?
    private var pendingRecovery: PoseCandidate?
    private var pendingRecoveryAt: TimeInterval?

    public init() {}

    public mutating func select(_ candidate: PoseCandidate, at time: TimeInterval) -> TrackingDecision {
        guard isValid(candidate), time.isFinite else { return .uncertain }
        anchor = candidate
        lastConfirmedAt = time
        requiresReselection = false
        referenceAppearance = validAppearance(candidate.appearance)
        pendingRecovery = nil
        pendingRecoveryAt = nil
        return .selected(index: candidate.index)
    }

    public mutating func update(_ candidates: [PoseCandidate], at time: TimeInterval) -> TrackingDecision {
        guard let anchor, let lastConfirmedAt else {
            return requiresReselection ? .reselectionRequired : .noSelection
        }
        guard time.isFinite, time >= lastConfirmedAt else { return .uncertain }
        let age = time - lastConfirmedAt
        if age >= (referenceAppearance == nil ? 0.8 : 2.0) {
            invalidateSelection()
            return .reselectionRequired
        }
        if age > 0.45 && referenceAppearance == nil { return .uncertain }

        let ranked = candidates.compactMap { candidate -> (candidate: PoseCandidate, score: Double)? in
            guard isValid(candidate) else { return nil }
            let distance = hypot(candidate.centerX - anchor.centerX, candidate.centerY - anchor.centerY)
            let sizeChange = abs(candidate.width - anchor.width) + abs(candidate.height - anchor.height)
            guard distance <= (age > 0.45 ? 0.28 : 0.22), sizeChange <= 0.24 else { return nil }
            if let referenceAppearance {
                guard let current = validAppearance(candidate.appearance) else {
                    // A missing signature cannot justify a long-gap reacquisition.
                    guard age <= 0.45 else { return nil }
                    return (candidate, distance + 0.2 * sizeChange + 0.15)
                }
                let difference = appearanceDistance(referenceAppearance, current)
                guard difference <= 0.25 else { return nil }
                return (candidate, distance + 0.2 * sizeChange + 0.5 * difference)
            }
            return (candidate, distance + 0.2 * sizeChange)
        }.sorted { $0.score < $1.score }

        guard let best = ranked.first else {
            // Keep the last known target briefly; a passer-by must not replace it.
            return .uncertain
        }
        if ranked.count > 1 && ranked[1].score - best.score < 0.06 {
            invalidateSelection()
            return .uncertain
        }
        if age > 0.45 {
            guard let pendingRecovery, let pendingRecoveryAt,
                  time - pendingRecoveryAt >= 0.05,
                  time - pendingRecoveryAt <= 0.3,
                  hypot(best.candidate.centerX - pendingRecovery.centerX,
                        best.candidate.centerY - pendingRecovery.centerY) <= 0.08 else {
                self.pendingRecovery = best.candidate
                self.pendingRecoveryAt = time
                return .uncertain
            }
        }
        self.anchor = best.candidate
        self.lastConfirmedAt = time
        pendingRecovery = nil
        pendingRecoveryAt = nil
        if let current = validAppearance(best.candidate.appearance) {
            if let referenceAppearance {
                self.referenceAppearance = zip(referenceAppearance, current).map { 0.85 * $0 + 0.15 * $1 }
            } else {
                self.referenceAppearance = current
            }
        }
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
        referenceAppearance = nil
        pendingRecovery = nil
        pendingRecoveryAt = nil
    }

    private func validAppearance(_ values: [Double]?) -> [Double]? {
        guard let values, values.count == 6,
              values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        return values
    }

    private func appearanceDistance(_ a: [Double], _ b: [Double]) -> Double {
        sqrt(zip(a, b).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) } / 6)
    }
}
