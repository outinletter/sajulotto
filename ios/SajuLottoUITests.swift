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
        app.tabBars.buttons["분석"].tap()
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

    func testAIResultReopensWithoutRequest() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        app.tabBars.buttons["분석"].tap()
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
        app.buttons["AI 해석"].tap()
        XCTAssertTrue(app.buttons["동의하고 AI 해석 요청"].waitForExistence(timeout: 5))
        app.buttons["동의하고 AI 해석 요청"].tap()
        let resultText = app.staticTexts["aiResultText"]
        let ready = expectation(for: NSPredicate(format: "exists == true AND label.length > 0"), evaluatedWith: resultText)
        wait(for: [ready], timeout: 100)
        XCTAssertFalse(resultText.label.contains("실패") || resultText.label.contains("받지 못") || resultText.label.contains("먼저"), resultText.label)
        capture("06-AI해석")
        let previousResult = resultText.label
        app.buttons["닫기"].tap()
        app.buttons["AI 해석"].tap()
        XCTAssertTrue(resultText.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["동의하고 AI 해석 요청"].exists)
        XCTAssertEqual(resultText.label, previousResult)
        capture("07-AI해석재열기")
    }

    func testSavedInputsAndNumberBalls() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        app.tabBars.buttons["분석"].tap()
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

        app.buttons["번호 저장"].tap()
        XCTAssertTrue(app.alerts["안내"].waitForExistence(timeout: 5))
        app.alerts.buttons["확인"].tap()
        app.tabBars.buttons["기록"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "행운 요일:")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "생년월일 (양력): 1995")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["조합 A"].exists)
        capture("08-입력정보와원형번호")
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
        func record(_ topic: String, text: String) {
            let button = app.buttons["reflection-topic-" + topic]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            for _ in 0..<6 { if button.isHittable { break }; scrollReflection(app) }
            button.tap()
            let field = app.descendants(matching: .any).matching(identifier: "reflection-text").firstMatch
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
