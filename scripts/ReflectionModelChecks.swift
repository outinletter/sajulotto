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
        let corrupt = Data("broken-json".utf8);try corrupt.write(to:file)
        let protected = ReflectionStore(file:file)
        do { _ = try protected.save(topic:.joy,mood:.warm,text:"새 글",strokes:[]); assertionFailure("corruption overwritten") } catch ReflectionError.unreadable {}
        let preserved = try Data(contentsOf:file); assert(preserved == corrupt)
        print("PASS: KST week boundaries, uniform-sample invariants, stable numbers on edit, reload, private sharing, delete, invalid input and corruption protection")
    }
}
