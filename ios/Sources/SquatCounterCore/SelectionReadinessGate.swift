import Foundation

/// Briefly withholds live counts after choosing an athlete so they can return
/// to position. It uses the frame time domain, never wall-clock time.
public struct SelectionReadinessGate: Sendable {
    public let delay: TimeInterval
    private var readyAt: TimeInterval?

    public init(delay: TimeInterval = 3) {
        self.delay = max(0, delay.isFinite ? delay : 3)
    }

    public mutating func arm(at timestamp: TimeInterval) {
        readyAt = timestamp.isFinite ? timestamp + delay : nil
    }

    public mutating func disarm() { readyAt = nil }

    public func isReady(at timestamp: TimeInterval) -> Bool {
        guard timestamp.isFinite, let readyAt else { return false }
        return timestamp >= readyAt
    }

    public func remaining(at timestamp: TimeInterval) -> TimeInterval? {
        guard timestamp.isFinite, let readyAt else { return nil }
        return max(0, readyAt - timestamp)
    }
}
