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
    let count: Int
    let phase: String
    let event: RepEvent?
    let metrics: BenchmarkMetrics
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
    @Published var imageAspectRatio = 1.0
    @Published var model: PoseModel = .lite
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
            return
        }
        #endif
        endSession()
        startupTiming.start(at: ProcessInfo.processInfo.systemUptime)
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

    func testLicensedClip() {
        guard let url = Bundle.main.url(forResource: "pexels-8837118-1280w", withExtension: "mp4") else {
            phaseText = "Clipe de teste não incluído"
            return
        }
        analyzeVideo(at: url)
    }

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
        workoutSummary = nil
        replayURL = nil
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
        return ([header] + rows).joined(separator: "\n")
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
        isAnalyzing = false
    }

    private func setCameraActive(_ active: Bool) {
        isCameraActive = active
        UIApplication.shared.isIdleTimerDisabled = active
    }

    private func handleCaptureNotification(event: Int, reasonRaw: Int?, errorMessage: String?) {
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
    private func saveQACameraReportIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--qa-camera") || args.contains("--qa-front-camera")
                || args.contains("--qa-record-camera") || args.contains("--qa-record-front-camera") else { return }
        let report = QACameraReport(recordedAt: Date(), camera: cameraChoice.rawValue,
                                    model: (modelUsed ?? model).rawValue,
                                    timing: startupTiming, metrics: metrics,
                                    warning: cameraWarning)
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
        metrics = BenchmarkMetrics(); processedFrames = 0; droppedFrames = 0
        startedAt = nil
        modelUsed = model
    }

    private func prepareWorker(id: UUID, videoURL: URL?) throws {
        resetResults()
        let newWorker = try InferenceWorker(model: model) { [weak self] result in
            guard let self, self.token == id, videoURL == nil else { return }
            self.apply(result)
            if let event = result.event { self.events.append(event) }
            if self.activeRecordingURL != nil && self.movieOutput.isRecording {
                self.liveRecordingResults.append(result)
            }
        } complete: { [weak self] results, errorMessage in
            guard let self, self.token == id, let videoURL else { return }
            guard !results.isEmpty else {
                self.isAnalyzing = false
                self.phaseText = errorMessage ?? "Nenhum quadro analisável"
                return
            }
            self.videoResults = results
            self.isAnalyzing = false
            self.events = results.compactMap(\.event)
            self.metrics = results[results.count - 1].metrics
            self.processedFrames = self.metrics.processedFrames
            self.droppedFrames = self.metrics.droppedFrames
            let player = AVPlayer(url: videoURL)
            self.videoPlayer = player
            self.installObserver(on: player, id: id)
            self.phaseText = "Reproduzindo análise"
            self.isRunning = false
            self.startedAt = nil
            player.play()
        }
        worker = newWorker
        if videoURL == nil { frameDelegate.setWorker(newWorker) }
    }

    private func installObserver(on player: AVPlayer, id: UUID) {
        playerObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.token == id else { return }
                if let result = self.videoResults.last(where: { $0.pts <= time.seconds }) {
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
        imageAspectRatio = result.frame.imageAspectRatio
        repetitions = result.count
        phaseText = result.phase
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
    private var counter = SquatCounter()
    private var processed = 0
    private var dropped = 0
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

    init(model: PoseModel, update: @escaping @MainActor (TimedPose) -> Void,
         complete: @escaping @MainActor ([TimedPose], String?) -> Void) throws {
        detector = try PoseDetector(model: model)
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
        guard track.preferredTransform.isIdentity, track.naturalSize.width >= track.naturalSize.height else {
            finish([], error: "Nesta versão, importe vídeo horizontal sem rotação embutida")
            return
        }
        guard let reader = try? AVAssetReader(asset: asset) else {
            finish([], error: "Não foi possível ler o vídeo"); return
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
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
        finish(results, error: reader.status == .failed ? reader.error?.localizedDescription : nil)
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
            let frame = try detector.detect(buffer, timestamp: pts)
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
            let event = counter.consume(.init(timestamp: pts, kneeAngle: frame.kneeAngle ?? 0, confidence: frame.confidence))
            return TimedPose(pts: pts, frame: frame, count: counter.repetitions,
                             phase: counter.phase.displayText, event: event, metrics: currentMetrics)
        } catch {
            dropped += 1
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
