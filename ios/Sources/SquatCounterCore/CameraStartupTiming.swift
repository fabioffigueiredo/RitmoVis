import Foundation

/// Monotonic timestamps from one clock. Permission time is excluded only from the adjusted metric.
public struct CameraStartupTiming: Codable, Equatable, Sendable {
    public private(set) var tapAt: TimeInterval?
    public private(set) var visualResponseAt: TimeInterval?
    public private(set) var permissionRequestedAt: TimeInterval?
    public private(set) var permissionResolvedAt: TimeInterval?
    public private(set) var captureRunningAt: TimeInterval?
    public private(set) var firstFrameAt: TimeInterval?
    public private(set) var firstPoseAt: TimeInterval?

    public init() {}

    public mutating func start(at time: TimeInterval) { self = Self(); tapAt = time }
    public mutating func permissionRequested(at time: TimeInterval) { if permissionRequestedAt == nil { permissionRequestedAt = time } }
    public mutating func visualResponse(at time: TimeInterval) { if visualResponseAt == nil { visualResponseAt = time } }
    public mutating func permissionResolved(at time: TimeInterval) { if permissionResolvedAt == nil { permissionResolvedAt = time } }
    public mutating func captureRunning(at time: TimeInterval) { if captureRunningAt == nil { captureRunningAt = time } }
    public mutating func firstFrame(at time: TimeInterval) { if firstFrameAt == nil { firstFrameAt = time } }
    public mutating func firstPose(at time: TimeInterval) { if firstPoseAt == nil { firstPoseAt = time } }

    public var permissionWaitMs: Double { interval(permissionRequestedAt, permissionResolvedAt) }
    public var tapToVisualResponseMs: Double { interval(tapAt, visualResponseAt) }
    public var tapToCaptureMs: Double { interval(tapAt, captureRunningAt) }
    public var tapToFirstFrameMs: Double { interval(tapAt, firstFrameAt) }
    public var tapToFirstPoseMs: Double { interval(tapAt, firstPoseAt) }
    public var startupExcludingPermissionMs: Double { max(0, tapToFirstFrameMs - permissionWaitMs) }

    private func interval(_ start: TimeInterval?, _ end: TimeInterval?) -> Double {
        guard let start, let end, end >= start else { return 0 }
        return (end - start) * 1_000
    }
}
