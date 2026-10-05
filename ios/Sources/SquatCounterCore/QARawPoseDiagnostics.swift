#if DEBUG
import Foundation

public struct QARawPoseCapturePolicy {
    public let isEnabled: Bool
    private let marks = [2.0666666667, 8.0666666667]
    private var counts = [0, 0]
    private var lastAcceptedPTS: Double?
    private let privateClipName: String?

    public init(launchArguments: [String]) {
        privateClipName = launchArguments.first(where: { $0.hasPrefix("--qa-private-clip=") })
            .map { String($0.dropFirst("--qa-private-clip=".count)) }
        isEnabled = launchArguments.contains("--qa-raw-pose-diagnostics") &&
            launchArguments.contains { $0.hasPrefix("--qa-private-clip=") &&
                $0.count > "--qa-private-clip=".count }
    }

    public func permits(source: URL, privateDirectory: URL) -> Bool {
        guard isEnabled, source.isFileURL, privateDirectory.isFileURL,
              let privateClipName, !privateClipName.isEmpty,
              URL(fileURLWithPath: privateClipName).lastPathComponent == privateClipName,
              ["mp4", "mov"].contains(URL(fileURLWithPath: privateClipName).pathExtension.lowercased())
        else { return false }
        return source.standardizedFileURL == privateDirectory.appendingPathComponent(privateClipName).standardizedFileURL
    }

    /// Fixed diagnostic windows; never collect a whole session or camera feed.
    public mutating func accept(at pts: Double) -> Bool {
        guard isEnabled, pts.isFinite, pts >= 0,
              lastAcceptedPTS.map({ pts > $0 }) ?? true,
              let window = marks.firstIndex(where: { abs(pts - $0) <= 0.1 }),
              counts[window] < 16 else { return false }
        counts[window] += 1
        lastAcceptedPTS = pts
        return true
    }
}

public struct QARawPosePoint: Codable, Sendable {
    public let index: Int
    public let x: Double?
    public let y: Double?
    public let visibility: Double?
    public let presence: Double?
    public init(index: Int, x: Double, y: Double, visibility: Double, presence: Double) {
        self.index = index
        self.x = x.isFinite ? x : nil
        self.y = y.isFinite ? y : nil
        self.visibility = visibility.isFinite ? visibility : nil
        self.presence = presence.isFinite ? presence : nil
    }
}

public struct QARawPose: Codable, Sendable {
    public let index: Int
    public let landmarks: [QARawPosePoint]
    public let confidence: Double?
    public let kneeAngle: Double?
    public let hasTrackingCandidate: Bool
    public init(index: Int, landmarks: [QARawPosePoint], confidence: Double,
                kneeAngle: Double?, hasTrackingCandidate: Bool) {
        self.index = index; self.landmarks = landmarks
        self.confidence = confidence.isFinite ? confidence : nil
        self.kneeAngle = kneeAngle.flatMap { $0.isFinite ? $0 : nil }
        self.hasTrackingCandidate = hasTrackingCandidate
    }
}

public struct QARawPoseFrame: Codable, Sendable {
    public let pts: Double
    public let poses: [QARawPose]
    public init(pts: Double, poses: [QARawPose]) { self.pts = pts; self.poses = poses }
}
#endif
