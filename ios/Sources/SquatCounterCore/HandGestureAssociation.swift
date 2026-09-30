import Foundation

public struct GestureBodyWrist: Sendable {
    public let candidateIndex: Int
    public let x: Double
    public let y: Double
    public let shoulderY: Double
    public let confidence: Double
    public let bodyUsable: Bool

    public init(candidateIndex: Int, x: Double, y: Double, shoulderY: Double,
                confidence: Double, bodyUsable: Bool) {
        self.candidateIndex = candidateIndex; self.x = x; self.y = y
        self.shoulderY = shoulderY; self.confidence = confidence; self.bodyUsable = bodyUsable
    }
}

/// A spatial gate, not proof of identity or liveness. Reject overlapping wrists.
public enum HandGestureAssociation {
    public static func candidateIndex(handX: Double, handY: Double,
                                      bodyWrists: [GestureBodyWrist], aspectRatio: Double) -> Int? {
        guard handX.isFinite, handY.isFinite, (0...1).contains(handX),
              (0...1).contains(handY), aspectRatio.isFinite, aspectRatio > 0 else { return nil }
        // First resolve ownership across every confident wrist, including cropped
        // bystanders. Command eligibility must never hide a competing owner.
        let nearby = bodyWrists.filter {
            $0.confidence.isFinite && (0.55...1).contains($0.confidence) &&
            $0.x.isFinite && $0.y.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y) &&
            hypot((handX - $0.x) * aspectRatio, handY - $0.y) <= 0.075
        }
        let owners = Set(nearby.map(\.candidateIndex))
        guard owners.count == 1, let owner = owners.first,
              nearby.contains(where: { $0.bodyUsable && $0.shoulderY.isFinite &&
                  (0...1).contains($0.shoulderY) && handY < $0.shoulderY - 0.03 }) else { return nil }
        return owner
    }
}
