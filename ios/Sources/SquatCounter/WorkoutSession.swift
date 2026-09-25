@preconcurrency import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SquatCounterCore

enum PoseModel: String { case lite, full }

enum CameraChoice: String, CaseIterable, Identifiable {
    case back, front

    var id: String { rawValue }
    var title: String { self == .back ? "Traseira" : "Frontal" }
    var position: AVCaptureDevice.Position { self == .back ? .back : .front }
}

private extension SquatPhase {
    var displayText: String {
        switch self {
        case .unknown: "Aguardando posição"
        case .standing: "Em pé"
        case .descending: "Descendo"
        case .bottom: "Embaixo"
        case .ascending: "Subindo"
        case .trackingLost: "Pessoa fora do quadro"
        }
    }
}

struct BenchmarkMetrics: Codable, Sendable {
    var processedFrames = 0
    var droppedFrames = 0
    var noPoseFrames = 0
    var nearBlackFrames = 0
    var consecutiveNearBlackFrames = 0
    var meanLatencyMs = 0.0
    var p95LatencyMs = 0.0
    var elapsedSeconds = 0.0
    var processedFPS = 0.0
    var inputWidth = 0
    var inputHeight = 0
}

#if DEBUG
private struct QACameraReport: Codable {
    let recordedAt: Date
    let camera: String
    let model: String
    let timing: CameraStartupTiming
    let metrics: BenchmarkMetrics
    let warning: String?
    let captureRunning: Bool
    let captureInterrupted: Bool
    let captureEvents: [String]
}

private struct QAClipReport: Codable {
    let recordedAt: Date
    let model: String
    let calibration: String
    let source: String
    let repetitions: Int
    let events: [RepEvent]
    let metrics: BenchmarkMetrics
    let framesWithMultipleCandidates: Int
    let maximumCandidates: Int
    let framesWithoutSelection: Int
    let groupRequiresSelection: Bool
    let selectionRequested: Bool
    let selectedFrames: Int
    let uncertainFrames: Int
    let reselectionFrames: Int
    let diagnostics: ClipDiagnosticSummary
    let trace: [QATrackingFrame]?
}

private struct QATrackingFrame: Codable {
    let pts: Double
    let candidates: [PoseCandidate]
    let decision: String
    let angle: Double?
}
#endif

struct WorkoutSummary {
    let repetitions: Int
    let target: Int
    let elapsedSeconds: TimeInterval
    let noPoseFrames: Int?
    let processedFrames: Int?

    var remaining: Int { max(0, target - repetitions) }
    var couldNotAssess: Bool {
        guard let noPoseFrames, let processedFrames else { return false }
        return processedFrames == 0 || noPoseFrames >= processedFrames
    }
}

struct SelectedVideo: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let suffix = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(suffix)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return .init(url: copy)
        }
    }
}

private struct TimedPose: Sendable {
    let pts: TimeInterval
    let frame: PoseFrame
    let candidates: [PoseCandidate]
    let tracking: TrackingDecision
    let count: Int
    let phase: String
    let event: RepEvent?
    let metrics: BenchmarkMetrics
    var poseOptions: [PoseFrame] = []
}

private final class CameraFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var worker: InferenceWorker?
    private var firstFrameHandler: (@Sendable (TimeInterval) -> Void)?
    func setWorker(_ worker: InferenceWorker?) {
        lock.lock(); self.worker = worker; lock.unlock()
    }
    func setFirstFrameHandler(_ handler: (@Sendable (TimeInterval) -> Void)?) {
        lock.lock(); firstFrameHandler = handler; lock.unlock()
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lock.lock()
        let current = worker
        let handler = firstFrameHandler
        firstFrameHandler = nil
        lock.unlock()
        handler?(ProcessInfo.processInfo.systemUptime)
        current?.enqueue(sampleBuffer)
    }
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lock.lock(); let current = worker; lock.unlock()
        current?.recordCaptureDrop()
    }
}

private final class CaptureSessionBox: @unchecked Sendable {
    let value: AVCaptureSession
    init(_ value: AVCaptureSession) { self.value = value }
}

@MainActor final class WorkoutSession: NSObject, ObservableObject {
    private let nearBlackWarning = "A câmera está entregando quadros pretos. Confira luz e lentes. Se estiver testando pelo Xcode, tente sem o pareamento ativo."
    let captureSession = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let frameDelegate = CameraFrameDelegate()
    private let cameraQueue = DispatchQueue(label: "camera.lifecycle")
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    @Published var repetitions = 0
    @Published var phaseText = "Aguardando pose"
    @Published var landmarks: [CGPoint] = []
    @Published private(set) var targetCandidates: [PoseCandidate] = []
    @Published private(set) var trackingDecision: TrackingDecision = .noSelection
    @Published private(set) var importedVideoHasMultiplePeople = false
    @Published private(set) var isChoosingVideoPerson = false
    @Published private(set) var videoAnalysisNotice: String?
    @Published var imageAspectRatio = 1.0
    @Published var model: PoseModel = .lite
    @Published var useVisionForVideo = false
    @Published var calibrateSelectedStandingFrame = false
    @Published private(set) var videoBackendUsed = "MediaPipe"
    private var videoCalibrationUsed = "default-155-105"
    @Published var cameraChoice: CameraChoice = .back
    @Published var recordWorkout = false
    @Published var exercise: Exercise = .bodyweightSquat
    @Published var plan = WorkoutPlan()
    @Published var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var isCameraActive = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isFinalizingRecording = false
    @Published private(set) var isRecordingVideo = false
    @Published private(set) var replayURL: URL?
    @Published private(set) var workoutSummary: WorkoutSummary?
    @Published private(set) var modelUsed: PoseModel?
    @Published var videoPlayer: AVPlayer?
    @Published private(set) var processedFrames = 0
    @Published private(set) var droppedFrames = 0
    @Published private(set) var metrics = BenchmarkMetrics()
    @Published private(set) var events: [RepEvent] = []
    @Published private(set) var startedAt: Date?
    @Published private(set) var startupTiming = CameraStartupTiming()
    @Published private(set) var historyRecords: [WorkoutRecord] = []
    @Published private(set) var historyError: String?
    @Published private(set) var cameraWarning: String?
    @Published private(set) var startError: String?
    @Published private(set) var recordingNotice: String?
    @Published private(set) var isHistoricalReplay = false
    @Published private(set) var lockedPreviewAngle: CGFloat?

    private var worker: InferenceWorker?
    private var token = UUID()
    private var playerObserver: Any?
    private var videoResults: [TimedPose] = []
    private var rawImportedResults: [TimedPose] = []
    private var currentAnalyzedVideoURL: URL?
    private var currentVideoObservationPTS: TimeInterval?
    private var liveRecordingResults: [TimedPose] = []
    private var pendingRecordingResults: [TimedPose] = []
    private var pendingRecordingSummary: WorkoutSummary?
    private var recordingDelegate: WorkoutRecordingDelegate?
    private var activeRecordingURL: URL?
    private var recordingStartPTS: TimeInterval?
    private var recordingStartRequested = false
    private var stopRecordingWhenStarted = false
    private var pendingHistoryRecord: WorkoutRecord?
    private let historyStore = WorkoutHistoryStore(
        documentsURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    )
    private var captureObservers: [NSObjectProtocol] = []
    private var captureEventLog: [String] = []
    private var captureRotationPolicy = CaptureRotationPolicy()

    override init() {
        super.init()
        let center = NotificationCenter.default
        for name in [AVCaptureSession.wasInterruptedNotification,
                     AVCaptureSession.interruptionEndedNotification,
                     AVCaptureSession.runtimeErrorNotification] {
            captureObservers.append(center.addObserver(forName: name, object: captureSession, queue: .main) { [weak self] notification in
                let event = notification.name == AVCaptureSession.wasInterruptedNotification ? 0
                    : notification.name == AVCaptureSession.interruptionEndedNotification ? 1 : 2
                let reason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
                let error = (notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription
                Task { @MainActor [weak self] in
                    self?.handleCaptureNotification(event: event, reasonRaw: reason, errorMessage: error)
                }
            })
        }
    }

    deinit {
        for observer in captureObservers { NotificationCenter.default.removeObserver(observer) }
    }

    func startCamera() {
        guard !isRunning, !isStarting, !isFinalizingRecording else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--qa-synthetic-camera") {
            endSession()
            startupTiming.start(at: ProcessInfo.processInfo.systemUptime)
            isStarting = true
            phaseText = "Interface de teste sem câmera"
            if ProcessInfo.processInfo.arguments.contains("--qa-synthetic-targets") {
                imageAspectRatio = 9.0 / 16.0
                targetCandidates = [PoseCandidate(index: 0, centerX: 0.5, centerY: 0.5,
                                                  width: 0.3, height: 0.6, confidence: 0.9)]
                phaseText = "Toque na pessoa que será acompanhada — simulação de interface"
            }
            return
        }
        #endif
        endSession()
        startupTiming.start(at: ProcessInfo.processInfo.systemUptime)
        captureEventLog = []
        isStarting = true
        cameraWarning = nil
        startError = nil
        recordingNotice = nil
        replayURL = nil
        workoutSummary = nil
        liveRecordingResults = []
        pendingRecordingResults = []
        pendingRecordingSummary = nil
        pendingHistoryRecord = nil
        recordingStartPTS = nil
        recordingStartRequested = false
        stopRecordingWhenStarted = false
        let id = token
        Task { [self] in
            let requestedPermission = AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
            if requestedPermission { startupTiming.permissionRequested(at: ProcessInfo.processInfo.systemUptime) }
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                if token == id {
                    if requestedPermission { startupTiming.permissionResolved(at: ProcessInfo.processInfo.systemUptime) }
                    isStarting = false
                    phaseText = "Câmera não autorizada. Ative o acesso nos Ajustes do iPhone."
                    startError = phaseText
                }
                return
            }
            guard token == id else { return }
            if requestedPermission { startupTiming.permissionResolved(at: ProcessInfo.processInfo.systemUptime) }
            do {
                let box = CaptureSessionBox(captureSession)
                await withCheckedContinuation { continuation in
                    cameraQueue.async {
                        box.value.stopRunning()
                        continuation.resume()
                    }
                }
                guard token == id else { return }
                try configureCamera()
                try prepareWorker(id: id, videoURL: nil)
                if recordWorkout { try prepareRecording() }
                frameDelegate.setFirstFrameHandler { [weak self] uptime in
                    Task { @MainActor [weak self] in
                        guard let self, self.token == id else { return }
                        self.startupTiming.firstFrame(at: uptime)
                        self.startedAt = Date()
                        self.isStarting = false
                        self.isRunning = true
                    }
                }
                cameraQueue.async { [weak self] in
                    box.value.startRunning()
                    let started = box.value.isRunning
                    Task { @MainActor [weak self] in
                        guard let self, self.token == id else { return }
                        if !started {
                            self.stop()
                            self.phaseText = "Não foi possível iniciar a câmera"
                            self.startError = self.phaseText
                        } else {
                            self.startupTiming.captureRunning(at: ProcessInfo.processInfo.systemUptime)
                            self.setCameraActive(true)
                            if self.captureSession.isInterrupted {
                                self.cameraWarning = "Captura interrompida pelo iPhone. Feche outros usos da câmera e tente novamente."
                            }
                            if self.recordWorkout { self.beginRecording() }
                        }
                    }
                }
            } catch {
                isStarting = false
                phaseText = error.localizedDescription
                startError = "Não foi possível abrir a câmera: \(error.localizedDescription)"
            }
        }
    }

    func markLiveScreenVisible() {
        guard isStarting || isCameraActive else { return }
        startupTiming.visualResponse(at: ProcessInfo.processInfo.systemUptime)
    }

    func selectPerson(_ candidate: PoseCandidate) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--qa-synthetic-targets") && isStarting {
            trackingDecision = .selected(index: candidate.index)
            phaseText = "Pessoa acompanhada — simulação de interface"
            return
        }
        #endif
        guard isCameraActive else { return }
        worker?.selectPerson(candidate)
        phaseText = "Confirmando pessoa selecionada…"
    }

    func selectPersonInVideo(_ candidate: PoseCandidate) {
        guard !isAnalyzing, importedVideoHasMultiplePeople,
              let url = currentAnalyzedVideoURL,
              let timestamp = currentVideoObservationPTS,
              targetCandidates.contains(candidate), let player = videoPlayer,
              let selectedFrame = rawImportedResults.lastIndex(where: { $0.pts <= timestamp }) else { return }
        player.pause()
        let cached = rawImportedResults
        var counter = SquatCounter()
        if calibrateSelectedStandingFrame {
            guard cached[selectedFrame].poseOptions.indices.contains(candidate.index),
                  let angle = cached[selectedFrame].poseOptions[candidate.index].kneeAngle,
                  let calibrated = OfflineTargetAnalyzer.calibratedCounter(standingAngle: angle,
                    confidence: cached[selectedFrame].poseOptions[candidate.index].confidence) else {
                videoAnalysisNotice = "Referência insuficiente. Avance para um quadro em pé, com joelho visível, ou desative a calibração."
                return
            }
            counter = calibrated
            videoCalibrationUsed = "standing-reference-v1: top=\(counter.standingAngle), bottom=\(counter.bottomAngle)"
        } else { videoCalibrationUsed = "default-155-105" }
        let selectedCounter = counter
        let id = token
        isAnalyzing = true
        videoAnalysisNotice = "Analisando a pessoa escolhida…"
        Task { [weak self] in
            let results = await Task.detached(priority: .userInitiated) {
                Self.analyzeCachedPoses(cached, selectedFrame: selectedFrame, candidateIndex: candidate.index,
                                       counter: selectedCounter)
            }.value
            guard let self, self.token == id, self.videoPlayer === player else { return }
            self.videoResults = results
            self.events = results.compactMap(\.event)
            self.isAnalyzing = false
            self.isChoosingVideoPerson = false
            let followed = results.dropFirst(selectedFrame).filter {
                if case .selected = $0.tracking { return true }; return false
            }.count
            self.videoAnalysisNotice = "Trecho analisado: \(self.events.count) repetições · \(followed)/\(results.count - selectedFrame) quadros acompanhados."
            self.apply(results[selectedFrame])
            #if DEBUG
            self.saveQAClipReportIfRequested(source: url, results: results, selectionRequested: true)
            #endif
            await player.seek(to: CMTime(seconds: timestamp, preferredTimescale: 600),
                              toleranceBefore: .zero, toleranceAfter: .zero)
            guard self.token == id, self.videoPlayer === player else { return }
            player.play()
        }
    }

    func choosePersonInVideo() {
        guard !isAnalyzing, importedVideoHasMultiplePeople else { return }
        videoPlayer?.pause()
        calibrateSelectedStandingFrame = false
        isChoosingVideoPerson = true
        // Playback may have stopped on an empty frame. Reposition within the cached
        // analysis so "choose again" always offers an actual selectable person.
        let current = currentVideoObservationPTS ?? videoPlayer?.currentTime().seconds ?? 0
        if let selectable = rawImportedResults.filter({ !$0.candidates.isEmpty }).min(by: {
            abs($0.pts - current) < abs($1.pts - current)
        }) {
            currentVideoObservationPTS = selectable.pts
            apply(selectable)
            trackingDecision = .noSelection
            repetitions = 0
            phaseText = "Toque na pessoa que será acompanhada"
            videoPlayer?.seek(to: CMTime(seconds: selectable.pts, preferredTimescale: 600),
                              toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            videoAnalysisNotice = "Nenhuma pessoa detectada neste vídeo. Tente outro enquadramento ou iluminação."
        }
    }

    private nonisolated static func analyzeCachedPoses(_ cached: [TimedPose], selectedFrame: Int,
                                                       candidateIndex: Int, counter: SquatCounter) -> [TimedPose] {
        let frames = cached.map { result in
            VideoPoseFrame(timestamp: result.pts, observations: result.candidates.compactMap { candidate in
                guard result.poseOptions.indices.contains(candidate.index) else { return nil }
                let pose = result.poseOptions[candidate.index]
                return VideoPoseObservation(candidate: candidate, kneeAngle: pose.kneeAngle,
                                            confidence: pose.confidence)
            })
        }
        let analysis = OfflineTargetAnalyzer.analyze(frames, selectedFrame: selectedFrame,
                                                     candidateIndex: candidateIndex, counter: counter)
        return zip(cached, analysis).map { raw, tracked in
            let pose: PoseFrame
            if case .selected(let index) = tracked.decision, raw.poseOptions.indices.contains(index) {
                pose = raw.poseOptions[index]
            } else {
                pose = PoseFrame(landmarks: [], confidence: 0, kneeAngle: nil,
                                 imageAspectRatio: raw.frame.imageAspectRatio)
            }
            let phase: String
            switch tracked.decision {
            case .selected: phase = tracked.phase.displayText
            case .noSelection: phase = "Antes do ponto de seleção"
            case .uncertain: phase = "Identidade incerta — contagem pausada"
            case .reselectionRequired: phase = "Pessoa perdida — escolha novamente"
            }
            return TimedPose(pts: raw.pts, frame: pose, candidates: raw.candidates,
                             tracking: tracked.decision, count: tracked.count, phase: phase,
                             event: tracked.event, metrics: raw.metrics, poseOptions: raw.poseOptions)
        }
    }

    func stop() {
        #if DEBUG
        saveQACameraReportIfRequested()
        #endif
        let wasCameraActive = isCameraActive
        let wasStarting = isStarting
        let summary = WorkoutSummary(
            repetitions: repetitions,
            target: plan.targetRepetitions,
            elapsedSeconds: startedAt.map { Date().timeIntervalSince($0) } ?? metrics.elapsedSeconds,
            noPoseFrames: metrics.noPoseFrames,
            processedFrames: metrics.processedFrames
        )
        let finishingRecording = activeRecordingURL != nil && recordingStartRequested
        if wasCameraActive, let startedAt {
            let record = WorkoutRecord(startedAt: startedAt, endedAt: Date(),
                                       exercise: exercise.rawValue, target: plan.targetRepetitions,
                                       repetitions: repetitions, elapsedSeconds: summary.elapsedSeconds,
                                       model: (modelUsed ?? model).rawValue, camera: cameraChoice.rawValue,
                                       videoFileName: finishingRecording ? activeRecordingURL?.lastPathComponent : nil,
                                       replayFileName: finishingRecording ? "\(UUID().uuidString).json" : nil,
                                       processedFrames: metrics.processedFrames,
                                       noPoseFrames: metrics.noPoseFrames)
            if finishingRecording { pendingHistoryRecord = record }
            else { saveHistory(record: record, results: []) }
        }
        if wasCameraActive && startedAt != nil { workoutSummary = summary }
        if finishingRecording {
            pendingRecordingResults = liveRecordingResults
            pendingRecordingSummary = summary
            isFinalizingRecording = true
        }
        endSession()
        if finishingRecording {
            if movieOutput.isRecording {
                movieOutput.stopRecording()
            } else {
                stopRecordingWhenStarted = true
            }
        } else {
            activeRecordingURL = nil
            recordingDelegate = nil
            captureRotationPolicy.endRecording()
            lockedPreviewAngle = nil
        }
        let box = CaptureSessionBox(captureSession)
        cameraQueue.async { box.value.stopRunning() }
        isRunning = false
        isStarting = false
        startedAt = nil
        if wasStarting && !wasCameraActive { phaseText = "Início cancelado" }
    }

    func importVideo(_ item: PhotosPickerItem?) async {
        guard let item, let movie = try? await item.loadTransferable(type: SelectedVideo.self) else {
            phaseText = "Vídeo não disponível"
            return
        }
        analyzeVideo(at: movie.url)
    }

    func importVideoFile(_ selectedURL: URL) {
        let accessed = selectedURL.startAccessingSecurityScopedResource()
        defer { if accessed { selectedURL.stopAccessingSecurityScopedResource() } }
        do {
            let suffix = selectedURL.pathExtension.isEmpty ? "mov" : selectedURL.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("ritmovis-import-\(UUID().uuidString)")
                .appendingPathExtension(suffix)
            try FileManager.default.copyItem(at: selectedURL, to: copy)
            analyzeVideo(at: copy)
        } catch {
            phaseText = "Não foi possível abrir o vídeo: \(error.localizedDescription)"
        }
    }

    func testLicensedClip() {
        guard let url = Bundle.main.url(forResource: "pexels-8837118-1280w", withExtension: "mp4") else {
            phaseText = "Clipe de teste não incluído"
            return
        }
        analyzeVideo(at: url)
    }

    func testGroupClip() {
        guard let url = Bundle.main.url(forResource: "pexels-6740245-group", withExtension: "mp4") else {
            phaseText = "Clipe de grupo não incluído"
            return
        }
        useVisionForVideo = true
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--qa-group-mediapipe") { useVisionForVideo = false }
        #endif
        analyzeVideo(at: url)
    }

    #if DEBUG
    func testPrivateClip(named filename: String) {
        guard !filename.isEmpty, URL(fileURLWithPath: filename).lastPathComponent == filename,
              ["mp4", "mov"].contains(URL(fileURLWithPath: filename).pathExtension.lowercased()) else {
            phaseText = "Nome de vídeo de QA inválido"
            return
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            phaseText = "Vídeo de QA ausente no aparelho"
            return
        }
        analyzeVideo(at: url)
    }
    #endif

    func replay() {
        guard let videoPlayer else { return }
        repetitions = 0
        landmarks = []
        phaseText = "Reproduzindo replay"
        videoPlayer.seek(to: .zero)
        videoPlayer.play()
    }

    func refreshHistory() {
        do {
            _ = try historyStore.discoverLegacyVideos()
            historyRecords = historyStore.load().sorted { $0.startedAt > $1.startedAt }
            historyError = nil
        } catch {
            historyError = "Não foi possível carregar o histórico: \(error.localizedDescription)"
        }
    }

    func deleteHistory(_ record: WorkoutRecord) {
        do {
            try historyStore.delete(record: record)
            refreshHistory()
        } catch {
            historyError = "Não foi possível apagar este treino: \(error.localizedDescription)"
        }
    }

    func openHistoryReplay(_ record: WorkoutRecord) {
        guard !isCameraActive, !isStarting, let fileName = record.videoFileName else { return }
        endSession()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gravacoes", isDirectory: true).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            historyError = "Vídeo não encontrado neste iPhone"
            return
        }
        let samples = (try? historyStore.samples(for: record)) ?? []
        resetResults()
        isHistoricalReplay = true
        imageAspectRatio = samples.first?.imageAspectRatio ?? (url.pathExtension.lowercased() == "mov" ? 9.0 / 16.0 : 16.0 / 9.0)
        videoResults = samples.map { sample in
            let points = sample.landmarks.map { PosePoint(x: $0.x, y: $0.y, visibility: 1, presence: 1) }
            return TimedPose(pts: sample.relativeTime,
                             frame: PoseFrame(landmarks: points, confidence: 1,
                                              kneeAngle: nil, imageAspectRatio: sample.imageAspectRatio),
                             candidates: [], tracking: .noSelection,
                             count: sample.count, phase: sample.phase,
                             event: nil, metrics: BenchmarkMetrics())
        }
        let player = AVPlayer(url: url)
        videoPlayer = player
        installObserver(on: player, id: token)
        replayURL = url
        repetitions = 0
        landmarks = []
        workoutSummary = record.status == .completed
            ? WorkoutSummary(repetitions: record.repetitions, target: record.target,
                             elapsedSeconds: record.elapsedSeconds,
                             noPoseFrames: record.noPoseFrames,
                             processedFrames: record.processedFrames)
            : nil
        phaseText = samples.isEmpty ? "Vídeo sem contagem disponível" : "Replay pronto"
        player.play()
    }

    private func analyzeVideo(at url: URL) {
        stop()
        calibrateSelectedStandingFrame = false
        workoutSummary = nil
        replayURL = nil
        currentAnalyzedVideoURL = url
        let id = token
        isAnalyzing = true
        phaseText = "Analisando vídeo antes da reprodução"
        do {
            try prepareWorker(id: id, videoURL: url)
            worker?.analyzeVideo(at: url)
        } catch {
            isAnalyzing = false
            phaseText = error.localizedDescription
        }
    }

    func benchmarkCSV() -> String? {
        guard !isHistoricalReplay else { return nil }
        let header = "model,processed_frames,dropped_frames,no_pose_frames,near_black_frames,mean_latency_ms,p95_latency_ms,elapsed_seconds,processed_fps,input_width,input_height,tap_to_visual_ms,tap_to_capture_running_ms,tap_to_first_frame_ms,tap_to_first_pose_ms,permission_wait_ms,startup_without_permission_ms,event_timestamp_s,event_confidence"
        let timing = startupTiming
        let prefix = "\((modelUsed ?? model).rawValue),\(metrics.processedFrames),\(metrics.droppedFrames),\(metrics.noPoseFrames),\(metrics.nearBlackFrames),\(metrics.meanLatencyMs),\(metrics.p95LatencyMs),\(metrics.elapsedSeconds),\(metrics.processedFPS),\(metrics.inputWidth),\(metrics.inputHeight),\(timing.tapToVisualResponseMs),\(timing.tapToCaptureMs),\(timing.tapToFirstFrameMs),\(timing.tapToFirstPoseMs),\(timing.permissionWaitMs),\(timing.startupExcludingPermissionMs)"
        let rows = events.isEmpty ? [prefix + ",,"] : events.map { prefix + ",\($0.timestamp),\($0.confidence)" }
        let backend = isCameraActive ? "MediaPipe \((modelUsed ?? model).rawValue)" : videoBackendUsed
        let calibration = videoCalibrationUsed.replacingOccurrences(of: ",", with: ";")
        return ([header + ",backend,calibration"] + rows.map { $0 + ",\(backend),\(calibration)" }).joined(separator: "\n")
    }

    private func endSession() {
        token = UUID()
        isHistoricalReplay = false
        isStarting = false
        setCameraActive(false)
        frameDelegate.setFirstFrameHandler(nil)
        frameDelegate.setWorker(nil)
        worker?.cancel()
        worker = nil
        if let playerObserver, let videoPlayer { videoPlayer.removeTimeObserver(playerObserver) }
        playerObserver = nil
        videoPlayer?.pause()
        videoPlayer = nil
        videoResults = []
        rawImportedResults = []
        currentAnalyzedVideoURL = nil
        currentVideoObservationPTS = nil
        importedVideoHasMultiplePeople = false
        isChoosingVideoPerson = false
        videoAnalysisNotice = nil
        isAnalyzing = false
    }

    private func setCameraActive(_ active: Bool) {
        isCameraActive = active
        UIApplication.shared.isIdleTimerDisabled = active
    }

    private func handleCaptureNotification(event: Int, reasonRaw: Int?, errorMessage: String?) {
        captureEventLog.append("\(event):\(reasonRaw.map(String.init) ?? "-"):\(errorMessage ?? "-")")
        switch event {
        case 0:
            let reason = reasonRaw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            switch reason {
            case .videoDeviceInUseByAnotherClient:
                cameraWarning = "Outra sessão está usando a câmera. Feche o outro app ou a visualização remota."
            case .videoDeviceNotAvailableDueToSystemPressure:
                cameraWarning = "Câmera pausada por pressão do sistema. Aguarde o iPhone esfriar."
            case .videoDeviceNotAvailableInBackground:
                cameraWarning = "Câmera indisponível enquanto o app está em segundo plano."
            default:
                cameraWarning = "Captura interrompida pelo iPhone. Verifique a câmera e tente novamente."
            }
        case 1:
            cameraWarning = nil
        case 2:
            cameraWarning = "Falha da câmera: \(errorMessage ?? "erro desconhecido")"
        default:
            break
        }
    }

    #if DEBUG
    private func saveQAClipFailureIfRequested(source: URL, reason: String) {
        guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--qa-private-clip=") }) else { return }
        let report = ["source": source.lastPathComponent, "error": reason]
        guard let data = try? JSONSerialization.data(withJSONObject: report) else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? data.write(to: documents.appendingPathComponent("qa-clip-failure.json"), options: .atomic)
    }

    private func saveQAClipReportIfRequested(source: URL, results: [TimedPose],
                                             selectionRequested: Bool) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--qa-clip-lite") || args.contains("--qa-clip-full")
                || args.contains("--qa-group-clip") || args.contains("--qa-group-select")
                || args.contains(where: { $0.hasPrefix("--qa-private-clip=") }) else { return }
        let report = QAClipReport(recordedAt: Date(), model: videoBackendUsed,
                                  calibration: videoCalibrationUsed,
                                  source: source.lastPathComponent, repetitions: events.count,
                                  events: events, metrics: results.last?.metrics ?? metrics,
                                  framesWithMultipleCandidates: results.filter { $0.candidates.count > 1 }.count,
                                  maximumCandidates: results.map { $0.candidates.count }.max() ?? 0,
                                  framesWithoutSelection: results.filter { $0.tracking == .noSelection }.count,
                                  groupRequiresSelection: ImportedClipPolicy.requiresSelection(
                                    candidateCounts: results.map { $0.candidates.count }),
                                  selectionRequested: selectionRequested,
                                  selectedFrames: results.filter {
                                    if case .selected = $0.tracking { return true }; return false
                                  }.count,
                                  uncertainFrames: results.filter { $0.tracking == .uncertain }.count,
                                  reselectionFrames: results.filter { $0.tracking == .reselectionRequired }.count,
                                  diagnostics: ClipDiagnostics.summarize(results.map {
                                    ClipFrameDiagnostic(candidateCount: $0.candidates.count,
                                                        decision: $0.tracking,
                                                        hasKneeAngle: $0.frame.kneeAngle != nil)
                                  }),
                                  trace: args.contains("--qa-group-select") ? results.map {
                                    QATrackingFrame(pts: $0.pts, candidates: $0.candidates,
                                                    decision: String(describing: $0.tracking),
                                                    angle: $0.frame.kneeAngle)
                                  } : nil)
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try JSONEncoder().encode(report).write(
                to: documents.appendingPathComponent("qa-clip-diagnostics.json"), options: .atomic)
        } catch {
            print("QA clip diagnostics could not be saved: \(error.localizedDescription)")
        }
    }

    private func saveQACameraReportIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--qa-camera") || args.contains("--qa-front-camera")
                || args.contains("--qa-record-camera") || args.contains("--qa-record-front-camera") else { return }
        let report = QACameraReport(recordedAt: Date(), camera: cameraChoice.rawValue,
                                    model: (modelUsed ?? model).rawValue,
                                    timing: startupTiming, metrics: metrics,
                                    warning: cameraWarning,
                                    captureRunning: captureSession.isRunning,
                                    captureInterrupted: captureSession.isInterrupted,
                                    captureEvents: captureEventLog)
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try JSONEncoder().encode(report).write(
                to: documents.appendingPathComponent("qa-camera-diagnostics.json"), options: .atomic)
        } catch {
            print("QA diagnostics could not be saved: \(error.localizedDescription)")
        }
    }
    #endif

    private func resetResults() {
        repetitions = 0; events = []; landmarks = []; imageAspectRatio = 1
        targetCandidates = []; trackingDecision = .noSelection
        metrics = BenchmarkMetrics(); processedFrames = 0; droppedFrames = 0
        startedAt = nil
        modelUsed = model
    }

    private func prepareWorker(id: UUID, videoURL: URL?) throws {
        resetResults()
        let args = ProcessInfo.processInfo.arguments
        let vision = videoURL != nil && (useVisionForVideo || args.contains("--qa-apple-vision"))
        let hybrid = videoURL != nil && args.contains("--qa-hybrid")
        let independent = videoURL != nil && args.contains("--qa-independent-frames")
        videoBackendUsed = hybrid ? "Vision + MediaPipe \(model.rawValue) cropped"
            : vision ? "Apple Vision VNDetectHumanBodyPoseRequest"
            : "MediaPipe \(model.rawValue) \(independent ? "image" : "video")"
        videoCalibrationUsed = "default-155-105"
        let newWorker = try InferenceWorker(model: model,
                                             useVisionForVideo: vision,
                                             hybridExperiment: hybrid, independentFrameExperiment: independent,
                                             requiresExplicitSelection: videoURL == nil) { [weak self] result in
            guard let self, self.token == id, videoURL == nil else { return }
            self.apply(result)
            if let event = result.event { self.events.append(event) }
            if self.activeRecordingURL != nil && self.movieOutput.isRecording {
                self.liveRecordingResults.append(result)
            }
        } complete: { [weak self] rawResults, errorMessage in
            guard let self, self.token == id, let videoURL else { return }
            if let errorMessage {
                self.isAnalyzing = false
                self.phaseText = "Análise incompleta — nenhum resultado publicado: \(errorMessage)"
                #if DEBUG
                self.saveQAClipFailureIfRequested(source: videoURL, reason: errorMessage)
                #endif
                return
            }
            guard !rawResults.isEmpty else {
                self.isAnalyzing = false
                self.phaseText = "Nenhum quadro analisável"
                #if DEBUG
                self.saveQAClipFailureIfRequested(source: videoURL, reason: "Nenhum quadro analisável")
                #endif
                return
            }
            let groupDetected = ImportedClipPolicy.requiresSelection(
                candidateCounts: rawResults.map { $0.candidates.count })
            self.rawImportedResults = rawResults
            // No target has been selected on the first pass.
            let needsTarget = groupDetected
            let results: [TimedPose] = needsTarget ? rawResults.map { result in
                TimedPose(pts: result.pts,
                          frame: PoseFrame(landmarks: [], confidence: 0, kneeAngle: nil,
                                           imageAspectRatio: result.frame.imageAspectRatio),
                          candidates: result.candidates, tracking: .noSelection, count: 0,
                          phase: "Selecione a pessoa que deseja analisar",
                          event: nil, metrics: result.metrics, poseOptions: result.poseOptions)
            } : rawResults
            self.videoResults = results
            self.importedVideoHasMultiplePeople = groupDetected
            self.isChoosingVideoPerson = needsTarget
            self.isAnalyzing = false
            self.events = results.compactMap(\.event)
            self.metrics = results[results.count - 1].metrics
            #if DEBUG
            self.saveQAClipReportIfRequested(source: videoURL, results: results,
                                             selectionRequested: false)
            #endif
            self.processedFrames = self.metrics.processedFrames
            self.droppedFrames = self.metrics.droppedFrames
            let player = AVPlayer(url: videoURL)
            self.videoPlayer = player
            self.installObserver(on: player, id: id)
            self.phaseText = needsTarget
                ? "Mais de uma pessoa detectada — toque no aluno para analisar"
                : "Reproduzindo análise"
            self.isRunning = false
            self.startedAt = nil
            if needsTarget, let first = results.first {
                self.currentVideoObservationPTS = first.pts
                self.apply(first)
            } else { player.play() }
            #if DEBUG
            let qaArguments = ProcessInfo.processInfo.arguments
            if qaArguments.contains("--qa-group-select"),
               groupDetected,
               let sample = results.first(where: { !$0.candidates.isEmpty }),
               let center = sample.candidates.min(by: { lhs, rhs in
                   let requestedX = qaArguments.first(where: { $0.hasPrefix("--qa-target-x=") })
                       .flatMap { Double($0.dropFirst("--qa-target-x=".count)) } ?? 0.5
                   let requestedY = qaArguments.first(where: { $0.hasPrefix("--qa-target-y=") })
                       .flatMap { Double($0.dropFirst("--qa-target-y=".count)) } ?? 0.5
                   return hypot(lhs.centerX - requestedX, lhs.centerY - requestedY)
                       < hypot(rhs.centerX - requestedX, rhs.centerY - requestedY)
               }) {
                Task { @MainActor in
                    self.currentVideoObservationPTS = sample.pts
                    self.apply(sample)
                    self.calibrateSelectedStandingFrame = ProcessInfo.processInfo.arguments.contains("--qa-calibrate-standing")
                    self.selectPersonInVideo(center)
                }
            }
            #endif
        }
        worker = newWorker
        if videoURL == nil { frameDelegate.setWorker(newWorker) }
    }

    private func installObserver(on player: AVPlayer, id: UUID) {
        playerObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.token == id else { return }
                if let result = self.videoResults.last(where: { $0.pts <= time.seconds }) {
                    if self.isChoosingVideoPerson, self.currentVideoObservationPTS != result.pts {
                        self.calibrateSelectedStandingFrame = false
                    }
                    self.currentVideoObservationPTS = result.pts
                    self.apply(result)
                } else if !self.videoResults.isEmpty {
                    self.repetitions = 0
                    self.landmarks = []
                    self.phaseText = "Aguardando pose"
                }
            }
        }
    }

    private func apply(_ result: TimedPose) {
        if !isHistoricalReplay && !result.frame.landmarks.isEmpty {
            startupTiming.firstPose(at: ProcessInfo.processInfo.systemUptime)
        }
        landmarks = result.frame.landmarks.map { CGPoint(x: $0.x, y: $0.y) }
        targetCandidates = result.candidates
        trackingDecision = isChoosingVideoPerson && importedVideoHasMultiplePeople ? .noSelection : result.tracking
        imageAspectRatio = result.frame.imageAspectRatio
        repetitions = isChoosingVideoPerson && importedVideoHasMultiplePeople ? 0 : result.count
        phaseText = isChoosingVideoPerson && importedVideoHasMultiplePeople
            ? "Toque na pessoa que será acompanhada" : result.phase
        if !isHistoricalReplay {
            metrics = result.metrics
            processedFrames = metrics.processedFrames
            droppedFrames = metrics.droppedFrames
            if metrics.consecutiveNearBlackFrames >= 30 && cameraWarning == nil {
                cameraWarning = nearBlackWarning
            } else if metrics.consecutiveNearBlackFrames == 0 && cameraWarning == nearBlackWarning {
                cameraWarning = nil
            }
        }
    }

    private func prepareRecording() throws {
        guard captureSession.outputs.contains(where: { $0 === movieOutput }) else {
            throw NSError(domain: "SquatCounter", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "Gravação indisponível nesta configuração de câmera"])
        }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "SquatCounter", code: 6,
                          userInfo: [NSLocalizedDescriptionKey: "Pasta de gravações indisponível"])
        }
        let folder = documents.appendingPathComponent("Gravacoes", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("agachamentos-\(UUID().uuidString).mov")
        activeRecordingURL = url
        recordingDelegate = WorkoutRecordingDelegate(started: { [weak self] pts in
            guard let self, self.activeRecordingURL == url else { return }
            if pts.isFinite { self.recordingStartPTS = pts }
            self.isRecordingVideo = true
            if self.stopRecordingWhenStarted && self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
        }, finished: { [weak self] finishedURL, error, playable in
            guard let self, self.activeRecordingURL == finishedURL else { return }
            if self.isCameraActive { self.stop() }
            self.finishRecording(at: finishedURL, error: error, playable: playable)
        })
    }

    private func beginRecording() {
        guard let url = activeRecordingURL, let recordingDelegate else { return }
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 0
        captureRotationPolicy.startRecording(at: Double(angle))
        lockedPreviewAngle = angle
        applyCaptureRotation(angle)
        recordingStartRequested = true
        movieOutput.startRecording(to: url, recordingDelegate: recordingDelegate)
    }

    private func finishRecording(at url: URL, error: String?, playable: Bool) {
        captureRotationPolicy.endRecording()
        lockedPreviewAngle = nil
        isFinalizingRecording = false
        isRecordingVideo = false
        recordingStartRequested = false
        stopRecordingWhenStarted = false
        workoutSummary = pendingRecordingSummary
        defer {
            activeRecordingURL = nil
            recordingDelegate = nil
            pendingRecordingResults = []
            pendingRecordingSummary = nil
            recordingStartPTS = nil
            liveRecordingResults = []
            pendingHistoryRecord = nil
        }
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard playable, fileSize > 0 else {
            phaseText = error ?? "A gravação não gerou um vídeo reproduzível"
            recordingNotice = "O vídeo não pôde ser salvo para replay; o resumo do treino permanece no histórico."
            if let pendingHistoryRecord {
                let fallback = WorkoutRecord(id: pendingHistoryRecord.id,
                    startedAt: pendingHistoryRecord.startedAt, endedAt: pendingHistoryRecord.endedAt,
                    exercise: pendingHistoryRecord.exercise, target: pendingHistoryRecord.target,
                    repetitions: pendingHistoryRecord.repetitions,
                    elapsedSeconds: pendingHistoryRecord.elapsedSeconds,
                    model: pendingHistoryRecord.model, camera: pendingHistoryRecord.camera,
                    processedFrames: pendingHistoryRecord.processedFrames,
                    noPoseFrames: pendingHistoryRecord.noPoseFrames)
                saveHistory(record: fallback, results: [])
            }
            return
        }
        if let error { recordingNotice = "Vídeo salvo com aviso do iPhone: \(error)" }
        let firstPTS = recordingStartPTS ?? pendingRecordingResults.first?.pts ?? 0
        videoResults = pendingRecordingResults
            .filter { $0.pts >= firstPTS }
            .map { result in
                TimedPose(pts: result.pts - firstPTS, frame: result.frame,
                          candidates: [], tracking: result.tracking,
                          count: result.count, phase: result.phase,
                          event: result.event, metrics: result.metrics)
            }
        if let pendingHistoryRecord { saveHistory(record: pendingHistoryRecord, results: videoResults) }
        replayURL = url
        let player = AVPlayer(url: url)
        videoPlayer = player
        installObserver(on: player, id: token)
        repetitions = 0
        landmarks = []
        phaseText = "Replay pronto"
    }

    private func saveHistory(record: WorkoutRecord, results: [TimedPose]) {
        let samples = results.map { result in
            ReplaySample(relativeTime: result.pts, count: result.count, phase: result.phase,
                         landmarks: result.frame.landmarks.map { ReplayPoint(x: $0.x, y: $0.y) },
                         imageAspectRatio: result.frame.imageAspectRatio)
        }
        do {
            try historyStore.save(record: record, samples: samples)
            refreshHistory()
        } catch {
            historyError = "Treino concluído, mas o histórico não foi salvo: \(error.localizedDescription)"
        }
    }

    private func configureCamera() throws {
        let position = cameraChoice.position
        let existingInput = captureSession.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first
        let needsInputChange = existingInput?.device.position != position
        let needsMovieOutput = recordWorkout && !captureSession.outputs.contains(where: { $0 === movieOutput })
        guard needsInputChange || needsMovieOutput else {
            if let rotationCoordinator {
                applyCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
            }
            return
        }
        guard let device = needsInputChange
            ? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            : existingInput?.device else {
            throw NSError(domain: "SquatCounter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Câmera \(cameraChoice.title.lowercased()) indisponível"])
        }
        let input = needsInputChange ? try AVCaptureDeviceInput(device: device) : nil
        if needsInputChange {
            rotationObservation = nil
            rotationCoordinator = nil
        }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .high
        if let input {
            if let existingInput { captureSession.removeInput(existingInput) }
            guard captureSession.canAddInput(input) else {
                if let existingInput, captureSession.canAddInput(existingInput) { captureSession.addInput(existingInput) }
                throw NSError(domain: "SquatCounter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Entrada de câmera incompatível"])
            }
            captureSession.addInput(input)
        }
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(frameDelegate, queue: DispatchQueue(label: "camera.output"))
        if !captureSession.outputs.contains(where: { $0 === output }) {
            guard captureSession.canAddOutput(output) else {
                if let input { captureSession.removeInput(input) }
                if let existingInput, captureSession.canAddInput(existingInput) { captureSession.addInput(existingInput) }
                throw NSError(domain: "SquatCounter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Saída de câmera incompatível"])
            }
            captureSession.addOutput(output)
        }
        if needsMovieOutput {
            guard captureSession.canAddOutput(movieOutput) else {
                if let input { captureSession.removeInput(input) }
                if let existingInput, captureSession.canAddInput(existingInput) { captureSession.addInput(existingInput) }
                throw NSError(domain: "SquatCounter", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "Este aparelho não aceita gravação e análise simultâneas"])
            }
            movieOutput.minFreeDiskSpaceLimit = 100 * 1_024 * 1_024
            captureSession.addOutput(movieOutput)
        }
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
        if needsInputChange {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            rotationCoordinator = coordinator
            rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                Task { @MainActor [weak self] in self?.applyCaptureRotation(angle) }
            }
        } else if let rotationCoordinator {
            applyCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        }
    }

    private func applyCaptureRotation(_ angle: CGFloat) {
        let stableAngle = CGFloat(captureRotationPolicy.angle(for: Double(angle)))
        for connection in [output.connection(with: .video), movieOutput.connection(with: .video)].compactMap({ $0 }) {
            if connection.isVideoRotationAngleSupported(stableAngle) { connection.videoRotationAngle = stableAngle }
        }
    }
}

private final class SampleBufferBox: @unchecked Sendable {
    let buffer: CMSampleBuffer
    init(_ buffer: CMSampleBuffer) { self.buffer = buffer }
}

private final class InferenceWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "pose.inference", qos: .userInitiated)
    private let detector: PoseDetector
    private let requiresExplicitSelection: Bool
    private var tracker = TargetTracker()
    private var lastCandidates: [PoseCandidate] = []
    private var lastCandidatePTS: TimeInterval?
    private var lastCandidateUptime: TimeInterval?
    private var counter = SquatCounter()
    private var processed = 0
    private var dropped = 0
    private var firstDetectionError: String?
    private var noPose = 0
    private var frameHealth = CameraFrameHealth()
    private var sortedLatencies: [Double] = []
    private var latencySum = 0.0
    private let started = ContinuousClock.now
    private var inputWidth = 0
    private var inputHeight = 0
    private let cameraSlot = DispatchSemaphore(value: 1)
    private let lock = NSLock()
    private var cameraDrops = 0
    private var cancelled = false
    private var activeReader: AVAssetReader?
    private let update: @MainActor (TimedPose) -> Void
    private let complete: @MainActor ([TimedPose], String?) -> Void

    init(model: PoseModel, useVisionForVideo: Bool = false,
         hybridExperiment: Bool = false, independentFrameExperiment: Bool = false,
         requiresExplicitSelection: Bool,
         update: @escaping @MainActor (TimedPose) -> Void,
         complete: @escaping @MainActor ([TimedPose], String?) -> Void) throws {
        detector = try PoseDetector(model: model, useVisionForVideo: useVisionForVideo,
                                    hybridExperiment: hybridExperiment, independentFrameExperiment: independentFrameExperiment)
        self.requiresExplicitSelection = requiresExplicitSelection
        self.update = update
        self.complete = complete
    }

    func cancel() {
        lock.lock(); cancelled = true; let reader = activeReader; lock.unlock()
        reader?.cancelReading()
    }

    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }; return cancelled
    }

    func recordCaptureDrop() {
        lock.lock(); cameraDrops += 1; lock.unlock()
    }

    func selectPerson(_ displayed: PoseCandidate) {
        queue.async { [weak self] in
            guard let self, let pts = self.lastCandidatePTS,
                  let uptime = self.lastCandidateUptime,
                  ProcessInfo.processInfo.systemUptime - uptime < 1 else { return }
            // Do not trust a frame-local MediaPipe array index after a new frame arrives.
            let matches = self.lastCandidates.filter {
                hypot($0.centerX - displayed.centerX, $0.centerY - displayed.centerY) <= 0.08 &&
                abs($0.width - displayed.width) + abs($0.height - displayed.height) <= 0.15
            }
            guard matches.count == 1 else { return }
            self.counter.interruptTracking(at: pts)
            _ = self.tracker.select(matches[0], at: pts)
        }
    }

    func enqueue(_ buffer: CMSampleBuffer) {
        guard cameraSlot.wait(timeout: .now()) == .success else {
            recordCaptureDrop()
            return
        }
        let box = SampleBufferBox(buffer)
        queue.async { [weak self, box] in
            guard let self else { return }
            defer { self.cameraSlot.signal() }
            guard !self.isCancelled, let result = self.process(box.buffer) else { return }
            Task { @MainActor in self.update(result) }
        }
    }

    func analyzeVideo(at url: URL) {
        queue.async { [weak self] in self?.readVideo(at: url) }
    }

    private func readVideo(at url: URL) {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            finish([], error: "Vídeo sem faixa de imagem"); return
        }
        guard let reader = try? AVAssetReader(asset: asset) else {
            finish([], error: "Não foi possível ler o vídeo"); return
        }
        let pixelSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let output: AVAssetReaderOutput
        if track.preferredTransform.isIdentity {
            output = AVAssetReaderTrackOutput(track: track, outputSettings: pixelSettings)
        } else {
            // A reprodução aplica a matriz de rotação automaticamente; os quadros de
            // AVAssetReaderTrackOutput não. Compor aqui mantém pose e replay alinhados.
            let oriented = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: pixelSettings)
            oriented.videoComposition = AVMutableVideoComposition(propertiesOf: asset)
            output = oriented
        }
        guard reader.canAdd(output) else { finish([], error: "Formato de vídeo incompatível"); return }
        reader.add(output)
        lock.lock(); activeReader = reader; lock.unlock()
        guard reader.startReading() else { finish([], error: "Falha ao iniciar leitura do vídeo"); return }
        var results: [TimedPose] = []
        while !isCancelled, let buffer = output.copyNextSampleBuffer() {
            if let result = process(buffer) { results.append(result) }
        }
        lock.lock(); activeReader = nil; lock.unlock()
        guard !isCancelled else { return }
        guard reader.status == .completed else {
            finish(results, error: reader.error?.localizedDescription ?? "Leitura do vídeo interrompida")
            return
        }
        finish(results, error: results.isEmpty ? firstDetectionError : nil)
    }

    private func finish(_ results: [TimedPose], error: String?) {
        guard !isCancelled else { return }
        Task { @MainActor in complete(results, error) }
    }

    private func process(_ buffer: CMSampleBuffer) -> TimedPose? {
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        let start = ContinuousClock.now
        do {
            let nearBlack = CMSampleBufferGetImageBuffer(buffer).map(Self.isNearBlack) ?? false
            let batch = try detector.detect(buffer, timestamp: pts)
            lastCandidates = batch.candidates
            lastCandidatePTS = pts
            lastCandidateUptime = ProcessInfo.processInfo.systemUptime
            let decision: TrackingDecision
            if requiresExplicitSelection {
                decision = tracker.update(batch.candidates, at: pts)
            } else if batch.candidates.count == 1, let only = batch.candidates.first {
                decision = .selected(index: only.index)
            } else {
                decision = .noSelection
            }
            let selected: PoseFrame?
            if case .selected(let index) = decision, batch.poses.indices.contains(index) {
                selected = batch.poses[index]
            } else {
                selected = nil
            }
            let frame = selected ?? PoseFrame(landmarks: [], confidence: 0, kneeAngle: nil,
                                              imageAspectRatio: batch.imageAspectRatio)
            let duration = start.duration(to: .now).components
            let latency = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
            latencySum += latency
            let insertion = sortedLatencies.partitioningIndex { $0 >= latency }
            sortedLatencies.insert(latency, at: insertion)
            if let image = CMSampleBufferGetImageBuffer(buffer) {
                inputWidth = CVPixelBufferGetWidth(image)
                inputHeight = CVPixelBufferGetHeight(image)
            }
            processed += 1
            frameHealth.observe(isNearBlack: nearBlack)
            if frame.kneeAngle == nil { noPose += 1 }
            let event: RepEvent?
            if case .selected = decision, let kneeAngle = frame.kneeAngle {
                event = counter.consume(.init(timestamp: pts, kneeAngle: kneeAngle, confidence: frame.confidence))
            } else {
                counter.interruptTracking(at: pts)
                event = nil
            }
            let phase: String
            switch decision {
            case .selected: phase = counter.phase.displayText
            case .noSelection:
                if batch.candidates.isEmpty { phase = "Aguardando pessoas no quadro" }
                else if requiresExplicitSelection { phase = "Toque na pessoa que será acompanhada" }
                else { phase = "Vídeo com várias pessoas — seleção indisponível nesta versão" }
            case .uncertain: phase = "Identidade incerta — contagem pausada"
            case .reselectionRequired: phase = "Pessoa perdida — toque para selecionar novamente"
            }
            return TimedPose(pts: pts, frame: frame, candidates: batch.candidates,
                             tracking: decision, count: counter.repetitions,
                             phase: phase, event: event, metrics: currentMetrics,
                             poseOptions: batch.poses)
        } catch {
            dropped += 1
            if firstDetectionError == nil { firstDetectionError = error.localizedDescription }
            return nil
        }
    }

    private static func isNearBlack(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
              CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else { return false }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0 else { return false }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        for row in 0..<8 {
            for column in 0..<8 {
                let x = (column * width + width / 2) / 8
                let y = (row * height + height / 2) / 8
                let index = y * rowBytes + x * 4
                if max(bytes[index], bytes[index + 1], bytes[index + 2]) > 24 { return false }
            }
        }
        return true
    }

    private var currentMetrics: BenchmarkMetrics {
        let elapsed = started.duration(to: .now).components
        let elapsedSeconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        let p95Index = max(0, Int((Double(sortedLatencies.count) * 0.95).rounded(.up)) - 1)
        let p95 = sortedLatencies.isEmpty ? 0 : sortedLatencies[min(sortedLatencies.count - 1, p95Index)]
        lock.lock(); let cameraDropCount = cameraDrops; lock.unlock()
        return BenchmarkMetrics(processedFrames: processed, droppedFrames: dropped + cameraDropCount,
                                noPoseFrames: noPose, nearBlackFrames: frameHealth.nearBlackFrames,
                                consecutiveNearBlackFrames: frameHealth.consecutiveNearBlackFrames,
                                meanLatencyMs: processed == 0 ? 0 : latencySum / Double(processed),
                                p95LatencyMs: p95, elapsedSeconds: elapsedSeconds,
                                processedFPS: elapsedSeconds > 0 ? Double(processed) / elapsedSeconds : 0,
                                inputWidth: inputWidth, inputHeight: inputHeight)
    }
}

private extension Array where Element == Double {
    func partitioningIndex(_ predicate: (Double) -> Bool) -> Int {
        var lower = 0; var upper = count
        while lower < upper {
            let middle = (lower + upper) / 2
            if predicate(self[middle]) { upper = middle } else { lower = middle + 1 }
        }
        return lower
    }
}
