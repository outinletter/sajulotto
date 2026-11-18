import Foundation

@main struct ReflectionModelChecks {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("cards.json")
        let date = ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z")!
        assert(ReflectionStore.weekID(for: date) == "2026-10-11")
        assert(ReflectionStore.weekID(for: ISO8601DateFormatter().date(from:"2026-10-17T14:59:59Z")!) == "2026-10-11")
        assert(ReflectionStore.weekID(for: ISO8601DateFormatter().date(from:"2026-10-17T15:00:00Z")!) == "2026-10-18")
        let boundary = ISO8601DateFormatter().date(from: "2026-10-31T10:35:00Z")!
        let window = WeeklyWindow(containing: boundary)
        assert(window.isOpen(at: window.start))
        assert(window.isOpen(at: boundary.addingTimeInterval(-1)))
        assert(!window.isOpen(at: boundary))
        assert(!window.isOpen(at: ISO8601DateFormatter().date(from:"2026-10-31T14:59:59Z")!))
        assert(WeeklyWindow(containing: ISO8601DateFormatter().date(from:"2026-10-31T15:00:00Z")!).isOpen(at: ISO8601DateFormatter().date(from:"2026-10-31T15:00:00Z")!))
        let reference = WeeklyWindow.date(from:"2026-10-28")!
        assert(SelectedDayQuestions.question(.achievement,referenceDate:reference,now:reference.addingTimeInterval(-86400)).contains("그날"))
        assert(SelectedDayQuestions.question(.achievement,referenceDate:reference,now:reference).contains("오늘"))
        assert(SelectedDayQuestions.question(.achievement,referenceDate:reference,now:reference.addingTimeInterval(86400)).contains("해낸"))
        let inputNow = ISO8601DateFormatter().date(from:"2026-10-31T03:00:00Z")!
        assert(BirthDateInput.parse("19950512",now:inputNow) != nil)
        assert(BirthDateInput.parse("1995-05-12",now:inputNow) != nil)
        assert(BirthDateInput.parse("20240229",now:inputNow) != nil)
        assert(BirthDateInput.parse("20230229",now:inputNow) == nil)
        assert(BirthDateInput.parse("18991231",now:inputNow) == nil)
        assert(BirthDateInput.parse("20270101",now:inputNow) == nil)
        assert(BirthDateInput.parse("20261032",now:inputNow) == nil)
        assert(BirthDateInput.parse("20260001",now:inputNow) == nil)
        assert(BirthDateInput.parse("",now:inputNow) == nil)
        assert(BirthHour.allCases.count == 13 && BirthHour.zi.rawValue == "0" && BirthHour.hai.rawValue == "11")
        let store = ReflectionStore(file:file)
        let stroke = ReflectionStroke(points:[ReflectionPoint(x:0.2,y:0.3),ReflectionPoint(x:0.8,y:0.7)])
        let card = try store.save(topic:.joy,mood:.warm,text:"비공개 회고 테스트",strokes:[stroke],now:date)
        assert(card.numbers.count == 6 && Set(card.numbers).count == 6 && card.numbers.allSatisfy { (1...45).contains($0) })
        assert(card.numbers == card.numbers.sorted())
        let edited = try store.save(topic:.joy,mood:.complex,text:"수정된 비공개 이야기",strokes:[stroke],now:date)
        assert(edited.id == card.id && edited.numbers == card.numbers && store.cards.count == 1)
        assert(!edited.shareCaption().contains(edited.text))
        assert(edited.shareCaption(includeBody:true).contains(edited.text))
        let reopened = ReflectionStore(file:file)
        assert(reopened.cards == store.cards && reopened.cards[0].strokes == [stroke])
        let nextWeek = date.addingTimeInterval(7*86400)
        let next = try reopened.save(topic:.joy,mood:.calm,text:"다음 주",strokes:[],now:nextWeek)
        assert(next.id != card.id && next.weekID != card.weekID)
        let oldEdit = try reopened.save(topic:.joy,mood:.quiet,text:"이전 주 수정",strokes:[],editing:card.id,now:nextWeek)
        assert(oldEdit.weekID == card.weekID && oldEdit.numbers == card.numbers)
        do { _ = try reopened.save(topic:.release,mood:.quiet,text:" \n ",strokes:[],now:date); assertionFailure("blank accepted") } catch ReflectionError.empty {}
        do { _ = try reopened.save(topic:.release,mood:.quiet,text:String(repeating:"가",count:501),strokes:[],now:date); assertionFailure("long accepted") } catch ReflectionError.tooLong {}
        try reopened.delete(next)
        assert(ReflectionStore(file:file).cards.count == 1)
        let entries: [[String: Any]] = ReflectionTopic.allCases.map { ["topic": $0.rawValue, "text": "통합 입력 " + $0.title, "numbers": [1,7,13,22,34,45]] }
        try reopened.saveAnalysis(entries, now: date)
        assert(reopened.cards.count == 5)
        assert(reopened.cards.allSatisfy { $0.numbers == [1,7,13,22,34,45] })
        assert(ReflectionStore(file:file).cards == reopened.cards)
        var invalid = entries; invalid[4]["numbers"] = [1,1,2,3,4,5]
        let beforeBatch = reopened.cards
        do { try reopened.saveAnalysis(invalid, now: date); assertionFailure("invalid batch accepted") } catch ReflectionError.invalidCard {}
        assert(reopened.cards == beforeBatch)
        let legacyJSON = try JSONEncoder().encode(store.cards)
        let decodedLegacy = try JSONDecoder().decode([ReflectionCard].self, from: legacyJSON)
        assert(decodedLegacy.first?.referenceDate == nil)
        let referenceEntries: [[String: Any]] = ReflectionTopic.allCases.enumerated().map { index, topic in
            ["topic":topic.rawValue,"text":"답변 \(index)","numbers":[1,2,3,4,5,6],"referenceDate":"2026-10-14","question":"그날의 질문"]
        }
        try reopened.saveAnalysis(referenceEntries,now:date)
        assert(reopened.cards.filter { $0.weekID == ReflectionStore.weekID(for:date) }.allSatisfy { $0.referenceDate == "2026-10-14" && $0.question == "그날의 질문" })
        let associated = reopened.cards.first!
        let editedReference = try reopened.save(topic:associated.topic,mood:.calm,text:"답변 수정",strokes:[],editing:associated.id,now:date)
        assert(editedReference.referenceDate == "2026-10-14" && editedReference.question == "그날의 질문")
        let corrupt = Data("broken-json".utf8);try corrupt.write(to:file)
        let protected = ReflectionStore(file:file)
        do { _ = try protected.save(topic:.joy,mood:.warm,text:"새 글",strokes:[]); assertionFailure("corruption overwritten") } catch ReflectionError.unreadable {}
        let preserved = try Data(contentsOf:file); assert(preserved == corrupt)
        try protected.reset()
        assert(protected.cards.isEmpty && !FileManager.default.fileExists(atPath: file.path))
        _ = try protected.save(topic:.joy,mood:.warm,text:"초기화 후 새 기록",strokes:[],now:date)
        try protected.reset()
        try protected.reset()
        assert(ReflectionStore(file:file).cards.isEmpty)
        print("PASS: KST week boundaries, uniform-sample invariants, stable numbers on edit, reload, private sharing, delete, invalid input and corruption protection")
    }
}
