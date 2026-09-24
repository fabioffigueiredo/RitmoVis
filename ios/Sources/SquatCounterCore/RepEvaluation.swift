import Foundation

/// Manual labels refer to the source video's timeline, not wall-clock time.
public struct RepAnnotation: Codable, Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let completed: Bool

    public init(startSeconds: Double, endSeconds: Double, completed: Bool) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.completed = completed
    }
}

public struct RepEvaluationInput: Codable, Sendable {
    public let schemaVersion: Int
    public let clipID: String
    public let toleranceSeconds: Double
    public let annotations: [RepAnnotation]
    public let detectedAtSeconds: [Double]

    public init(schemaVersion: Int = 1, clipID: String, toleranceSeconds: Double,
                annotations: [RepAnnotation], detectedAtSeconds: [Double]) {
        self.schemaVersion = schemaVersion
        self.clipID = clipID
        self.toleranceSeconds = toleranceSeconds
        self.annotations = annotations
        self.detectedAtSeconds = detectedAtSeconds
    }
}

public struct RepEvaluationResult: Codable, Equatable, Sendable {
    public let clipID: String
    public let annotatedComplete: Int
    public let annotatedIncomplete: Int
    public let detected: Int
    public let truePositives: Int
    public let falsePositives: Int
    public let falseNegatives: Int
    public let falsePositivesDuringIncompleteAttempts: Int
    public let falsePositiveTimes: [Double]
    public let missedCompletionTimes: [Double]
    public let meanAbsoluteTimingErrorSeconds: Double?
    public let precision: Double?
    public let recall: Double?
}

public enum RepEvaluationError: Error, LocalizedError, Equatable {
    case unsupportedSchema
    case invalidClipID
    case invalidTolerance
    case invalidAnnotation
    case overlappingAnnotations
    case invalidDetectionTime

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "Versão de anotação não suportada"
        case .invalidClipID: "Identificador do clipe vazio"
        case .invalidTolerance: "Tolerância temporal inválida"
        case .invalidAnnotation: "Anotação com intervalo inválido"
        case .overlappingAnnotations: "Anotações de uma pessoa não podem se sobrepor"
        case .invalidDetectionTime: "Evento detectado com tempo inválido"
        }
    }
}

/// Chronological, one-to-one matching within an explicitly supplied tolerance.
/// Counts are per clip and are not an estimate of general model accuracy.
public enum RepEvaluator {
    public static func evaluate(_ input: RepEvaluationInput) throws -> RepEvaluationResult {
        guard input.schemaVersion == 1 else { throw RepEvaluationError.unsupportedSchema }
        guard !input.clipID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepEvaluationError.invalidClipID
        }
        guard input.toleranceSeconds.isFinite, input.toleranceSeconds >= 0 else {
            throw RepEvaluationError.invalidTolerance
        }
        let annotations = input.annotations.sorted { $0.startSeconds < $1.startSeconds }
        for (index, annotation) in annotations.enumerated() {
            guard annotation.startSeconds.isFinite, annotation.endSeconds.isFinite,
                  annotation.startSeconds >= 0, annotation.endSeconds > annotation.startSeconds else {
                throw RepEvaluationError.invalidAnnotation
            }
            if index > 0 && annotation.startSeconds < annotations[index - 1].endSeconds {
                throw RepEvaluationError.overlappingAnnotations
            }
        }
        guard input.detectedAtSeconds.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw RepEvaluationError.invalidDetectionTime
        }

        let complete = annotations.filter(\.completed).map(\.endSeconds)
        let incomplete = annotations.filter { !$0.completed }
        let detected = input.detectedAtSeconds.sorted()
        var expectedIndex = 0
        var detectedIndex = 0
        var matchedErrors: [Double] = []
        var falsePositiveTimes: [Double] = []
        var missedTimes: [Double] = []

        while expectedIndex < complete.count && detectedIndex < detected.count {
            let expected = complete[expectedIndex]
            let actual = detected[detectedIndex]
            if actual < expected - input.toleranceSeconds {
                falsePositiveTimes.append(actual)
                detectedIndex += 1
            } else if actual > expected + input.toleranceSeconds {
                missedTimes.append(expected)
                expectedIndex += 1
            } else {
                matchedErrors.append(abs(actual - expected))
                expectedIndex += 1
                detectedIndex += 1
            }
        }
        missedTimes.append(contentsOf: complete.dropFirst(expectedIndex))
        falsePositiveTimes.append(contentsOf: detected.dropFirst(detectedIndex))
        let tp = matchedErrors.count
        let fp = falsePositiveTimes.count
        let fn = missedTimes.count
        return RepEvaluationResult(
            clipID: input.clipID,
            annotatedComplete: complete.count,
            annotatedIncomplete: incomplete.count,
            detected: detected.count,
            truePositives: tp,
            falsePositives: fp,
            falseNegatives: fn,
            falsePositivesDuringIncompleteAttempts: falsePositiveTimes.filter { time in
                incomplete.contains { time >= $0.startSeconds && time <= $0.endSeconds }
            }.count,
            falsePositiveTimes: falsePositiveTimes,
            missedCompletionTimes: missedTimes,
            meanAbsoluteTimingErrorSeconds: tp == 0 ? nil : matchedErrors.reduce(0, +) / Double(tp),
            precision: tp + fp == 0 ? nil : Double(tp) / Double(tp + fp),
            recall: tp + fn == 0 ? nil : Double(tp) / Double(tp + fn)
        )
    }
}
