import Foundation

public struct ClipFrameDiagnostic: Sendable {
    public let candidateCount: Int
    public let decision: TrackingDecision
    public let hasKneeAngle: Bool

    public init(candidateCount: Int, decision: TrackingDecision, hasKneeAngle: Bool) {
        self.candidateCount = candidateCount
        self.decision = decision
        self.hasKneeAngle = hasKneeAngle
    }
}

public struct ClipDiagnosticSummary: Codable, Equatable, Sendable {
    public let noDetectedPeople: Int
    public let awaitingSelection: Int
    public let identityUncertain: Int
    public let reselectionRequired: Int
    public let selectedWithoutUsableAngle: Int
}

/// Diagnostic categories are intentionally non-exclusive: no detected people may also mean no selection.
public enum ClipDiagnostics {
    public static func summarize(_ frames: [ClipFrameDiagnostic]) -> ClipDiagnosticSummary {
        var noDetectedPeople = 0
        var awaitingSelection = 0
        var identityUncertain = 0
        var reselectionRequired = 0
        var selectedWithoutUsableAngle = 0
        for frame in frames {
            if frame.candidateCount == 0 { noDetectedPeople += 1 }
            switch frame.decision {
            case .noSelection: awaitingSelection += 1
            case .uncertain: identityUncertain += 1
            case .reselectionRequired: reselectionRequired += 1
            case .selected:
                if !frame.hasKneeAngle { selectedWithoutUsableAngle += 1 }
            }
        }
        return ClipDiagnosticSummary(noDetectedPeople: noDetectedPeople,
                                     awaitingSelection: awaitingSelection,
                                     identityUncertain: identityUncertain,
                                     reselectionRequired: reselectionRequired,
                                     selectedWithoutUsableAngle: selectedWithoutUsableAngle)
    }
}
