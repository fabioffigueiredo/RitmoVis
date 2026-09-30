import AVFoundation
import MediaPipeTasksVision
import SquatCounterCore

struct DetectedHand {
    let x: Double
    let y: Double
    let gesture: HandGesture
    let confidence: Double
}

/// Local, experimental static-hand recognition. Only a visible body wrist may own a command.
final class HandGestureDetector {
    private let recognizer: GestureRecognizer

    init() throws {
        guard let path = Bundle.main.path(forResource: "gesture_recognizer", ofType: "task") else {
            throw NSError(domain: "RitmoVis", code: 20,
                          userInfo: [NSLocalizedDescriptionKey: "Modelo de gestos ausente. Desative os gestos e use Selecionar."])
        }
        let options = GestureRecognizerOptions()
        options.baseOptions.modelAssetPath = path
        options.runningMode = .video
        options.numHands = 4
        options.minHandDetectionConfidence = 0.6
        options.minHandPresenceConfidence = 0.6
        options.minTrackingConfidence = 0.6
        recognizer = try GestureRecognizer(options: options)
    }

    func detect(_ buffer: CMSampleBuffer, batch: PoseDetectionBatch,
                timestamp: TimeInterval) throws -> [GestureObservation] {
        let hands = try recognizeHands(buffer, timestamp: timestamp)
        // Partial bodies may not be selectable, but their visible wrists still
        // make hand ownership ambiguous. Do not discard this evidence upstream.
        let wrists: [GestureBodyWrist] = batch.poses.enumerated().flatMap { index, pose in
            return [(15, 11), (16, 12)].compactMap { wristIndex, shoulderIndex in
                guard pose.landmarks.indices.contains(wristIndex),
                      pose.landmarks.indices.contains(shoulderIndex) else { return nil }
                let wrist = pose.landmarks[wristIndex], shoulder = pose.landmarks[shoulderIndex]
                return GestureBodyWrist(candidateIndex: index, x: wrist.x, y: wrist.y,
                    shoulderY: shoulder.y,
                    confidence: min(wrist.visibility, wrist.presence),
                    bodyUsable: pose.kneeAngle != nil && pose.confidence >= 0.55 &&
                        min(shoulder.visibility, shoulder.presence) >= 0.55)
            }
        }
        return hands.compactMap { hand in
            guard let owner = HandGestureAssociation.candidateIndex(handX: hand.x,
                      handY: hand.y, bodyWrists: wrists, aspectRatio: batch.imageAspectRatio),
                  let candidate = batch.candidates.first(where: { $0.index == owner }) else { return nil }
            return .init(gesture: hand.gesture, confidence: hand.confidence,
                         candidate: candidate, isAboveShoulder: true)
        }
    }

    /// Same video-mode inference path used by capture; exposed internally for model integration QA.
    func recognizeHands(_ buffer: CMSampleBuffer, timestamp: TimeInterval) throws -> [DetectedHand] {
        let image = try MPImage(sampleBuffer: buffer)
        let result = try recognizer.recognize(videoFrame: image,
                                              timestampInMilliseconds: Int(timestamp * 1_000))
        return result.landmarks.enumerated().compactMap { handIndex, landmarks in
            guard let wrist = landmarks.first, result.gestures.indices.contains(handIndex),
                  let category = result.gestures[handIndex].max(by: { $0.score < $1.score }) else { return nil }
            let gesture: HandGesture
            switch category.categoryName {
            case "Open_Palm": gesture = .openPalm
            case "Closed_Fist": gesture = .closedFist
            default: gesture = .unknown
            }
            return .init(x: Double(wrist.x), y: Double(wrist.y), gesture: gesture,
                         confidence: Double(category.score))
        }
    }
}
