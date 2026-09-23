import Foundation
import XCTest
@testable import SquatCounterCore

final class WorkoutHistoryTests: XCTestCase {
    private var documentsURL: URL!

    override func setUpWithError() throws {
        documentsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkoutHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: documentsURL)
        documentsURL = nil
    }

    func testSavePersistsRecordAndReplaySamples() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let record = makeRecord()
        let samples = [
            ReplaySample(relativeTime: 0.25, count: 2, phase: "ascending", landmarks: [.init(x: 0.2, y: 0.8)], imageAspectRatio: 16.0 / 9.0)
        ]

        try store.save(record: record, samples: samples)

        XCTAssertEqual(store.load(), [record])
        XCTAssertEqual(try store.samples(for: record), samples)
    }

    func testObservationCountsPersistWithoutChangingOldRecords() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let unassessed = WorkoutRecord(
            startedAt: Date(timeIntervalSince1970: 100), endedAt: Date(timeIntervalSince1970: 112),
            exercise: "Agachamento livre", target: 12, repetitions: 0, elapsedSeconds: 12,
            model: "lite", camera: "back", processedFrames: 300, noPoseFrames: 300
        )
        try store.save(record: unassessed, samples: [])
        XCTAssertEqual(store.load().first?.hasUsablePose, false)

        let oldRecord = makeRecord()
        let encoded = try JSONEncoder().encode([oldRecord])
        let indexURL = documentsURL.appendingPathComponent("WorkoutHistory/index.json")
        try encoded.write(to: indexURL, options: .atomic)
        XCTAssertNil(store.load().first?.hasUsablePose)
    }

    func testDeleteRemovesMetadataAndReplayWithoutTouchingAnUnrelatedVideo() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let record = makeRecord(videoFileName: "session.mov")
        let unrelatedVideo = documentsURL.appendingPathComponent("Gravacoes/keep.mov")
        try FileManager.default.createDirectory(at: unrelatedVideo.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: unrelatedVideo)
        try store.save(record: record, samples: [])

        try store.delete(record: record)

        XCTAssertEqual(store.load(), [])
        XCTAssertThrowsError(try store.samples(for: record))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedVideo.path))
    }

    func testDiscoverLegacyVideosAddsOnlyUnindexedMoviesAndIsIdempotent() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let recordings = documentsURL.appendingPathComponent("Gravacoes", isDirectory: true)
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        try Data().write(to: recordings.appendingPathComponent("legacy.mov"))
        try Data().write(to: recordings.appendingPathComponent("ignore.mp4"))
        let indexedRecord = makeRecord(videoFileName: "known.mov")
        try Data().write(to: recordings.appendingPathComponent("known.mov"))
        try store.save(record: indexedRecord, samples: [])

        let discovered = try store.discoverLegacyVideos()

        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered[0].status, .legacyVideoOnly)
        XCTAssertEqual(discovered[0].videoFileName, "legacy.mov")
        XCTAssertEqual(discovered[0].repetitions, 0)
        XCTAssertEqual(discovered[0].target, 0)
        XCTAssertTrue((try store.discoverLegacyVideos()).isEmpty)
        XCTAssertEqual(store.load().count, 2)
    }

    func testLoadSkipsCorruptReplaySidecarAndSamplesReportsItAsUnavailable() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let record = makeRecord()
        try store.save(record: record, samples: [])
        let replayURL = documentsURL.appendingPathComponent("WorkoutHistory/Replay/\(record.id.uuidString).json")
        try Data("not json".utf8).write(to: replayURL, options: .atomic)

        XCTAssertEqual(store.load(), [record])
        XCTAssertThrowsError(try store.samples(for: record))
    }

    func testLoadReturnsNoRecordsWhenIndexIsCorrupt() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let indexURL = documentsURL.appendingPathComponent("WorkoutHistory/index.json")
        try FileManager.default.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: indexURL)

        XCTAssertEqual(store.load(), [])
    }

    func testSaveDoesNotOverwriteACorruptIndex() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let indexURL = documentsURL.appendingPathComponent("WorkoutHistory/index.json")
        try FileManager.default.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corruptData = Data("not json".utf8)
        try corruptData.write(to: indexURL)

        XCTAssertThrowsError(try store.save(record: makeRecord(), samples: []))
        XCTAssertEqual(try Data(contentsOf: indexURL), corruptData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: documentsURL.appendingPathComponent("WorkoutHistory/Replay/00000000-0000-0000-0000-000000000001.json").path))
    }

    func testSaveReplacesAnImportedLegacyRecordForTheSameVideo() throws {
        let store = WorkoutHistoryStore(documentsURL: documentsURL)
        let recordings = documentsURL.appendingPathComponent("Gravacoes", isDirectory: true)
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        try Data().write(to: recordings.appendingPathComponent("interrupted.mov"))
        XCTAssertEqual(try store.discoverLegacyVideos().count, 1)

        let completed = makeRecord(videoFileName: "interrupted.mov")
        try store.save(record: completed, samples: [])

        XCTAssertEqual(store.load(), [completed])
    }

    private func makeRecord(videoFileName: String? = nil) -> WorkoutRecord {
        WorkoutRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 130),
            exercise: "Agachamento livre",
            target: 12,
            repetitions: 9,
            elapsedSeconds: 30,
            model: "full",
            camera: "back",
            videoFileName: videoFileName,
            replayFileName: nil,
            status: .completed
        )
    }
}
