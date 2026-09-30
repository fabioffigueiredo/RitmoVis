import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import SquatCounterCore

private enum Theme {
    // Temporary high-contrast demo palette. RitmoVis keeps its own name and identity.
    static let background = Color(red: 0.035, green: 0.05, blue: 0.065)
    static let surface = Color(red: 0.09, green: 0.12, blue: 0.15)
    static let accent = Color(red: 0.24, green: 0.78, blue: 0.96)
    static let onAccent = Color(red: 0.02, green: 0.08, blue: 0.11)
    static let border = Color.white.opacity(0.14)
}

private extension TrackingDecision {
    var isSelected: Bool {
        if case .selected = self { return true }
        return false
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var session = WorkoutSession()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var didRunQA = false
    @State private var showAdvancedOptions = false

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
        .preferredColorScheme(.dark)
        .onAppear { session.refreshHistory(); runQAIfRequested() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && (session.isCameraActive || session.isStarting) { session.stop() }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url): session.importVideoFile(url)
            case .failure(let error): session.phaseText = "Não foi possível escolher o vídeo: \(error.localizedDescription)"
            }
        }
    }

    private var preparationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introduction
                if let summary = session.workoutSummary { resultCard(summary) }
                setupCard
                videoAnalysisCard
                if let player = session.videoPlayer { replayCard(player) }
                if showAdvancedOptions { diagnosticsCard }
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
            .foregroundStyle(Theme.onAccent)
            .disabled(session.isFinalizingRecording)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.background.opacity(0.96))
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("RITMOVIS · PROTÓTIPO", systemImage: "figure.strengthtraining.traditional")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            Text("Posicione. Selecione. Treine.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Apoie o iPhone, enquadre o corpo inteiro e toque em Iniciar. Escolha na imagem quem será acompanhado.")
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
            Text("Preparar treino").font(.title2.weight(.bold))
            Label("Agachamento livre", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Picker("Câmera", selection: $session.cameraChoice) {
                ForEach(CameraChoice.allCases) { choice in Text(choice.title).tag(choice) }
            }
            .pickerStyle(.segmented)
            Stepper("Meta: \(session.plan.targetRepetitions) repetições",
                    value: $session.plan.targetRepetitions, in: 1...500)
            Toggle("Gravar vídeo para replay", isOn: $session.recordWorkout)
                .tint(Theme.accent)
            Text("Opcional. A gravação fica neste iPhone, sem áudio; você pode rever a contagem no Histórico.")
                .font(.footnote).foregroundStyle(.white.opacity(0.72))
            DisclosureGroup("Opções avançadas", isExpanded: $showAdvancedOptions) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Modelo de pose", selection: $session.model) {
                        Text("Lite").tag(PoseModel.lite)
                        Text("Full").tag(PoseModel.full)
                    }
                    .pickerStyle(.segmented)
                    Text(session.model == .lite
                         ? "Lite prioriza menor uso de processamento."
                         : "Full usa mais processamento e pode localizar melhor os pontos; não garante mais contagens.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.78))
                    Stepper("Tempo de referência: \(Int(session.plan.duration)) s",
                            value: $session.plan.duration, in: 10...3600, step: 10)
                    Text("O tempo de referência não encerra o treino sozinho.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.72))
                    Toggle("Comandos por gesto · experimental", isOn: $session.gestureControlEnabled)
                        .tint(Theme.accent)
                        .accessibilityIdentifier("gestureControlToggle")
                    if session.gestureControlEnabled {
                        Text("Apoie o celular e afaste-se até aparecer de corpo inteiro. Levante uma mão acima do ombro, palma aberta para a câmera, por 2 s para selecionar e iniciar; punho fechado por 2 s para parar. Aguarde a confirmação. Não se aproxime para mostrar a mão.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.82))
                        Text("Só na câmera ao vivo. Se a mão não for legível ou o foco for perdido, use os botões. Este experimento não corrige o rastreamento no box.")
                            .font(.footnote).foregroundStyle(.yellow)
                    }
                }
                .padding(.top, 12)
            }
            .tint(Theme.accent)
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
            Label("Resumo do treino", systemImage: "chart.bar.fill")
                .font(.headline).foregroundStyle(Theme.accent)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summary.repetitions)").font(.system(size: 54, weight: .bold, design: .rounded))
                Text("/ \(summary.target)").font(.title3.weight(.semibold))
            }
            Text("Repetições detectadas").font(.subheadline.weight(.semibold))
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
                .overlay(DetectedPeopleOverlay(candidates: replayCandidates,
                                               imageAspectRatio: session.imageAspectRatio))
                .overlay {
                    if session.isChoosingVideoPerson {
                        TargetSelectionOverlay(candidates: session.targetCandidates,
                                               imageAspectRatio: session.imageAspectRatio,
                                               tracking: session.trackingDecision,
                                               select: session.selectPersonInVideo)
                    }
                }
                .overlay(alignment: .topLeading) {
                Text("REPETIÇÕES DETECTADAS  \(session.repetitions)")
                        .font(.headline.monospacedDigit())
                        .padding(8)
                        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
                .aspectRatio(session.imageAspectRatio, contentMode: .fit)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("videoReplay")
            Text("\(session.repetitions) · \(session.phaseText)")
                .font(.subheadline.monospacedDigit())
            if session.isChoosingVideoPerson && session.importedVideoHasMultiplePeople {
                Text("Pessoas aptas à análise no quadro: \(session.targetCandidates.count)")
                    .font(.footnote).foregroundStyle(.white.opacity(0.72))
                    .accessibilityIdentifier("eligibleVideoPeopleCount")
                Text("Se a pessoa aparece mas não pode ser selecionada, avance para um quadro com quadril, joelho e tornozelo visíveis ou ajuste luz e enquadramento.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.72))
                    .accessibilityIdentifier("selectionEligibilityExplanation")
            } else {
                Text("Pessoas detectadas no quadro: \(session.targetCandidates.count)")
                    .font(.footnote).foregroundStyle(.white.opacity(0.72))
            }
            if session.importedVideoHasMultiplePeople {
                Text(session.videoBackendUsed).font(.caption)
                if session.isChoosingVideoPerson {
                    Toggle("Usar este quadro em pé como referência (experimental)",
                           isOn: $session.calibrateSelectedStandingFrame)
                        .accessibilityIdentifier("standingCalibration")
                    Text("Ative somente se o aluno estiver em pé neste quadro. Ajusta a contagem de ciclos, não avalia técnica correta.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !session.isChoosingVideoPerson {
                    Button("Escolher outra pessoa ou ponto") { session.choosePersonInVideo() }
                        .buttonStyle(.bordered)
                }
                Text(session.isChoosingVideoPerson
                     ? "Vídeo pausado: toque em Selecionar sobre o aluno. Você também pode avançar para outro quadro antes de escolher."
                     : "Acompanhando a pessoa escolhida. Trechos anteriores à seleção não são contados; se a identidade ficar incerta, escolha novamente.")
                    .font(.footnote).foregroundStyle(.yellow)
            }
            if let notice = session.videoAnalysisNotice {
                Text(notice).font(.subheadline).accessibilityIdentifier("videoAnalysisNotice")
            }
            if let url = session.replayURL {
                ShareLink("Compartilhar vídeo original (sem contador)", item: url)
            }
        }
        .card()
    }

    private var replayCandidates: [PoseCandidate] {
        guard session.importedVideoHasMultiplePeople, !session.isChoosingVideoPerson else {
            return session.targetCandidates
        }
        if case .selected(let index) = session.trackingDecision {
            return session.targetCandidates.filter { $0.index == index }
        }
        return []
    }

    private var videoAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analisar vídeo recebido", systemImage: "video.badge.waveform")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
            Text("Abra um vídeo salvo em Arquivos ou Fotos. O app analisa os quadros no iPhone e mostra a contagem sincronizada durante a reprodução. O clipe não entra no Histórico de treinos.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.82))
            HStack {
                Button { showingFileImporter = true } label: {
                    Label("Arquivos", systemImage: "folder")
                }
                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Label("Fotos", systemImage: "photo.on.rectangle")
                }
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }
                    Task {
                        await session.importVideo(item)
                        pickerItem = nil
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Theme.onAccent)
            .disabled(session.isAnalyzing || session.isCameraActive)
            if showAdvancedOptions {
                Text("Escolha o modo antes de importar. Alterar a opção não recalcula o replay; importe novamente.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.72))
                    .accessibilityIdentifier("importModeTimingNotice")
                Toggle("Apple Vision para vídeos com grupo (experimental)", isOn: $session.useVisionForVideo)
                    .disabled(session.isAnalyzing || session.isCameraActive)
                Toggle("Análise quadro a quadro para grupos", isOn: $session.analyzeGroupFramesIndependently)
                    .disabled(session.isAnalyzing || session.isCameraActive)
                Text("Para vídeos com várias pessoas, o modo quadro a quadro detecta cada imagem sem depender do quadro anterior. Pode ser mais lento; não garante manter a identidade. Apple Vision tem prioridade se os dois modos estiverem ativos. A câmera ao vivo continua com MediaPipe Lite/Full.")
                    .font(.caption).foregroundStyle(.white.opacity(0.72))
            }
            #if DEBUG
            if Bundle.main.url(forResource: "pexels-8837118-1280w", withExtension: "mp4") != nil {
                Button("Ver teste: uma pessoa") { session.testLicensedClip() }
                    .buttonStyle(.bordered)
                    .disabled(session.isAnalyzing)
            }
            if Bundle.main.url(forResource: "pexels-6740245-group", withExtension: "mp4") != nil {
                Button("Ver teste: três pessoas") { session.testGroupClip() }
                    .buttonStyle(.bordered)
                    .disabled(session.isAnalyzing)
            }
            #endif
            if session.isAnalyzing {
                ProgressView("Analisando vídeo no iPhone…")
                    .tint(Theme.accent)
                Button("Cancelar análise") { session.stop() }
                    .buttonStyle(.bordered)
            } else if session.videoPlayer != nil {
                Label(session.phaseText, systemImage: "play.rectangle")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.82))
            } else if session.phaseText != "Aguardando pose" {
                Text(session.phaseText)
                    .font(.subheadline).foregroundStyle(.yellow)
            }
            Text("Por enquanto, use vídeo horizontal. Em grupos, toque no aluno durante o replay para reanalisar; até a seleção, nenhuma repetição é atribuída.")
                .font(.footnote).foregroundStyle(.white.opacity(0.72))
        }
        .card()
    }

    private var diagnosticsCard: some View {
        DisclosureGroup("Testes e métricas") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Os clipes de QA aparecem acima somente no build local que inclui seus arquivos licenciados; mídia não é enviada ao Git nem entra no Histórico.")
                Text("No clipe de grupo, selecione um aluno no replay para reanalisar; sem seleção, a contagem deve ficar em zero.")
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
        if args.contains(where: { $0.hasPrefix("--qa-recorded-camera=") }) {
            session.gestureControlEnabled = args.contains("--qa-gestures")
            session.startCamera()
            return
        }
        if args.contains(where: { $0.hasPrefix("--qa-private-clip=") }) {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            for name in ["qa-clip-diagnostics.json", "qa-clip-failure.json"] {
                try? FileManager.default.removeItem(at: documents.appendingPathComponent(name))
            }
            let diagnostics = ["startedAt": ISO8601DateFormatter().string(from: Date()),
                               "arguments": args.joined(separator: " ")]
            if let data = try? JSONSerialization.data(withJSONObject: diagnostics) {
                try? data.write(to: documents.appendingPathComponent("qa-launch.json"), options: .atomic)
            }
        }
        if let privateClip = args.first(where: { $0.hasPrefix("--qa-private-clip=") }) {
            session.model = args.contains("--qa-model-full") ? .full : .lite
            session.useVisionForVideo = args.contains("--qa-apple-vision")
            session.testPrivateClip(named: String(privateClip.dropFirst("--qa-private-clip=".count)))
        }
        else if args.contains("--qa-clip-full") { session.model = .full; session.testLicensedClip() }
        else if args.contains("--qa-clip-lite") { session.model = .lite; session.testLicensedClip() }
        else if args.contains("--qa-group-clip") { session.model = .lite; session.testGroupClip() }
        else if args.contains("--qa-group-select") {
            session.model = args.contains("--qa-model-full") ? .full : .lite
            session.testGroupClip()
        }
        else if args.contains("--qa-front-camera") {
            session.cameraChoice = .front
            session.startCamera()
            Task { try? await Task.sleep(for: .seconds(12)); session.stop() }
        }
        else if args.contains("--qa-camera") {
            session.startCamera()
            Task { try? await Task.sleep(for: .seconds(12)); session.stop() }
        }
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
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }
}

private struct LiveWorkoutScreen: View {
    @ObservedObject var session: WorkoutSession

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                cameraImage
                PoseOverlay(landmarks: session.landmarks, imageAspectRatio: session.imageAspectRatio)
                    .ignoresSafeArea()
                TargetSelectionOverlay(candidates: session.targetCandidates,
                                       imageAspectRatio: session.imageAspectRatio,
                                       tracking: session.trackingDecision,
                                       select: session.selectPerson)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        hudValue(title: "REPETIÇÕES DETECTADAS", value: "\(session.repetitions)", prominent: true,
                                 compact: geometry.size.width > geometry.size.height)
                        Spacer(minLength: 4)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = session.startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
                            hudValue(title: "TEMPO", value: durationText(elapsed), prominent: false,
                                     compact: geometry.size.width > geometry.size.height)
                        }
                    }
                    #if DEBUG
                    if session.recordedCameraPlayer != nil {
                        Text("TESTE · vídeo gravado — não é câmera ao vivo")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                            .padding(8)
                            .background(.black.opacity(0.85), in: Capsule())
                            .accessibilityIdentifier("recordedCameraSourceNotice")
                    }
                    #endif
                    HStack(spacing: 8) {
                        if session.isStarting { ProgressView().tint(.white) }
                        if session.isRecordingVideo { Image(systemName: "record.circle.fill").foregroundStyle(.red) }
                        Image(systemName: session.trackingDecision.isSelected ? "scope" : "pause.circle.fill")
                            .foregroundStyle(session.trackingDecision.isSelected ? Theme.accent : .yellow)
                        Text(session.isStarting ? "Preparando câmera…" : trackingStatus)
                            .lineLimit(3)
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
                    if session.gestureControlEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(gestureInstruction)
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("gestureInstructions")
                            if session.gestureProgress > 0 {
                                ProgressView(value: session.gestureProgress)
                                    .tint(Theme.accent)
                                    .accessibilityLabel("Confirmação do gesto")
                                    .accessibilityValue("\(Int(session.gestureProgress * 100)) por cento")
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button { session.stop() } label: {
                        Label("Parar treino", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: geometry.size.width > geometry.size.height ? 280 : .infinity,
                                   minHeight: 64)
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

    private var trackingStatus: String {
        switch session.trackingDecision {
        case .selected: "Atleta em foco · \(session.phaseText)"
        case .noSelection: "Toque em Selecionar no atleta"
        case .uncertain: "Foco incerto · contagem pausada"
        case .reselectionRequired: "Atleta perdido · selecione novamente"
        }
    }

    @ViewBuilder private var cameraImage: some View {
        #if DEBUG
        if let player = session.recordedCameraPlayer {
            RecordedVideoPreview(player: player).ignoresSafeArea()
        } else {
            CameraPreview(session: session.captureSession, mirrored: session.cameraChoice == .front,
                          lockedRotationAngle: session.lockedPreviewAngle).ignoresSafeArea()
        }
        #else
        CameraPreview(session: session.captureSession, mirrored: session.cameraChoice == .front,
                      lockedRotationAngle: session.lockedPreviewAngle).ignoresSafeArea()
        #endif
    }

    private var gestureInstruction: String {
        if let notice = session.gestureNotice { return notice }
        switch session.trackingDecision {
        case .noSelection:
            return session.targetCandidates.isEmpty
                ? "Enquadre o corpo inteiro. Depois levante a mão aberta para a câmera por 2 s."
                : "Levante a mão aberta acima do ombro por 2 s. Aguarde a confirmação ou toque em Selecionar."
        case .selected:
            return "Para parar: levante o punho fechado acima do ombro por 2 s. Se não responder, use Parar."
        case .uncertain, .reselectionRequired:
            return "Contagem pausada. Use Selecionar para confirmar o atleta; o gesto não troca de pessoa."
        }
    }

    private func hudValue(title: String, value: String, prominent: Bool, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.bold)).tracking(1)
            Text(value)
                .font(.system(size: prominent ? (compact ? 52 : 72) : (compact ? 30 : 36),
                              weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct TargetSelectionOverlay: View {
    let candidates: [PoseCandidate]
    let imageAspectRatio: Double
    let tracking: TrackingDecision
    let select: (PoseCandidate) -> Void

    var body: some View {
        GeometryReader { geometry in
            let frameAspect = geometry.size.width / max(geometry.size.height, 1)
            let imageAspect = CGFloat(imageAspectRatio)
            let imageWidth = frameAspect > imageAspect ? geometry.size.height * imageAspect : geometry.size.width
            let imageHeight = frameAspect > imageAspect ? geometry.size.height : geometry.size.width / max(imageAspect, 0.01)
            let offsetX = (geometry.size.width - imageWidth) / 2
            let offsetY = (geometry.size.height - imageHeight) / 2
            ForEach(candidates, id: \.index) { candidate in
                let selected = tracking == .selected(index: candidate.index)
                Button { select(candidate) } label: {
                    Text(selected ? "Em foco" : "Selecionar")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(minWidth: 58, minHeight: 52)
                        .background(selected ? Theme.accent : Color.white.opacity(0.95),
                                    in: Capsule())
                        .foregroundStyle(.black)
                }
                .accessibilityLabel(selected ? "Pessoa acompanhada" : "Selecionar pessoa no quadro")
                .position(x: offsetX + CGFloat(candidate.centerX) * imageWidth,
                          y: offsetY + CGFloat(candidate.centerY) * imageHeight)
            }
        }
    }
}

private struct DetectedPeopleOverlay: View {
    let candidates: [PoseCandidate]
    let imageAspectRatio: Double

    var body: some View {
        GeometryReader { geometry in
            let frameAspect = geometry.size.width / max(geometry.size.height, 1)
            let imageAspect = CGFloat(imageAspectRatio)
            let imageWidth = frameAspect > imageAspect ? geometry.size.height * imageAspect : geometry.size.width
            let imageHeight = frameAspect > imageAspect ? geometry.size.height : geometry.size.width / max(imageAspect, 0.01)
            let offsetX = (geometry.size.width - imageWidth) / 2
            let offsetY = (geometry.size.height - imageHeight) / 2
            ForEach(candidates, id: \.index) { candidate in
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.accent, lineWidth: 2)
                    .frame(width: CGFloat(candidate.width) * imageWidth,
                           height: CGFloat(candidate.height) * imageHeight)
                    .position(x: offsetX + CGFloat(candidate.centerX) * imageWidth,
                              y: offsetY + CGFloat(candidate.centerY) * imageHeight)
            }
        }
        .allowsHitTesting(false)
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
