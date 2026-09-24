import AVFoundation
import MediaPipeTasksVision
import SquatCounterCore

struct PosePoint: Sendable { let x: Double; let y: Double; let visibility: Double; let presence: Double }
struct PoseFrame: Sendable { let landmarks: [PosePoint]; let confidence: Double; let kneeAngle: Double?; let imageAspectRatio: Double }
struct PoseDetectionBatch: Sendable {
    let poses: [PoseFrame]
    let candidates: [PoseCandidate]
    let imageAspectRatio: Double
}

/// Adaptador fino: apenas converte o resultado local do MediaPipe em dados do contador.
final class PoseDetector {
    private let landmarker: PoseLandmarker
    init(model: PoseModel) throws {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = Bundle.main.path(forResource: model == .lite ? "pose_landmarker_lite" : "pose_landmarker_full", ofType: "task") ?? ""
        options.runningMode = .video
        options.numPoses = 4
        guard !options.baseOptions.modelAssetPath.isEmpty else { throw NSError(domain: "SquatCounter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Modelo MediaPipe ausente"]) }
        landmarker = try PoseLandmarker(options: options)
    }
    func detect(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) throws -> PoseDetectionBatch {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let aspectRatio = pixelBuffer.map { Double(CVPixelBufferGetWidth($0)) / Double(CVPixelBufferGetHeight($0)) } ?? 1
        let image = try MPImage(sampleBuffer: sampleBuffer)
        let result = try landmarker.detect(videoFrame: image, timestampInMilliseconds: Int(timestamp * 1_000))
        var frames: [PoseFrame] = []
        var candidates: [PoseCandidate] = []
        for (index, pose) in result.landmarks.enumerated() {
            let points = pose.map { PosePoint(x: Double($0.x), y: Double($0.y), visibility: $0.visibility?.doubleValue ?? 0, presence: $0.presence?.doubleValue ?? 0) }
        // Índices BlazePose: ancas 23/24, joelhos 25/26, tornozelos 27/28.
        // Na vista lateral, o lado oposto pode estar oculto. Escolha somente um
        // trio de articulações visível; a confiança não é inventada nem diluída
        // pelos pontos do lado oculto.
            let left = side(hip: points[safe: 23], knee: points[safe: 25], ankle: points[safe: 27], aspectRatio: aspectRatio)
            let right = side(hip: points[safe: 24], knee: points[safe: 26], ankle: points[safe: 28], aspectRatio: aspectRatio)
            let chosen = [left, right].compactMap { $0 }.max { $0.confidence < $1.confidence }
            frames.append(PoseFrame(landmarks: points, confidence: chosen?.confidence ?? 0,
                                    kneeAngle: chosen?.angle, imageAspectRatio: aspectRatio))
            let visible = points.filter { min($0.visibility, $0.presence) >= 0.5 &&
                $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }
            guard visible.count >= 8,
                  let minX = visible.map(\.x).min(), let maxX = visible.map(\.x).max(),
                  let minY = visible.map(\.y).min(), let maxY = visible.map(\.y).max() else { continue }
            let confidence = visible.map { min($0.visibility, $0.presence) }.reduce(0, +) / Double(visible.count)
            candidates.append(PoseCandidate(index: index, centerX: (minX + maxX) / 2,
                                            centerY: (minY + maxY) / 2, width: maxX - minX,
                                            height: maxY - minY, confidence: confidence))
        }
        return PoseDetectionBatch(poses: frames, candidates: candidates, imageAspectRatio: aspectRatio)
    }
    private func side(hip: PosePoint?, knee: PosePoint?, ankle: PosePoint?, aspectRatio: Double) -> (angle: Double, confidence: Double)? {
        guard let hip, let knee, let ankle, let angle = angle(hip: hip, knee: knee, ankle: ankle, aspectRatio: aspectRatio) else { return nil }
        let confidence = [hip, knee, ankle].map { min($0.visibility, $0.presence) }.min() ?? 0
        guard confidence >= 0.55 else { return nil }
        return (angle, confidence)
    }
    private func angle(hip: PosePoint?, knee: PosePoint?, ankle: PosePoint?, aspectRatio: Double) -> Double? {
        guard let hip, let knee, let ankle else { return nil }
        // Os landmarks são normalizados por eixo; reponha a proporção dos pixels.
        let a = atan2(hip.y - knee.y, (hip.x - knee.x) * aspectRatio)
        let b = atan2(ankle.y - knee.y, (ankle.x - knee.x) * aspectRatio)
        var degrees = abs((a - b) * 180 / .pi); if degrees > 180 { degrees = 360 - degrees }; return degrees
    }
}
private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
