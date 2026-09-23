import Foundation

/// The persistence state of a workout entry.
public enum WorkoutRecordStatus: String, Codable, Sendable {
    case completed
    case legacyVideoOnly
}

/// Metadata retained for a completed workout or an imported legacy recording.
public struct WorkoutRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let exercise: String
    public let target: Int
    public let repetitions: Int
    public let elapsedSeconds: TimeInterval
    public let model: String
    public let camera: String
    public let videoFileName: String?
    public let replayFileName: String?
    public let processedFrames: Int?
    public let noPoseFrames: Int?
    public let status: WorkoutRecordStatus

    /// `nil` means an older record has no observation data; `false` means no usable pose was seen.
    public var hasUsablePose: Bool? {
        guard let processedFrames, let noPoseFrames else { return nil }
        return processedFrames > noPoseFrames
    }

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        exercise: String,
        target: Int,
        repetitions: Int,
        elapsedSeconds: TimeInterval,
        model: String,
        camera: String,
        videoFileName: String? = nil,
        replayFileName: String? = nil,
        processedFrames: Int? = nil,
        noPoseFrames: Int? = nil,
        status: WorkoutRecordStatus = .completed
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercise = exercise
        self.target = target
        self.repetitions = repetitions
        self.elapsedSeconds = elapsedSeconds
        self.model = model
        self.camera = camera
        self.videoFileName = videoFileName
        self.replayFileName = replayFileName
        self.processedFrames = processedFrames
        self.noPoseFrames = noPoseFrames
        self.status = status
    }
}

/// A normalized point from a pose landmark set.
public struct ReplayPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A pose snapshot used to replay a completed workout.
public struct ReplaySample: Codable, Equatable, Sendable {
    public typealias Point = ReplayPoint

    public let relativeTime: TimeInterval
    public let count: Int
    public let phase: String
    public let landmarks: [ReplayPoint]
    public let imageAspectRatio: Double

    public init(
        relativeTime: TimeInterval,
        count: Int,
        phase: String,
        landmarks: [ReplayPoint],
        imageAspectRatio: Double
    ) {
        self.relativeTime = relativeTime
        self.count = count
        self.phase = phase
        self.landmarks = landmarks
        self.imageAspectRatio = imageAspectRatio
    }
}

/// Errors returned when an individual replay sidecar cannot be read or addressed safely.
public enum WorkoutHistoryError: Error, Equatable, Sendable {
    case corruptIndex
    case replayUnavailable(UUID)
    case invalidFileName(String)
}

/// File-backed workout history rooted at the caller-provided Documents directory.
///
/// Metadata is stored in `WorkoutHistory/index.json`, replay sidecars in
/// `WorkoutHistory/Replay`, and optional videos in `Gravacoes`.
public struct WorkoutHistoryStore: Sendable {
    private let documentsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(documentsURL: URL) {
        self.documentsURL = documentsURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Returns indexed records. A missing or corrupt index is treated as an empty history.
    public func load() -> [WorkoutRecord] {
        guard let data = try? Data(contentsOf: indexURL),
              let records = try? decoder.decode([WorkoutRecord].self, from: data) else {
            return []
        }
        return records
    }

    /// Atomically writes a record's replay sidecar before making its metadata visible in the index.
    public func save(record: WorkoutRecord, samples: [ReplaySample]) throws {
        var records = try readIndexForMutation()
        let replayURL = try replayURL(for: record)
        try createDirectoryIfNeeded(at: replayURL.deletingLastPathComponent())
        try writeAtomically(samples, to: replayURL)

        if let videoFileName = record.videoFileName {
            records.removeAll {
                $0.status == .legacyVideoOnly && $0.videoFileName == videoFileName
            }
        }
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        try writeIndex(records)
    }

    /// Reads a record's replay samples. Missing or corrupt sidecars are reported as unavailable.
    public func samples(for record: WorkoutRecord) throws -> [ReplaySample] {
        let url = try replayURL(for: record)
        guard let data = try? Data(contentsOf: url),
              let samples = try? decoder.decode([ReplaySample].self, from: data) else {
            throw WorkoutHistoryError.replayUnavailable(record.id)
        }
        return samples
    }

    /// Removes the record from metadata and removes only its exact replay/video filenames.
    public func delete(record: WorkoutRecord) throws {
        var records = try readIndexForMutation()
        records.removeAll { $0.id == record.id }
        try writeIndex(records)

        try removeIfPresent(at: replayURL(for: record))
        if let videoFileName = record.videoFileName {
            try removeIfPresent(at: try recordingsURL.appendingSafeFileName(videoFileName))
        }
    }

    /// Adds one metadata-only record for each unindexed `.mov` found in `Gravacoes`.
    /// Calling this again without new videos makes no changes and returns an empty array.
    public func discoverLegacyVideos() throws -> [WorkoutRecord] {
        guard FileManager.default.fileExists(atPath: recordingsURL.path) else { return [] }

        var records = try readIndexForMutation()
        let indexedNames = Set(records.compactMap(\.videoFileName))
        let urls = try FileManager.default.contentsOfDirectory(
            at: recordingsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let videos = urls.filter { url in
            url.pathExtension.lowercased() == "mov"
                && (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                && !indexedNames.contains(url.lastPathComponent)
        }

        let discovered = videos.map { url -> WorkoutRecord in
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            return WorkoutRecord(
                startedAt: modifiedAt,
                endedAt: modifiedAt,
                exercise: "Vídeo legado",
                target: 0,
                repetitions: 0,
                elapsedSeconds: 0,
                model: "desconhecido",
                camera: "desconhecida",
                videoFileName: url.lastPathComponent,
                replayFileName: nil,
                status: .legacyVideoOnly
            )
        }
        guard !discovered.isEmpty else { return [] }

        records.append(contentsOf: discovered)
        try writeIndex(records)
        return discovered
    }

    private var historyURL: URL {
        documentsURL.appendingPathComponent("WorkoutHistory", isDirectory: true)
    }

    private var indexURL: URL {
        historyURL.appendingPathComponent("index.json", isDirectory: false)
    }

    private var replayDirectoryURL: URL {
        historyURL.appendingPathComponent("Replay", isDirectory: true)
    }

    private var recordingsURL: URL {
        documentsURL.appendingPathComponent("Gravacoes", isDirectory: true)
    }

    private func replayURL(for record: WorkoutRecord) throws -> URL {
        let name = record.replayFileName ?? "\(record.id.uuidString).json"
        return try replayDirectoryURL.appendingSafeFileName(name)
    }

    private func writeIndex(_ records: [WorkoutRecord]) throws {
        try createDirectoryIfNeeded(at: historyURL)
        try writeAtomically(records, to: indexURL)
    }

    private func readIndexForMutation() throws -> [WorkoutRecord] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return [] }
        let data = try Data(contentsOf: indexURL)
        do {
            return try decoder.decode([WorkoutRecord].self, from: data)
        } catch {
            throw WorkoutHistoryError.corruptIndex
        }
    }

    private func createDirectoryIfNeeded(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func writeAtomically<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func removeIfPresent(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

private extension URL {
    func appendingSafeFileName(_ fileName: String) throws -> URL {
        guard !fileName.isEmpty,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              fileName != ".", fileName != ".." else {
            throw WorkoutHistoryError.invalidFileName(fileName)
        }
        return appendingPathComponent(fileName, isDirectory: false)
    }
}
