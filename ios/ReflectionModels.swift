import Foundation
import Combine

enum ReflectionTopic: String, CaseIterable, Codable, Identifiable {
    case joy, release, gratitude, achievement, beginning
    var id: String { rawValue }
    var title: String {
        switch self { case .joy: return "좋았던 일"; case .release: return "아쉬웠던 일"; case .gratitude: return "고마웠던 일"; case .achievement: return "내가 해낸 일"; case .beginning: return "다음 주의 바람" }
    }
    var question: String {
        switch self { case .joy: return "이번 주, 나를 웃게 한 순간은?"; case .release: return "마음에 남은 일을 가볍게 내려놓아 볼까요?"; case .gratitude: return "누구에게, 무엇에 고마웠나요?"; case .achievement: return "작아도 내가 해낸 것은 무엇인가요?"; case .beginning: return "다음 주, 나에게 선물하고 싶은 일은?" }
    }
    var symbol: String {
        switch self { case .joy: return "sun.max"; case .release: return "wind"; case .gratitude: return "heart"; case .achievement: return "sparkle"; case .beginning: return "leaf" }
    }
    var affirmation: String {
        switch self { case .joy: return "작은 기쁨도 오래 빛날 수 있어요."; case .release: return "어떤 마음이든 여기에 놓아도 괜찮아요."; case .gratitude: return "고마움을 발견한 오늘을 기억해요."; case .achievement: return "작은 한 걸음도 당신이 해낸 일이에요."; case .beginning: return "다음 시작도 당신의 속도로." }
    }
}

enum ReflectionMood: String, CaseIterable, Codable, Identifiable {
    case warm, calm, fresh, quiet, complex
    var id: String { rawValue }
    var title: String {
        switch self { case .warm: return "따뜻한"; case .calm: return "차분한"; case .fresh: return "산뜻한"; case .quiet: return "고요한"; case .complex: return "복잡한" }
    }
}

struct ReflectionPoint: Codable, Equatable { let x: Double; let y: Double }
struct ReflectionStroke: Codable, Equatable { var points: [ReflectionPoint] }
struct ReflectionCard: Codable, Identifiable, Equatable {
    let id: UUID
    let created: Date
    let weekID: String
    let topic: ReflectionTopic
    var mood: ReflectionMood
    var text: String
    var strokes: [ReflectionStroke]
    let numbers: [Int]
    var dateText: String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        return formatter.string(from: created)
    }
    var numberText: String { numbers.map { String(format: "%02d", $0) }.joined(separator: " · ") }
    func shareCaption(includeBody: Bool = false) -> String {
        let caption = "이번 주의 여섯 장면 · \(topic.title)\n\(topic.affirmation)\n\(numberText)\n오락용 무작위 조합입니다. 당첨 확률을 높이지 않습니다."
        return includeBody ? caption + "\n\n" + text : caption
    }
}

enum ReflectionError: LocalizedError {
    case empty, tooLong, unreadable, invalidCard
    var errorDescription: String? {
        switch self { case .empty: return "한 줄의 이야기를 적어주세요."; case .tooLong: return "이야기는 500자 이내로 적어주세요."; case .unreadable: return "저장 기록을 읽지 못했습니다. 기존 파일을 보호하기 위해 새 저장을 중단했습니다."; case .invalidCard: return "카드 정보를 확인할 수 없습니다." }
    }
}

@MainActor final class ReflectionStore: ObservableObject {
    @Published private(set) var cards: [ReflectionCard] = []
    @Published var errorMessage: String?
    private let file: URL
    private var readable = true
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.firstWeekday = 1
        return calendar
    }
    static func weekID(for date: Date) -> String {
        let calendar = calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        let c = calendar.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    init(file: URL? = nil) {
        var selectedFile = file
        #if DEBUG
        if selectedFile == nil, let raw = ProcessInfo.processInfo.environment["REFLECTION_TEST_STORE"], let id = UUID(uuidString: raw) {
            selectedFile = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ReflectionUITests", isDirectory: true).appendingPathComponent(id.uuidString + ".json")
        }
        #endif
        self.file = selectedFile ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reflection", isDirectory: true).appendingPathComponent("weekly-cards.json")
        guard FileManager.default.fileExists(atPath: self.file.path) else { return }
        do {
            cards = try JSONDecoder().decode([ReflectionCard].self, from: Data(contentsOf: self.file))
            guard cards.allSatisfy({ $0.numbers.count == 6 && Set($0.numbers).count == 6 && $0.numbers.allSatisfy { (1...45).contains($0) } }) else { throw ReflectionError.invalidCard }
        } catch { cards = []; readable = false; errorMessage = ReflectionError.unreadable.localizedDescription }
    }
    func card(for topic: ReflectionTopic, at date: Date = Date()) -> ReflectionCard? {
        cards.first { $0.weekID == Self.weekID(for: date) && $0.topic == topic }
    }
    @discardableResult func save(topic: ReflectionTopic, mood: ReflectionMood, text: String, strokes: [ReflectionStroke], editing: UUID? = nil, now: Date = Date()) throws -> ReflectionCard {
        guard readable else { throw ReflectionError.unreadable }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ReflectionError.empty }
        guard clean.count <= 500 else { throw ReflectionError.tooLong }
        let existing: ReflectionCard?
        if let editing {
            guard let found = cards.first(where: { $0.id == editing }) else { throw ReflectionError.invalidCard }
            existing = found
        } else { existing = card(for: topic, at: now) }
        let safeStrokes = strokes.prefix(64).map { ReflectionStroke(points: Array($0.points.prefix(256))) }
        guard safeStrokes.flatMap(\.points).allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else { throw ReflectionError.invalidCard }
        // Uniform sampling without replacement. Feelings, text, and drawing do not affect the odds.
        var pool = Array(1...45)
        var random = SystemRandomNumberGenerator()
        for i in 0..<6 { pool.swapAt(i, Int.random(in: i..<pool.count, using: &random)) }
        let card = ReflectionCard(id: existing?.id ?? UUID(), created: existing?.created ?? now,
            weekID: existing?.weekID ?? Self.weekID(for: now), topic: existing?.topic ?? topic,
            mood: mood, text: clean, strokes: safeStrokes, numbers: existing?.numbers ?? Array(pool.prefix(6)).sorted())
        var updated = cards.filter { $0.id != card.id }; updated.append(card)
        updated.sort { $0.created > $1.created }
        try persist(updated); cards = updated
        return card
    }
    func delete(_ card: ReflectionCard) throws {
        guard readable else { throw ReflectionError.unreadable }
        let updated = cards.filter { $0.id != card.id }; try persist(updated); cards = updated
    }
    private func persist(_ updated: [ReflectionCard]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(updated)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }
}
