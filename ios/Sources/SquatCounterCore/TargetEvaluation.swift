import Foundation

/// Human-reviewed visibility of the explicitly selected target, not a detector prediction.
public enum TargetObservability: String, Codable, Sendable {
    case observable
    case unobservable
    case absent
}

/// `selectedTrackID` is assigned by an annotator from the predicted box; it is not a face or account ID.
public struct TargetEvaluationSample: Codable, Sendable {
    public let timeSeconds: Double
    public let observability: TargetObservability
    public let selectedTrackID: String?
    public let creditedRepetition: Bool

    public init(timeSeconds: Double, observability: TargetObservability,
                selectedTrackID: String?, creditedRepetition: Bool) {
        self.timeSeconds = timeSeconds
        self.observability = observability
        self.selectedTrackID = selectedTrackID
        self.creditedRepetition = creditedRepetition
    }
}

public struct TargetEvaluationInput: Codable, Sendable {
    public let schemaVersion: Int
    public let clipID: String
    public let targetTrackID: String
    public let samples: [TargetEvaluationSample]

    public init(schemaVersion: Int = 1, clipID: String, targetTrackID: String,
                samples: [TargetEvaluationSample]) {
        self.schemaVersion = schemaVersion
        self.clipID = clipID
        self.targetTrackID = targetTrackID
        self.samples = samples
    }
}

public struct TargetEvaluationResult: Codable, Sendable {
    public let clipID: String
    public let totalSamples: Int
    public let observableSamples: Int
    public let correctTargetSamples: Int
    public let wrongPersonSamples: Int
    public let unsafeSelections: Int
    public let wrongPersonCredits: Int
    public let coverage: Double?
}

public enum TargetEvaluationError: Error, Equatable {
    case invalidMetadata
    case invalidSample
}

/// Scores association independently from squat timing. No human labels means no accuracy score.
public enum TargetEvaluator {
    public static func evaluate(_ input: TargetEvaluationInput) throws -> TargetEvaluationResult {
        let target = input.targetTrackID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.schemaVersion == 1,
              !input.clipID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !target.isEmpty else { throw TargetEvaluationError.invalidMetadata }

        var previous = -Double.infinity
        for sample in input.samples {
            guard sample.timeSeconds.isFinite, sample.timeSeconds >= 0,
                  sample.timeSeconds > previous,
                  !sample.creditedRepetition || sample.selectedTrackID != nil,
                  sample.selectedTrackID.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true
            else { throw TargetEvaluationError.invalidSample }
            previous = sample.timeSeconds
        }

        let observable = input.samples.filter { $0.observability == .observable }
        let correct = observable.filter { $0.selectedTrackID == target }.count
        let wrong = input.samples.filter { $0.selectedTrackID != nil && $0.selectedTrackID != target }.count
        let unsafe = input.samples.filter { $0.observability != .observable && $0.selectedTrackID != nil }.count
        let wrongCredits = input.samples.filter {
            $0.creditedRepetition && $0.selectedTrackID != target
        }.count
        return TargetEvaluationResult(
            clipID: input.clipID, totalSamples: input.samples.count,
            observableSamples: observable.count, correctTargetSamples: correct,
            wrongPersonSamples: wrong, unsafeSelections: unsafe,
            wrongPersonCredits: wrongCredits,
            coverage: observable.isEmpty ? nil : Double(correct) / Double(observable.count)
        )
    }
}
