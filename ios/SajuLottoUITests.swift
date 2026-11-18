import XCTest

final class SajuLottoUITests: XCTestCase {
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launchEnvironment["REFLECTION_TEST_STORE"] = UUID().uuidString
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<14 {
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 40
            if element.exists && element.isHittable && element.frame.maxY < bottom && element.frame.minY > 110 { return }
            if element.exists && element.frame.minY < 110 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }
    func testSelectedDayQuestionsReadingNumbersAndConfirmedReset() throws {
        let app = launch()
        app.buttons["app-tab-0"].tap()
        XCTAssertTrue(app.staticTexts["천기누설"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.webViews.count, 0)
        XCTAssertFalse(app.buttons["native-generate"].exists)
        capture("01-한줄제목과출생입력")
        let birth = app.textFields["native-birth"]
        reveal(birth, in: app); birth.tap(); birth.typeText("19950512")
        app.buttons["입력 완료"].tap()
        let prepare = app.buttons["native-prepare"]
        reveal(prepare, in: app); prepare.tap()
        let reference = app.staticTexts["reference-day"]
        XCTAssertTrue(reference.waitForExistence(timeout: 10), app.debugDescription)
        let selectedDay = reference.label
        XCTAssertFalse(selectedDay.isEmpty)
        XCTAssertFalse(app.buttons["native-generate"].exists)
        capture("02-선정일선택화면")
        capture("02B-선정일중심질문")
        let topics = ["joy", "gratitude", "achievement"]
        for (index, topic) in topics.enumerated() {
            let section = app.buttons["story-section-" + topic]
            reveal(section, in: app); section.tap()
            let field = app.descendants(matching: .any).matching(identifier: "story-" + topic).firstMatch
            reveal(field, in: app)
            field.tap(); field.typeText("PRIVATE STORY " + topic)
            app.buttons["입력 완료"].tap()
            XCTAssertFalse(app.buttons["native-generate"].exists)
            if index == 0 {
                let reading = app.buttons["native-reading"]
                reveal(reading, in: app); XCTAssertFalse(reading.isEnabled)
            }
        }
        let reading = app.buttons["native-reading"]
        reveal(reading, in: app)
        XCTAssertTrue(reading.isEnabled)
        capture("03-세답변입력완료")
        reading.tap()
        XCTAssertTrue(app.staticTexts["선택일의 일주"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(reference.label, selectedDay)
        XCTAssertFalse(app.staticTexts["조합 A"].exists)
        capture("04-번호생성전선정일사주풀이")
        let generate = app.buttons["native-generate"]
        reveal(generate, in: app); generate.tap()
        XCTAssertEqual(reference.label, selectedDay)
        let revealed = app.descendants(matching: .any).matching(identifier: "number-set-0").firstMatch
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "번호 공개 완료"), object: revealed)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 5), .completed)
        capture("04B-파스텔번호결과")
        let save = app.buttons["native-save"]
        reveal(save, in: app); save.tap()
        XCTAssertTrue(app.alerts["안내"].waitForExistence(timeout: 5))
        app.alerts.buttons["확인"].tap()
        let openCatalog = app.buttons["도감에 저장됨"]
        reveal(openCatalog, in: app); openCatalog.tap()
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog-report-")).firstMatch
        reveal(record, in: app); record.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "생년월일 (양력): 1995-05-12")).firstMatch.waitForExistence(timeout: 5))
        capture("04-저장번호와출생정보")
        app.navigationBars.buttons.firstMatch.tap()
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reflection-card-"))
        XCTAssertEqual(cards.count, 3)
        capture("06-세이야기주간도감")
        cards.firstMatch.tap()
        let numbers = app.descendants(matching: .any).matching(identifier: "reflection-numbers").firstMatch
        XCTAssertTrue(numbers.waitForExistence(timeout: 5))
        let original = numbers.label
        let share = app.buttons["reflection-share"]
        reveal(share, in: app); share.tap()
        let privacy = app.switches["reflection-share-body"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5)); XCTAssertEqual(privacy.value as? String, "0")
        let preview = app.descendants(matching: .any).matching(identifier: "reflection-share-preview").firstMatch
        XCTAssertFalse(preview.label.contains("PRIVATE STORY"))
        capture("07-공유본문기본숨김")
        app.buttons["닫기"].tap()
        let edit = app.buttons["reflection-edit"]
        edit.tap()
        let field = app.descendants(matching: .any).matching(identifier: "reflection-text").firstMatch
        reveal(field, in: app); field.tap(); field.typeText(" UPDATED")
        app.buttons["입력 완료"].tap()
        let update = app.buttons["reflection-save"]
        reveal(update, in: app); update.tap()
        XCTAssertTrue(numbers.waitForExistence(timeout: 5)); XCTAssertEqual(numbers.label, original)
        app.buttons["app-tab-2"].tap()
        let reset = app.buttons["app-reset"]
        reveal(reset, in: app); reset.tap()
        XCTAssertTrue(app.alerts["앱 데이터를 모두 초기화할까요?"].waitForExistence(timeout: 5))
        app.alerts.buttons["취소"].tap()
        app.buttons["app-tab-1"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertEqual(cards.count, 3)
        app.buttons["app-tab-2"].tap()
        reveal(reset, in: app); reset.tap(); app.alerts.buttons["모든 데이터 삭제"].tap()
        app.buttons["app-tab-0"].tap()
        XCTAssertTrue(app.buttons["native-prepare"].waitForExistence(timeout: 5)); XCTAssertFalse(generate.exists)
        app.buttons["app-tab-1"].tap(); XCTAssertEqual(cards.count, 0)
        XCTAssertFalse(app.staticTexts["함께 저장한 출생 정보"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["native-prepare"].waitForExistence(timeout: 5)); XCTAssertFalse(generate.exists)
        capture("08-확인후초기화와재시작")
    }
    func testPrivacyPolicyAvailableOffline() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["천기누설"].waitForExistence(timeout: 10))
        let info = app.buttons["app-tab-2"]
        info.tap()
        let policy = app.buttons["개인정보 처리방침"]
        if !policy.waitForExistence(timeout: 3) { info.tap() }
        XCTAssertTrue(policy.waitForExistence(timeout: 5)); policy.tap()
        XCTAssertTrue(app.staticTexts["기본 분석"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.webViews.count, 0)
        capture("09-오프라인개인정보처리방침")
    }
}
