import XCTest

final class SajuLottoUITests: XCTestCase {
    func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
    func testOfflineAnalysisAndSavedNumbers() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
        capture("01-시작화면")
        let birth = app.webViews.textFields.matching(NSPredicate(format: "value CONTAINS %@", "19950512")).firstMatch
        for _ in 0..<6 {
            if birth.exists && birth.isHittable { break }
            app.webViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(birth.waitForExistence(timeout: 5), app.debugDescription)
        birth.tap()
        birth.typeText("19950512")
        let generate = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "분석 및 번호 생성")).firstMatch
        if !generate.isHittable { app.webViews.firstMatch.swipeUp() }
        generate.tap()
        let result = app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "참고용 번호 5세트가 생성되었습니다")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 45), app.debugDescription)
        capture("02-번호조합")
        app.buttons["번호 저장"].tap()
        XCTAssertTrue(app.alerts["안내"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "저장했습니다")).firstMatch.exists)
        app.alerts.buttons["확인"].tap()
        app.tabBars.buttons["기록"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "행운 요일:")).firstMatch.waitForExistence(timeout: 5))
        capture("03-저장기록")
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "행운 요일:")).firstMatch.tap()
        XCTAssertTrue(app.buttons["번호 공유"].waitForExistence(timeout: 5))
        capture("04-저장번호공유")
        app.buttons["번호 공유"].tap()
        capture("공유시트")
        XCTAssertTrue(app.buttons["header.closeButton"].waitForExistence(timeout: 5))
        app.buttons["header.closeButton"].tap()
        app.tabBars.buttons["안내"].tap()
        XCTAssertTrue(app.staticTexts["개인정보 처리 안내"].waitForExistence(timeout: 5), app.debugDescription)
        capture("05-개인정보안내")
        app.tabBars.buttons["분석"].tap()
        app.buttons["AI 해석"].tap()
        XCTAssertTrue(app.buttons["동의하고 AI 해석 요청"].waitForExistence(timeout: 5))
        app.buttons["취소"].tap()
        XCTAssertFalse(app.staticTexts["aiResultText"].exists)
        app.buttons["AI 해석"].tap()
        app.buttons["동의하고 AI 해석 요청"].tap()
        let resultText = app.staticTexts["aiResultText"]
        let ready = expectation(for: NSPredicate(format: "exists == true AND label.length > 0"), evaluatedWith: resultText)
        wait(for: [ready], timeout: 100)
        XCTAssertFalse(resultText.label.contains("실패") || resultText.label.contains("받지 못") || resultText.label.contains("먼저"), resultText.label)
        capture("06-AI해석")

    }
}
