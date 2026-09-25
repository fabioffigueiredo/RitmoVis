import XCTest

@MainActor
final class WorkoutFlowUITests: XCTestCase {
    func testGroupSelectionKeepsReplayAndShowsAnalysis() {
        let app = XCUIApplication()
        // Exercise the real cached replay with MediaPipe on Simulator.
        // Vision inference is measured separately on the physical device.
        app.launchArguments = ["--qa-group-clip", "--qa-group-mediapipe"]
        app.launch()
        let select = app.buttons["Selecionar pessoa no quadro"].firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: 120))
        for _ in 0..<5 where !select.isHittable { app.swipeUp() }
        XCTAssertTrue(select.isHittable)
        select.tap()
        let notice = app.staticTexts["videoAnalysisNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        let complete = NSPredicate(format: "label BEGINSWITH %@", "Trecho analisado:")
        expectation(for: complete, evaluatedWith: notice)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["Escolher outra pessoa ou ponto"].exists)
        XCTAssertFalse(app.buttons["Parar análise"].exists)
        app.buttons["Escolher outra pessoa ou ponto"].tap()
        XCTAssertTrue(select.waitForExistence(timeout: 5))
    }

    func testPreparationAndHistoryNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Seu treino, em foco."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Iniciar treino"].exists)
        XCTAssertTrue(app.staticTexts["Analisar vídeo recebido"].exists)
        XCTAssertTrue(app.buttons["Arquivos"].exists)
        XCTAssertTrue(app.buttons["Fotos"].exists)
        XCTAssertTrue(app.switches["Análise quadro a quadro para grupos"].exists)
        app.tabBars.buttons["Histórico"].tap()
        XCTAssertTrue(app.navigationBars["Histórico"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Treino"].tap()
        XCTAssertTrue(app.buttons["Iniciar treino"].exists)
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
        XCTAssertTrue(app.staticTexts["REPETIÇÕES"].exists)
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
