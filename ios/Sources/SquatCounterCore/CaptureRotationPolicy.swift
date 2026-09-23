/// Keeps camera-output pixels in one orientation for the lifetime of a movie recording.
/// The UI may rotate independently, but replay landmarks and movie frames must share a basis.
public struct CaptureRotationPolicy: Equatable, Sendable {
    public private(set) var lockedAngle: Double?

    public init() {}

    public mutating func startRecording(at angle: Double) {
        lockedAngle = angle
    }

    public mutating func endRecording() {
        lockedAngle = nil
    }

    public func angle(for requestedAngle: Double) -> Double {
        lockedAngle ?? requestedAngle
    }
}
