public struct CameraFrameHealth: Sendable {
    public private(set) var nearBlackFrames = 0
    public private(set) var consecutiveNearBlackFrames = 0

    public init() {}

    public mutating func observe(isNearBlack: Bool) {
        if isNearBlack {
            nearBlackFrames += 1
            consecutiveNearBlackFrames += 1
        } else {
            consecutiveNearBlackFrames = 0
        }
    }

    public var shouldWarn: Bool { consecutiveNearBlackFrames >= 30 }
}
