import XCTest

final class SajuLottoUITests: XCTestCase {
    func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
    func testNativeAnalysisSavedNumbersAndConsent() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launchEnvironment["REFLECTION_TEST_STORE"] = UUID().uuidString
        app.launch()
        app.tabBars.buttons["분석"].tap()
        XCTAssertTrue(app.buttons["native-generate"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.webViews.count, 0)
        capture("01-네이티브사주입력")
        app.buttons["native-generate"].tap()
        XCTAssertTrue(app.staticTexts["네 기둥"].waitForExistence(timeout: 10), app.debugDescription)
        capture("02-네이티브원국")
        let save = app.buttons["native-save"]
        for _ in 0..<12 { if save.exists && save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.exists)
        save.tap()
        XCTAssertTrue(app.alerts["안내"].waitForExistence(timeout: 5))
        app.alerts.buttons["확인"].tap()
        app.tabBars.buttons["기록"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "참고 요일:")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "생년월일 (양력): 1995-05-12")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["조합 A"].exists)
        capture("03-네이티브번호기록")
        app.tabBars.buttons["분석"].tap()
        app.buttons["AI 해석"].tap()
        XCTAssertTrue(app.buttons["동의하고 AI 해석 요청"].waitForExistence(timeout: 5))
        capture("05-AI정보전송동의")
        app.buttons["ai-consent-cancel"].tap()
        XCTAssertFalse(app.staticTexts["aiResultText"].exists)
        app.buttons["새 분석"].tap()
        XCTAssertTrue(app.buttons["native-generate"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["AI 해석"].isEnabled)
    }

    func testPrivacyPolicyAvailableOffline() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        app.tabBars.buttons["안내"].tap()
        app.buttons["개인정보 처리방침"].tap()
        XCTAssertTrue(app.staticTexts["기본 분석"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.webViews.count, 0)
        capture("04-앱내개인정보처리방침")
    }

    private func scrollReflection(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.78))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.22)))
    }

    func testReflectionLifecycleAndPrivateSharing() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launchEnvironment["REFLECTION_TEST_STORE"] = UUID().uuidString
        app.launch()
        let topic = app.buttons["reflection-topic-joy"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        if !topic.isHittable { scrollReflection(app) }
        topic.tap()
        let field = app.descendants(matching: .any).matching(identifier: "reflection-text").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("PRIVATE-REFLECTION-TEST")
        if app.buttons["입력 완료"].exists { app.buttons["입력 완료"].tap() }
        let save = app.buttons["reflection-save"]
        for _ in 0..<5 { if save.isHittable { break }; scrollReflection(app) }
        save.tap()
        let result = app.buttons["reflection-result-joy"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        result.tap()
        let anyNumbers = app.descendants(matching: .any).matching(identifier: "reflection-numbers").firstMatch
        XCTAssertTrue(anyNumbers.waitForExistence(timeout: 8), app.debugDescription)
        let original = anyNumbers.label
        XCTAssertFalse(original.isEmpty)
        capture("09-회고카드완성")
        let share = app.buttons["reflection-share"]
        for _ in 0..<4 { if share.isHittable { break }; scrollReflection(app) }
        share.tap()
        let privacy = app.switches["reflection-share-body"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        XCTAssertEqual(privacy.value as? String, "0")
        let preview = app.descendants(matching: .any).matching(identifier: "reflection-share-preview").firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertFalse(preview.staticTexts["PRIVATE-REFLECTION-TEST"].exists)
        capture("10-공유본문기본숨김")
        app.buttons["닫기"].tap()
        app.buttons["reflection-edit"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(" UPDATED")
        if app.buttons["입력 완료"].exists { app.buttons["입력 완료"].tap() }
        for _ in 0..<5 { if save.isHittable { break }; scrollReflection(app) }
        save.tap()
        XCTAssertTrue(anyNumbers.waitForExistence(timeout: 5))
        XCTAssertEqual(anyNumbers.label, original)
        app.terminate(); app.launch()
        app.tabBars.buttons["도감"].tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reflection-card-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        capture("11-주간도감")
        card.tap()
        XCTAssertTrue(anyNumbers.waitForExistence(timeout: 5))
        XCTAssertEqual(anyNumbers.label, original)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "UPDATED")).firstMatch.exists)
    }

    func testInlineReflectionAccumulatesSets() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launchEnvironment["REFLECTION_TEST_STORE"] = UUID().uuidString
        app.launch()
        capture("00-한줄제목과회고홈")
        func record(_ topic: String, text: String) {
            let button = app.buttons["reflection-topic-" + topic]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            for _ in 0..<6 { if button.isHittable && button.frame.maxY < app.tabBars.firstMatch.frame.minY { break }; scrollReflection(app) }
            button.tap()
            let field = app.descendants(matching: .any).matching(identifier: "reflection-text").firstMatch
            for _ in 0..<6 { if field.exists && field.isHittable { break }; scrollReflection(app) }
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            for _ in 0..<4 { if field.isHittable { break }; scrollReflection(app) }
            field.tap(); field.typeText(text)
            if app.buttons["입력 완료"].exists { app.buttons["입력 완료"].tap() }
            capture("12-카드아래펼침입력")
            let save = app.buttons["reflection-save"]
            for _ in 0..<6 { if save.isHittable { break }; scrollReflection(app) }
            save.tap()
            let result = app.buttons["reflection-result-" + topic]
            XCTAssertTrue(result.waitForExistence(timeout: 8))
            XCTAssertTrue(result.isHittable)
        }
        record("joy", text: "FIRST REFLECTION")
        let original = app.buttons["reflection-result-joy"].label
        record("gratitude", text: "SECOND REFLECTION")
        let results = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reflection-result-"))
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(app.buttons["reflection-result-joy"].label, original)
        XCTAssertFalse(app.buttons["reflection-save"].exists)
        capture("13-상단번호두세트누적")
        record("joy", text: " EDITED")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(app.buttons["reflection-result-joy"].label, original)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reflection-result-joy"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reflection-result-gratitude"].exists)
        XCTAssertEqual(results.count, 2)
    }
}
