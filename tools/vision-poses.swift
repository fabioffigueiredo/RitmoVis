// Extracts sparse, local-only body observations for dataset curation.
// Usage: swift tools/vision-poses.swift VIDEO SAMPLE_PERIOD_SECONDS > private.jsonl
import AVFoundation
import Foundation
import Vision

struct Point: Codable {
    let x: Double
    let y: Double
    let confidence: Double
}

struct Person: Codable {
    let index: Int
    let confidence: Double
    let centerX: Double?
    let centerY: Double?
    let width: Double?
    let height: Double?
    let kneeAngle: Double?
    let points: [String: Point]
}

struct Frame: Codable {
    let timeSeconds: Double
    let people: [Person]
}

let names: [(String, VNHumanBodyPoseObservation.JointName)] = [
    ("nose", .nose), ("leftShoulder", .leftShoulder), ("rightShoulder", .rightShoulder),
    ("leftHip", .leftHip), ("rightHip", .rightHip),
    ("leftKnee", .leftKnee), ("rightKnee", .rightKnee),
    ("leftAnkle", .leftAnkle), ("rightAnkle", .rightAnkle)
]

func angle(_ hip: Point?, _ knee: Point?, _ ankle: Point?, aspect: Double) -> Double? {
    guard let hip, let knee, let ankle,
          min(hip.confidence, knee.confidence, ankle.confidence) >= 0.55 else { return nil }
    let a = atan2(hip.y - knee.y, (hip.x - knee.x) * aspect)
    let b = atan2(ankle.y - knee.y, (ankle.x - knee.x) * aspect)
    var degrees = abs((a - b) * 180 / .pi)
    if degrees > 180 { degrees = 360 - degrees }
    return degrees
}

guard CommandLine.arguments.count == 3,
      let period = Double(CommandLine.arguments[2]), period > 0, period.isFinite else {
    fputs("Usage: swift vision-poses.swift VIDEO SAMPLE_PERIOD_SECONDS\n", stderr)
    exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: url)
guard let track = asset.tracks(withMediaType: .video).first else {
    fputs("Video track missing\n", stderr); exit(2)
}
do {
    let reader = try AVAssetReader(asset: asset)
    let pixelSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    let output: AVAssetReaderOutput
    if track.preferredTransform.isIdentity {
        output = AVAssetReaderTrackOutput(track: track, outputSettings: pixelSettings)
    } else {
        let oriented = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: pixelSettings)
        oriented.videoComposition = AVMutableVideoComposition(propertiesOf: asset)
        output = oriented
    }
    guard reader.canAdd(output) else { throw NSError(domain: "RitmoVis", code: 1) }
    reader.add(output)
    guard reader.startReading() else { throw reader.error ?? NSError(domain: "RitmoVis", code: 2) }
    let request = VNDetectHumanBodyPoseRequest()
    let encoder = JSONEncoder()
    var nextTime = 0.0
    var sampled = 0
    while let sample = output.copyNextSampleBuffer() {
        let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
        guard time.isFinite, time + 0.0001 >= nextTime,
              let pixel = CMSampleBufferGetImageBuffer(sample) else { continue }
        nextTime = time + period
        let aspect = Double(CVPixelBufferGetWidth(pixel)) / Double(CVPixelBufferGetHeight(pixel))
        try VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .up).perform([request])
        let people: [Person] = try (request.results ?? []).enumerated().map { index, observation in
            let joints = try observation.recognizedPoints(.all)
            let points = Dictionary(uniqueKeysWithValues: names.compactMap { name, joint -> (String, Point)? in
                guard let point = joints[joint] else { return nil }
                return (name, Point(x: Double(point.location.x), y: 1 - Double(point.location.y),
                                    confidence: Double(point.confidence)))
            })
            let visible = points.values.filter { $0.confidence >= 0.5 }
            let minX = visible.map(\.x).min(), maxX = visible.map(\.x).max()
            let minY = visible.map(\.y).min(), maxY = visible.map(\.y).max()
            let left = angle(points["leftHip"], points["leftKnee"], points["leftAnkle"], aspect: aspect)
            let right = angle(points["rightHip"], points["rightKnee"], points["rightAnkle"], aspect: aspect)
            let kneeAngle = [left, right].compactMap { $0 }.max()
            return Person(index: index, confidence: Double(observation.confidence),
                          centerX: minX.flatMap { lo in maxX.map { (lo + $0) / 2 } },
                          centerY: minY.flatMap { lo in maxY.map { (lo + $0) / 2 } },
                          width: minX.flatMap { lo in maxX.map { $0 - lo } },
                          height: minY.flatMap { lo in maxY.map { $0 - lo } },
                          kneeAngle: kneeAngle, points: points)
        }
        var line = try encoder.encode(Frame(timeSeconds: time, people: people))
        line.append(0x0A)
        FileHandle.standardOutput.write(line)
        sampled += 1
    }
    guard reader.status == .completed else { throw reader.error ?? NSError(domain: "RitmoVis", code: 3) }
    fputs("Sampled \(sampled) frames\n", stderr)
} catch {
    fputs("Vision extraction failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
