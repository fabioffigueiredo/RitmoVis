import SwiftUI
import PhotosUI
import AVKit
import SquatCounterCore

private enum Theme {
    static let background = Color(red: 0.07, green: 0.10, blue: 0.15)
    static let surface = Color(red: 0.12, green: 0.16, blue: 0.22)
    static let accent = Color(red: 1, green: 0.56, blue: 0.22)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var session = WorkoutSession()
    @State private var pickerItem: PhotosPickerItem?
    @State private var didRunQA = false

    var body: some View {
        ZStack {
            TabView {
                NavigationStack { preparationScreen }
                    .tabItem { Label("Treino", systemImage: "figure.strengthtraining.traditional") }
                NavigationStack { HistoryScreen(session: session) }
                    .tabItem { Label("Histórico", systemImage: "clock.arrow.circlepath") }
            }
            .tint(Theme.accent)
            if session.isStarting || session.isCameraActive {
                LiveWorkoutScreen(session: session)
                    .transition(reduceMotion ? .identity : .opacity)
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.isStarting || session.isCameraActive)
        .onAppear { session.refreshHistory(); runQAIfRequested() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && (session.isCameraActive || session.isStarting) { session.stop() }
        }
    }

    private var preparationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introduction
                if let summary = session.workoutSummary { resultCard(summary) }
                setupCard
                if let player = session.videoPlayer { replayCard(player) }
                diagnosticsCard
            }
            .padding(16)
            .padding(.bottom, 80)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(.white)
        .navigationTitle("Treino")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                session.isAnalyzing ? session.stop() : session.startCamera()
            } label: {
                Label(session.isAnalyzing ? "Parar análise" : "Iniciar treino",
                      systemImage: session.isAnalyzing ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(session.isFinalizingRecording)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.background.opacity(0.96))
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AGACHAMENTO LIVRE", systemImage: "figure.strengthtraining.traditional")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            Text("Seu treino, em foco.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Apoie o iPhone, deixe o corpo inteiro visível e toque em Iniciar. A contagem acontece no aparelho.")
                .font(.body).foregroundStyle(.white.opacity(0.82))
            HStack(spacing: 12) {
                Label("\(session.plan.targetRepetitions) repetições", systemImage: "number")
                Label("\(Int(session.plan.duration)) s", systemImage: "timer")
            }
            .font(.subheadline.weight(.semibold))
        }
        .card()
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preparar sessão").font(.title2.weight(.bold))
            Picker("Câmera", selection: $session.cameraChoice) {
                ForEach(CameraChoice.allCases) { choice in Text(choice.title).tag(choice) }
            }
            .pickerStyle(.segmented)
            Picker("Modelo de pose", selection: $session.model) {
                Text("Lite").tag(PoseModel.lite)
                Text("Full").tag(PoseModel.full)
            }
            .pickerStyle(.segmented)
            Text(session.model == .lite
                 ? "Lite: resposta mais rápida e menor uso de processamento. Recomendado para começar."
                 : "Full: usa mais processamento e pode localizar melhor os pontos do corpo. Não garante melhor contagem em todo treino.")
                .font(.footnote).foregroundStyle(.white.opacity(0.78))
            Stepper("Meta: \(session.plan.targetRepetitions) repetições",
                    value: $session.plan.targetRepetitions, in: 1...500)
            Stepper("Tempo de referência: \(Int(session.plan.duration)) s",
                    value: $session.plan.duration, in: 10...3600, step: 10)
            Toggle("Gravar vídeo para replay", isOn: $session.recordWorkout)
                .tint(Theme.accent)
            Text("Opcional. Vídeo sem áudio salvo neste iPhone; o replay com contagem fica no Histórico. O tempo de referência não encerra o treino sozinho.")
                .font(.footnote).foregroundStyle(.white.opacity(0.72))
            if let error = session.historyError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.yellow)
            }
            if let error = session.startError {
                Label(error, systemImage: "camera.fill")
                    .font(.footnote).foregroundStyle(.yellow)
            }
        }
        .disabled(session.isAnalyzing || session.isFinalizingRecording)
        .card()
    }

    private func resultCard(_ summary: WorkoutSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Último treino", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(Theme.accent)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summary.repetitions)").font(.system(size: 54, weight: .bold, design: .rounded))
                Text("/ \(summary.target) repetições").font(.title3.weight(.semibold))
            }
            Text(summary.couldNotAssess
                 ? "Não foi possível verificar a meta. Confira câmera, luz e enquadramento."
                 : summary.remaining > 0 ? "Faltaram \(summary.remaining) para a meta" : "Meta alcançada")
            Text("Tempo: \(durationText(summary.elapsedSeconds))"
                 + (summary.noPoseFrames.map { " · \($0) quadros sem pose" } ?? ""))
                .font(.subheadline).foregroundStyle(.white.opacity(0.75))
            if session.isFinalizingRecording { ProgressView("Salvando gravação…").tint(Theme.accent) }
            if let notice = session.recordingNotice {
                Text(notice).font(.footnote).foregroundStyle(.yellow)
            }
            if session.replayURL != nil {
                Button("Reproduzir replay com contagem") { session.replay() }
                    .buttonStyle(.bordered)
            }
            Text("A contagem não avalia técnica nem segurança do exercício.")
                .font(.footnote).foregroundStyle(.white.opacity(0.72))
        }
        .card()
    }

    private func replayCard(_ player: AVPlayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Replay").font(.headline)
            VideoPlayer(player: player)
                .overlay(PoseOverlay(landmarks: session.landmarks, imageAspectRatio: session.imageAspectRatio))
                .aspectRatio(session.imageAspectRatio, contentMode: .fit)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("\(session.repetitions) · \(session.phaseText)")
                .font(.subheadline.monospacedDigit())
            if let url = session.replayURL {
                ShareLink("Compartilhar vídeo original (sem contador)", item: url)
            }
        }
        .card()
    }

    private var diagnosticsCard: some View {
        DisclosureGroup("Testes e métricas") {
            VStack(alignment: .leading, spacing: 12) {
                PhotosPicker("Importar vídeo horizontal", selection: $pickerItem, matching: .videos)
                    .onChange(of: pickerItem) { _, item in Task { await session.importVideo(item) } }
                Button("Testar clipe demonstrativo") { session.testLicensedClip() }
                Text("Clipe opcional não incluído no projeto. Se fornecido pelo usuário, não entra no histórico de treinos.")
                if session.isHistoricalReplay {
                    Text("Métricas de inferência não disponíveis para este replay histórico.")
                } else {
                    Text("Quadros: \(session.processedFrames) · descartados: \(session.droppedFrames) · sem pose: \(session.metrics.noPoseFrames) · quase pretos: \(session.metrics.nearBlackFrames)")
                    Text(String(format: "Inferência: média %.1f ms · p95 %.1f ms", session.metrics.meanLatencyMs, session.metrics.p95LatencyMs))
                    Text(String(format: "Vazão: %.1f fps · %d × %d", session.metrics.processedFPS, session.metrics.inputWidth, session.metrics.inputHeight))
                    if session.startupTiming.tapToFirstFrameMs > 0 {
                        Text(String(format: "Iniciar → tela: %.0f ms · câmera: %.0f ms · quadro: %.0f ms · pose: %.0f ms",
                                    session.startupTiming.tapToVisualResponseMs,
                                    session.startupTiming.tapToCaptureMs,
                                    session.startupTiming.tapToFirstFrameMs,
                                    session.startupTiming.tapToFirstPoseMs))
                        Text(String(format: "Inicialização sem espera de permissão: %.0f ms",
                                    session.startupTiming.startupExcludingPermissionMs))
                    }
                    if let csv = session.benchmarkCSV() {
                        ShareLink("Compartilhar métricas CSV", item: csv)
                    }
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        }
        .card()
    }

    private func runQAIfRequested() {
        #if DEBUG
        guard !didRunQA else { return }
        didRunQA = true
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--qa-clip-full") { session.model = .full; session.testLicensedClip() }
        else if args.contains("--qa-clip-lite") { session.model = .lite; session.testLicensedClip() }
        else if args.contains("--qa-front-camera") { session.cameraChoice = .front; session.startCamera() }
        else if args.contains("--qa-camera") { session.startCamera() }
        else if args.contains("--qa-record-camera") {
            session.recordWorkout = true
            session.startCamera()
            Task { try? await Task.sleep(for: .seconds(12)); session.stop() }
        }
        else if args.contains("--qa-record-front-camera") {
            session.cameraChoice = .front
            session.recordWorkout = true
            session.startCamera()
            Task { try? await Task.sleep(for: .seconds(12)); session.stop() }
        }
        #endif
    }
}

private extension View {
    func card() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct LiveWorkoutScreen: View {
    @ObservedObject var session: WorkoutSession

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPreview(session: session.captureSession, mirrored: session.cameraChoice == .front,
                              lockedRotationAngle: session.lockedPreviewAngle)
                    .ignoresSafeArea()
                PoseOverlay(landmarks: session.landmarks, imageAspectRatio: session.imageAspectRatio)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        hudValue(title: "REPETIÇÕES", value: "\(session.repetitions)", prominent: true)
                        Spacer(minLength: 4)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = session.startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
                            hudValue(title: "TEMPO", value: durationText(elapsed), prominent: false)
                        }
                    }
                    HStack(spacing: 8) {
                        if session.isStarting { ProgressView().tint(.white) }
                        if session.isRecordingVideo { Image(systemName: "record.circle.fill").foregroundStyle(.red) }
                        Text(session.isStarting ? "Preparando câmera…" : session.phaseText).lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(12)
                    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                    if let warning = session.cameraWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Spacer()
                    Button { session.stop() } label: {
                        Label("Parar treino", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: geometry.size.width > geometry.size.height ? 280 : .infinity,
                                   minHeight: 58)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .accessibilityHint("Encerra a captura e mostra o resultado")
                }
                .padding(geometry.size.width > geometry.size.height ? 20 : 16)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { session.markLiveScreenVisible() }
    }

    private func hudValue(title: String, value: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.bold)).tracking(1)
            Text(value)
                .font(.system(size: prominent ? 48 : 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryScreen: View {
    @ObservedObject var session: WorkoutSession

    var body: some View {
        Group {
            if let error = session.historyError {
                ContentUnavailableView("Histórico indisponível", systemImage: "exclamationmark.triangle",
                                       description: Text(error))
            } else if session.historyRecords.isEmpty {
                ContentUnavailableView("Nenhum treino ainda", systemImage: "clock",
                                       description: Text("Após tocar em Parar, a contagem aparecerá aqui. Gravar vídeo é opcional."))
            } else {
                List(session.historyRecords) { record in
                    NavigationLink {
                        HistoryDetailScreen(session: session, record: record)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Text(record.status == .legacyVideoOnly
                                 ? "Vídeo anterior · contagem indisponível"
                                 : record.hasUsablePose == false
                                   ? "Sem pose detectada · meta não verificada"
                                   : "\(record.repetitions)/\(record.target) repetições contadas · \(durationText(record.elapsedSeconds))")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if record.videoFileName != nil {
                                Label("Vídeo salvo", systemImage: "video.fill")
                                    .font(.caption).foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Histórico")
        .onAppear { session.refreshHistory() }
    }
}

private struct HistoryDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: WorkoutSession
    let record: WorkoutRecord
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(record.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.title2.weight(.bold))
                if record.status == .completed {
                    Text("\(record.repetitions) de \(record.target) repetições")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Tempo: \(durationText(record.elapsedSeconds)) · \(record.camera) · \(record.model)")
                    if record.hasUsablePose == false {
                        Text("Nenhuma pose foi detectada; este treino não permite verificar a meta.")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Gravação anterior sem dados de contagem ou pose.")
                }
                if record.videoFileName != nil {
                    if let player = session.videoPlayer {
                        ZStack(alignment: .topLeading) {
                            VideoPlayer(player: player)
                            PoseOverlay(landmarks: session.landmarks,
                                        imageAspectRatio: session.imageAspectRatio)
                            Text("\(session.repetitions)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                                .padding(12)
                        }
                        .aspectRatio(session.imageAspectRatio, contentMode: .fit)
                        .background(.black)
                        Button("Recomeçar replay") { session.replay() }
                    } else {
                        ProgressView("Abrindo vídeo…")
                    }
                    if let url = session.replayURL {
                        ShareLink("Compartilhar vídeo original, sem contador", item: url)
                    }
                } else {
                    Text("Este treino não foi gravado. O resumo permanece disponível.")
                        .foregroundStyle(.secondary)
                }
                Text("Contagem automática não é avaliação de técnica ou segurança.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Apagar este treino", role: .destructive) { confirmingDelete = true }
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Treino")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { session.openHistoryReplay(record) }
        .confirmationDialog("Apagar este treino e o vídeo deste iPhone?", isPresented: $confirmingDelete) {
            Button("Apagar treino", role: .destructive) {
                session.deleteHistory(record)
                dismiss()
            }
        }
    }
}

private func durationText(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
