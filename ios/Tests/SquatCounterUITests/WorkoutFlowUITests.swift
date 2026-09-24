import XCTest

@MainActor
final class WorkoutFlowUITests: XCTestCase {
    func testPreparationAndHistoryNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Seu treino, em foco."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Iniciar treino"].exists)
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
