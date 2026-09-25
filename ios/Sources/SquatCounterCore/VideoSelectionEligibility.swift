import Foundation

/// Rejects pose-like regions that cannot supply enough knee observations to analyze
/// this exercise. This is not a general-purpose photo or liveness detector.
public enum VideoSelectionEligibility {
    public static func isEligible(_ frames: [VideoPoseFrame], selectedFrame: Int,
                                  candidateIndex: Int, horizon: TimeInterval = 2) -> Bool {
        guard frames.indices.contains(selectedFrame),
              let initial = frames[selectedFrame].observations.first(where: {
                  $0.candidate.index == candidateIndex
              }) else { return false }
        var tracker = TargetTracker()
        _ = tracker.select(initial.candidate, at: frames[selectedFrame].timestamp)
        let start = frames[selectedFrame].timestamp
        var selected = 0
        var analyzable = 0
        for frame in frames[selectedFrame...] {
            if frame.timestamp - start > horizon { break }
            guard case .selected(let index) = tracker.update(frame.observations.map(\.candidate),
                                                               at: frame.timestamp) else { continue }
            selected += 1
            if let pose = frame.observations.first(where: { $0.candidate.index == index }),
               let angle = pose.kneeAngle, angle.isFinite, pose.confidence >= 0.5 {
                analyzable += 1
            }
        }
        return selected >= 12 && analyzable >= 10 && Double(analyzable) / Double(selected) >= 0.5
    }
}
