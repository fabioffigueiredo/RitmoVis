import AVFoundation
import MediaPipeTasksVision
import SquatCounterCore
import Vision
import UIKit
import CoreImage

struct PosePoint: Sendable { let x: Double; let y: Double; let visibility: Double; let presence: Double }
struct PoseFrame: Sendable { let landmarks: [PosePoint]; let confidence: Double; let kneeAngle: Double?; let imageAspectRatio: Double }
struct PoseDetectionBatch: Sendable {
    let poses: [PoseFrame]
    let candidates: [PoseCandidate]
    let imageAspectRatio: Double
}

/// Adaptador fino: apenas converte o resultado local do MediaPipe em dados do contador.
final class PoseDetector {
    private let landmarker: PoseLandmarker?
    private let independentFrames: Bool
    private let useVision: Bool
    private let hybrid: Bool
    private let visionRequest = VNDetectHumanBodyPoseRequest()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    init(model: PoseModel, useVisionForVideo: Bool = false,
         hybridExperiment: Bool = false, independentFrameExperiment: Bool = false) throws {
        hybrid = hybridExperiment
        independentFrames = hybrid || independentFrameExperiment
        useVision = useVisionForVideo || hybrid
        if useVision && !hybrid { landmarker = nil; return }
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = Bundle.main.path(forResource: model == .lite ? "pose_landmarker_lite" : "pose_landmarker_full", ofType: "task") ?? ""
        options.runningMode = independentFrames ? .image : .video
        options.numPoses = hybrid ? 1 : 4
        guard !options.baseOptions.modelAssetPath.isEmpty else { throw NSError(domain: "SquatCounter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Modelo MediaPipe ausente"]) }
        landmarker = try PoseLandmarker(options: options)
    }
    func detect(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) throws -> PoseDetectionBatch {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let aspectRatio = pixelBuffer.map { Double(CVPixelBufferGetWidth($0)) / Double(CVPixelBufferGetHeight($0)) } ?? 1
        let pointSets: [[PosePoint]]
        var geometrySets: [[PosePoint]]?
        if useVision, let pixelBuffer {
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([visionRequest])
            let mapping: [(VNHumanBodyPoseObservation.JointName, Int)] = [
                (.nose, 0), (.leftEye, 2), (.rightEye, 5), (.leftEar, 7), (.rightEar, 8),
                (.leftShoulder, 11), (.rightShoulder, 12), (.leftElbow, 13), (.rightElbow, 14),
                (.leftWrist, 15), (.rightWrist, 16), (.leftHip, 23), (.rightHip, 24),
                (.leftKnee, 25), (.rightKnee, 26), (.leftAnkle, 27), (.rightAnkle, 28)]
            let visionPoints = try (visionRequest.results ?? []).prefix(4).map { observation in
                let joints = try observation.recognizedPoints(.all)
                var points = Array(repeating: PosePoint(x: 0, y: 0, visibility: 0, presence: 0), count: 33)
                for (joint, index) in mapping {
                    if let p = joints[joint] {
                        points[index] = PosePoint(x: p.location.x, y: 1 - p.location.y,
                                                  visibility: Double(p.confidence), presence: Double(p.confidence))
                    }
                }
                return points
            }
            geometrySets = visionPoints
            pointSets = hybrid ? try visionPoints.map { try refine($0, pixelBuffer: pixelBuffer) } : visionPoints
        } else if let landmarker {
            let image = try MPImage(sampleBuffer: sampleBuffer)
            let result = try independentFrames ? landmarker.detect(image: image)
                : landmarker.detect(videoFrame: image, timestampInMilliseconds: Int(timestamp * 1_000))
            pointSets = result.landmarks.map { pose in
                pose.map { PosePoint(x: Double($0.x), y: Double($0.y), visibility: $0.visibility?.doubleValue ?? 0,
                                     presence: $0.presence?.doubleValue ?? 0) }
            }
        } else { pointSets = [] }
        var frames: [PoseFrame] = []
        var candidates: [PoseCandidate] = []
        for (index, points) in pointSets.enumerated() {
        // Índices BlazePose: ancas 23/24, joelhos 25/26, tornozelos 27/28.
        // Na vista lateral, o lado oposto pode estar oculto. Escolha somente um
        // trio de articulações visível; a confiança não é inventada nem diluída
        // pelos pontos do lado oculto.
            let left = side(hip: points[safe: 23], knee: points[safe: 25], ankle: points[safe: 27], aspectRatio: aspectRatio)
            let right = side(hip: points[safe: 24], knee: points[safe: 26], ankle: points[safe: 28], aspectRatio: aspectRatio)
            let chosen = [left, right].compactMap { $0 }.max { $0.confidence < $1.confidence }
            frames.append(PoseFrame(landmarks: points, confidence: chosen?.confidence ?? 0,
                                    kneeAngle: chosen?.angle, imageAspectRatio: aspectRatio))
            let geometryPoints = geometrySets?[index] ?? points
            let visible = geometryPoints.filter { min($0.visibility, $0.presence) >= 0.5 &&
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

    private func refine(_ points: [PosePoint], pixelBuffer: CVPixelBuffer) throws -> [PosePoint] {
        guard let landmarker else { return [] }
        let valid = points.filter { $0.visibility >= 0.3 }
        guard let x0 = valid.map(\.x).min(), let x1 = valid.map(\.x).max(),
              let y0 = valid.map(\.y).min(), let y1 = valid.map(\.y).max() else { return [] }
        let padX = max(0.04, (x1 - x0) * 0.2)
        let padY = max(0.03, (y1 - y0) * 0.1)
        let left = max(0, x0 - padX), right = min(1, x1 + padX)
        let top = max(0, y0 - padY), bottom = min(1, y1 + padY)
        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))
        let rect = CGRect(x: left * width, y: (1 - bottom) * height,
                          width: (right - left) * width, height: (bottom - top) * height).integral
        guard let cgImage = imageContext.createCGImage(CIImage(cvPixelBuffer: pixelBuffer), from: rect) else { return [] }
        let result = try landmarker.detect(image: MPImage(uiImage: UIImage(cgImage: cgImage)))
        guard let pose = result.landmarks.first else { return [] }
        let actualLeft = rect.minX / width
        let actualTop = 1 - rect.maxY / height
        return pose.map {
            PosePoint(x: actualLeft + Double($0.x) * rect.width / width,
                      y: actualTop + Double($0.y) * rect.height / height,
                      visibility: $0.visibility?.doubleValue ?? 0,
                      presence: $0.presence?.doubleValue ?? 0)
        }
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
