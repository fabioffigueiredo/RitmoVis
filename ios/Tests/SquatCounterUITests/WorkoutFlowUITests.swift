import XCTest

@MainActor
final class WorkoutFlowUITests: XCTestCase {
    // XCTest can mark a scrolled element hittable even when the sticky start
    // action covers its center. Keep interaction inside the content viewport.
    private func revealAboveStartAction(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            let upper = app.navigationBars.firstMatch.frame.maxY + 24
            let lower = app.buttons["Iniciar treino"].frame.minY - 24
            if element.exists && element.isHittable &&
                element.frame.minY >= upper && element.frame.maxY <= lower { return }
            let below = !element.exists || element.frame.maxY > lower
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.3 : 0.7))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(element.exists && element.isHittable, "O controle deve aparecer na área de conteúdo")
        XCTAssertGreaterThanOrEqual(element.frame.minY, app.navigationBars.firstMatch.frame.maxY + 24)
        XCTAssertLessThanOrEqual(element.frame.maxY, app.buttons["Iniciar treino"].frame.minY - 24,
                                 "O controle não deve ficar sob a ação fixa")
    }

    func testRecordedVideoInputIsLabelledAndAllowsSelectionAndStop() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-recorded-camera=pexels-8837118-1280w.mp4"]
        app.launch()
        let source = app.staticTexts["recordedCameraSourceNotice"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertTrue(source.label.contains("não é câmera ao vivo"))
        let select = app.buttons["Selecionar pessoa no quadro"].firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: 15))
        select.tap()
        XCTAssertTrue(app.buttons["Pessoa acompanhada"].waitForExistence(timeout: 5))
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Recorded input — portrait — not live camera"
        portrait.lifetime = .keepAlways
        add(portrait)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        let stop = app.buttons["Parar treino"]
        XCTAssertTrue(stop.isHittable)
        XCTAssertTrue(source.exists)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Recorded input — landscape — not live camera"
        landscape.lifetime = .keepAlways
        add(landscape)
        stop.tap()
        XCTAssertTrue(app.buttons["Iniciar treino"].waitForExistence(timeout: 10))
    }

    func testGestureInstructionsStayVisibleWithManualStopInBothOrientations() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-synthetic-camera", "--qa-synthetic-targets"]
        app.launch()
        let advanced = app.buttons["Opções avançadas"]
        revealAboveStartAction(advanced, in: app)
        advanced.tap()
        let toggle = app.switches["gestureControlToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")
        revealAboveStartAction(toggle, in: app)
        XCTAssertTrue(toggle.isHittable)
        let control = toggle.switches.firstMatch
        if control.exists { control.tap() } else { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "1", "Gesto deve estar habilitado antes de abrir a interface")
        app.buttons["Iniciar treino"].tap()
        let instructions = app.staticTexts["gestureInstructions"]
        XCTAssertTrue(instructions.waitForExistence(timeout: 10))
        XCTAssertTrue(instructions.label.contains("mão aberta"))
        XCTAssertTrue(instructions.label.contains("2 s"))
        let select = app.buttons["Selecionar pessoa no quadro"]
        select.tap()
        XCTAssertTrue(instructions.label.contains("punho fechado"))
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["Parar treino"].isHittable)
        XCTAssertTrue(instructions.exists)
        app.buttons["Parar treino"].tap()
        XCTAssertTrue(app.buttons["Iniciar treino"].waitForExistence(timeout: 10))
    }

    func testGroupSelectionKeepsReplayAndShowsAnalysis() {
        let app = XCUIApplication()
        // Exercise the real cached replay with MediaPipe on Simulator.
        // Vision inference is measured separately on the physical device.
        app.launchArguments = ["--qa-group-clip", "--qa-group-mediapipe"]
        app.launch()
        let select = app.buttons["Selecionar pessoa no quadro"].firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: 120))
        let eligibleCount = app.staticTexts["eligibleVideoPeopleCount"]
        XCTAssertTrue(eligibleCount.exists)
        XCTAssertTrue(eligibleCount.label.hasPrefix("Pessoas aptas à análise no quadro:"))
        let explanation = app.staticTexts["selectionEligibilityExplanation"]
        XCTAssertTrue(explanation.exists)
        XCTAssertTrue(explanation.label.contains("joelho"))
        XCTAssertTrue(explanation.label.contains("enquadramento"))
        revealAboveStartAction(select, in: app)
        XCTAssertTrue(select.isHittable)
        select.tap()
        let notice = app.staticTexts["videoAnalysisNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        let complete = NSPredicate(format: "label BEGINSWITH %@", "Trecho analisado:")
        expectation(for: complete, evaluatedWith: notice)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["Escolher outra pessoa ou ponto"].exists)
        XCTAssertFalse(app.buttons["Parar análise"].exists)
        let chooseAgain = app.buttons["Escolher outra pessoa ou ponto"]
        revealAboveStartAction(chooseAgain, in: app)
        chooseAgain.tap()
        XCTAssertTrue(select.waitForExistence(timeout: 5))
    }

    func testPreparationAndHistoryNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Posicione. Selecione. Treine."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Iniciar treino"].exists)
        XCTAssertTrue(app.staticTexts["Analisar vídeo recebido"].exists)
        let modeTiming = app.staticTexts["importModeTimingNotice"]
        XCTAssertFalse(modeTiming.exists)
        app.buttons["Opções avançadas"].tap()
        XCTAssertTrue(modeTiming.exists)
        XCTAssertTrue(modeTiming.label.contains("antes de importar"))
        XCTAssertTrue(modeTiming.label.contains("importe novamente"))
        XCTAssertTrue(app.buttons["Arquivos"].exists)
        XCTAssertTrue(app.buttons["Fotos"].exists)
        app.tabBars.buttons["Histórico"].tap()
        XCTAssertTrue(app.navigationBars["Histórico"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Treino"].tap()
        XCTAssertTrue(app.buttons["Iniciar treino"].exists)
    }

    func testDemoPreparationKeepsTechnicalOptionsOutOfPrimaryFlow() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Posicione. Selecione. Treine."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Iniciar treino"].exists)
        XCTAssertTrue(app.buttons["Opções avançadas"].exists)
        XCTAssertFalse(app.segmentedControls.buttons["Lite"].exists)
        app.buttons["Opções avançadas"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Lite"].waitForExistence(timeout: 5))
    }

    func testDemoResultCallsCountsDetectedNotCorrect() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-synthetic-camera", "--qa-synthetic-targets"]
        app.launch()
        app.buttons["Iniciar treino"].tap()
        XCTAssertTrue(app.staticTexts["REPETIÇÕES DETECTADAS"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Parar treino"].exists)
    }

    func testLargeTextKeepsStartAndStopReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL",
                               "--qa-synthetic-camera"]
        app.launch()
        let start = app.buttons["Iniciar treino"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isHittable)
        start.tap()
        let stop = app.buttons["Parar treino"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        XCTAssertTrue(stop.isHittable)
    }

    func testImmersiveControlsRemainAvailableAfterRotation() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-synthetic-camera"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }

        let start = app.buttons["Iniciar treino"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let stop = app.buttons["Parar treino"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["REPETIÇÕES DETECTADAS"].exists)
        XCTAssertTrue(app.staticTexts["TEMPO"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
    }

    func testCanStartWorkoutAfterClipAnalysis() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-clip-lite", "--qa-synthetic-camera"]
        app.launch()

        let start = app.buttons["Iniciar treino"]
        XCTAssertTrue(app.buttons["Parar análise"].waitForExistence(timeout: 10))
        XCTAssertTrue(start.waitForExistence(timeout: 120), "A análise do clipe deve liberar Iniciar treino")
        XCTAssertTrue(app.staticTexts["Replay"].exists, "O clipe deve produzir replay, não apenas encerrar a análise")
        start.tap()
        XCTAssertTrue(app.buttons["Parar treino"].waitForExistence(timeout: 10))
    }

    func testPersonSelectionControlInImmersiveScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-synthetic-camera", "--qa-synthetic-targets"]
        app.launch()
        app.buttons["Iniciar treino"].tap()
        let select = app.buttons["Selecionar pessoa no quadro"]
        XCTAssertTrue(select.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Pessoa acompanhada"].exists)
        select.tap()
        XCTAssertTrue(app.buttons["Pessoa acompanhada"].waitForExistence(timeout: 5))
        app.buttons["Parar treino"].tap()
    }
}
