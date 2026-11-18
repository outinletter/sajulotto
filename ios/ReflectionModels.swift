import Foundation
import Combine

enum ReflectionTopic: String, CaseIterable, Codable, Identifiable {
    case joy, release, gratitude, achievement, beginning
    static let analysisTopics: [Self] = [.joy, .gratitude, .achievement]
    var journalQuestion: String {
        switch self {
        case .joy: return "그날 기억에 남은 작은 즐거움은 무엇인가요?"
        case .gratitude: return "그날 누구에게, 무엇에 고마웠나요?"
        case .achievement: return "그날 집중했거나 해낸 한 가지는 무엇인가요?"
        case .release, .beginning: return question
        }
    }
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

struct WeeklyWindow: Equatable {
    let start: Date
    let deadline: Date
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.firstWeekday = 1
        return calendar
    }
    init(containing date: Date) {
        start = Self.calendar.dateInterval(of: .weekOfYear, for: date)!.start
        let saturday = Self.calendar.date(byAdding: .day, value: 6, to: start)!
        deadline = Self.calendar.date(bySettingHour: 19, minute: 35, second: 0, of: saturday)!
    }
    func isOpen(at date: Date) -> Bool { date >= start && date < deadline }
    static func date(from iso: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }
    static func label(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "M.d (E)"
        return formatter.string(from: date)
    }
    var label: String { "\(Self.label(start)) 00:00 ~ \(Self.label(deadline)) 19:35 · 한국 시간" }
}

enum SelectedDayQuestions {
    static func title(_ topic: ReflectionTopic) -> String {
        switch topic { case .joy: return "작은 즐거움"; case .release: return "내려놓을 걱정"; case .gratitude: return "고마운 인연"; case .achievement: return "집중할 한 가지"; case .beginning: return "나를 위한 선택" }
    }
    static func question(_ topic: ReflectionTopic, referenceDate: Date, now: Date = Date()) -> String {
        let past = WeeklyWindow.calendar.compare(referenceDate, to: now, toGranularity: .day) == .orderedAscending
        if past {
            switch topic {
            case .joy: return "그날 기억에 남는 작은 즐거움은 무엇이었나요?"
            case .release: return "그날의 걱정 중 지금은 내려놓고 싶은 것은 무엇인가요?"
            case .gratitude: return "그날 고마웠던 사람이나 일은 무엇이었나요?"
            case .achievement: return "그날 집중했거나 해낸 한 가지 일은 무엇인가요?"
            case .beginning: return "그날의 경험에서 다음에도 이어가고 싶은 선택은 무엇인가요?"
            }
        }
        let day = WeeklyWindow.calendar.isDate(referenceDate, inSameDayAs: now) ? "오늘" : "그날"
        switch topic {
        case .joy: return "\(day) 기대하는 작은 즐거움은 무엇인가요?"
        case .release: return "\(day) 잠시 내려놓고 싶은 걱정은 무엇인가요?"
        case .gratitude: return "\(day) 고마움을 전하고 싶은 사람은 누구인가요?"
        case .achievement: return "\(day) 가장 집중하고 싶은 한 가지 일은 무엇인가요?"
        case .beginning: return "\(day) 나를 위해 실천하고 싶은 작은 선택은 무엇인가요?"
        }
    }
}

enum BirthHour: String, CaseIterable {
    case unknown = "unknown", zi = "0", chou = "1", yin = "2", mao = "3", chen = "4", si = "5", wu = "6", wei = "7", shen = "8", you = "9", xu = "10", hai = "11"
    var label: String {
        switch self {
        case .unknown: return "모름"
        case .zi: return "자시 · 23:00~00:59"
        case .chou: return "축시 · 01:00~02:59"
        case .yin: return "인시 · 03:00~04:59"
        case .mao: return "묘시 · 05:00~06:59"
        case .chen: return "진시 · 07:00~08:59"
        case .si: return "사시 · 09:00~10:59"
        case .wu: return "오시 · 11:00~12:59"
        case .wei: return "미시 · 13:00~14:59"
        case .shen: return "신시 · 15:00~16:59"
        case .you: return "유시 · 17:00~18:59"
        case .xu: return "술시 · 19:00~20:59"
        case .hai: return "해시 · 21:00~22:59"
        }
    }
}

enum BirthDateInput {
    static func parse(_ text: String, now: Date = Date()) -> Date? {
        let digits = text.filter(\.isNumber)
        guard digits.count == 8, let year = Int(digits.prefix(4)), let month = Int(digits.dropFirst(4).prefix(2)), let day = Int(digits.suffix(2)), (1900...2027).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let calendar = WeeklyWindow.calendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)), date <= calendar.startOfDay(for: now) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        return check.year == year && check.month == month && check.day == day ? date : nil
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
    var referenceDate: String? = nil
    var question: String? = nil
    var additionalNumberSets: [[Int]]? = nil
    var isJournal: Bool { numbers.isEmpty }
    var displayTitle: String { referenceDate == nil ? topic.title : SelectedDayQuestions.title(topic) }
    var dateText: String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        return formatter.string(from: created)
    }
    var numberText: String { numbers.map { String(format: "%02d", $0) }.joined(separator: " · ") }
    func shareCaption(includeBody: Bool = false) -> String {
        if isJournal {
            let caption = "나의 회고 · \(displayTitle)\n\(referenceDate ?? dateText)"
            return includeBody ? caption + "\n\n" + text : caption
        }
        let caption = "이번 주의 여섯 장면 · \(displayTitle)\n\(referenceDate.map { "기준일: " + $0 + "\n" } ?? "")\(topic.affirmation)\n\(numberText)\n오락용 무작위 조합입니다. 당첨 확률을 높이지 않습니다."
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
            guard cards.allSatisfy({ card in
                if card.isJournal {
                    return card.referenceDate.flatMap(WeeklyWindow.date(from:)) != nil && card.additionalNumberSets == nil
                }
                return card.numbers.count == 6 && Set(card.numbers).count == 6 && card.numbers.allSatisfy { (1...45).contains($0) }
            }) else { throw ReflectionError.invalidCard }
        } catch { cards = []; readable = false; errorMessage = ReflectionError.unreadable.localizedDescription }
    }
    func card(for topic: ReflectionTopic, at date: Date = Date()) -> ReflectionCard? {
        cards.first { !$0.isJournal && $0.weekID == Self.weekID(for: date) && $0.topic == topic }
    }
    static func journalDateKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    func journalCard(for topic: ReflectionTopic, on date: Date) -> ReflectionCard? {
        let key = Self.journalDateKey(date)
        return cards.first { $0.isJournal && $0.referenceDate == key && $0.topic == topic }
    }
    @discardableResult func save(topic: ReflectionTopic, mood: ReflectionMood, text: String, strokes: [ReflectionStroke], editing: UUID? = nil, now: Date = Date(), journalDate: Date? = nil, question: String? = nil) throws -> ReflectionCard {
        guard readable else { throw ReflectionError.unreadable }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ReflectionError.empty }
        guard clean.count <= 500 else { throw ReflectionError.tooLong }
        let existing: ReflectionCard?
        if let editing {
            guard let found = cards.first(where: { $0.id == editing }) else { throw ReflectionError.invalidCard }
            existing = found
        } else if let journalDate {
            existing = journalCard(for: topic, on: journalDate)
        } else { existing = card(for: topic, at: now) }
        let safeStrokes = strokes.prefix(64).map { ReflectionStroke(points: Array($0.points.prefix(256))) }
        guard safeStrokes.flatMap(\.points).allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else { throw ReflectionError.invalidCard }
        let numbers: [Int]
        if let existing { numbers = existing.numbers }
        else if journalDate != nil { numbers = [] }
        else {
            var pool = Array(1...45)
            var random = SystemRandomNumberGenerator()
            for i in 0..<6 { pool.swapAt(i, Int.random(in: i..<pool.count, using: &random)) }
            numbers = Array(pool.prefix(6)).sorted()
        }
        let card = ReflectionCard(id: existing?.id ?? UUID(), created: existing?.created ?? now,
            weekID: existing?.weekID ?? Self.weekID(for: journalDate ?? now), topic: existing?.topic ?? topic,
            mood: mood, text: clean, strokes: safeStrokes, numbers: numbers,
            referenceDate: existing?.referenceDate ?? journalDate.map(Self.journalDateKey),
            question: existing?.question ?? (journalDate == nil ? nil : (question ?? topic.journalQuestion)),
            additionalNumberSets: existing?.additionalNumberSets)
        var updated = cards.filter { $0.id != card.id }; updated.append(card)
        updated.sort { $0.created > $1.created }
        try persist(updated); cards = updated
        return card
    }
    /// Commit the answers and all generated sets together.
    func saveAnalysis(_ entries: [[String: Any]], additionalNumberSets: [[Int]] = [], now: Date = Date()) throws {
        guard readable else { throw ReflectionError.unreadable }
        let topics = Set(additionalNumberSets.isEmpty ? ReflectionTopic.allCases : ReflectionTopic.analysisTopics)
        guard entries.count == topics.count, entries.count + additionalNumberSets.count == 5,
              additionalNumberSets.allSatisfy({ $0.count == 6 && Set($0).count == 6 && $0.allSatisfy { (1...45).contains($0) } }) else {
            throw ReflectionError.invalidCard
        }
        var updated = cards
        var seen = Set<ReflectionTopic>()
        for entry in entries {
            guard let raw = entry["topic"] as? String, let topic = ReflectionTopic(rawValue: raw), seen.insert(topic).inserted,
                  let text = entry["text"] as? String, text.count <= 500,
                  let numbers = entry["numbers"] as? [Int], numbers.count == 6, Set(numbers).count == 6,
                  numbers.allSatisfy({ (1...45).contains($0) }) else { throw ReflectionError.invalidCard }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { throw ReflectionError.empty }
            let referenceDate = entry["referenceDate"] as? String
            let existing: ReflectionCard?
            if let referenceDate {
                existing = cards.first { !$0.isJournal && $0.topic == topic && $0.referenceDate == referenceDate }
            } else {
                existing = card(for: topic, at: now)
            }
            let card = ReflectionCard(id: existing?.id ?? UUID(), created: existing?.created ?? now,
                weekID: Self.weekID(for: now), topic: topic, mood: existing?.mood ?? .calm,
                text: clean, strokes: existing?.strokes ?? [], numbers: numbers.sorted(),
                referenceDate: referenceDate, question: entry["question"] as? String,
                additionalNumberSets: topic == ReflectionTopic.analysisTopics.last && !additionalNumberSets.isEmpty ? additionalNumberSets : nil)
            updated.removeAll { $0.id == card.id }; updated.append(card)
        }
        guard seen == topics else { throw ReflectionError.invalidCard }
        updated.sort { $0.created > $1.created }
        try persist(updated); cards = updated
    }
    func delete(_ card: ReflectionCard) throws {
        guard readable else { throw ReflectionError.unreadable }
        let updated = cards.filter { $0.id != card.id }; try persist(updated); cards = updated
    }
    func deleteReferenceDate(_ referenceDate: String) throws {
        guard readable else { throw ReflectionError.unreadable }
        let updated = cards.filter { $0.referenceDate != referenceDate }
        try persist(updated); cards = updated
    }
    func numberSets(for referenceDate: String) -> [[Int]] {
        let dateCards = cards.filter { !$0.isJournal && $0.referenceDate == referenceDate }
        let extra = dateCards.compactMap(\.additionalNumberSets).first
        let topics = extra == nil ? ReflectionTopic.allCases : ReflectionTopic.analysisTopics
        return topics.compactMap { topic in dateCards.first { $0.topic == topic }?.numbers } + (extra ?? [])
    }
    func reset() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        cards = []; readable = true; errorMessage = nil
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

enum WeeklyTheme: String, CaseIterable, Identifiable {
    case focus = "집중", relationships = "관계", rest = "휴식"
    var id: String { rawValue }

    func prompt(for week: Date) -> (sentence: String, question: String) {
        let prompts: [(String, String)]
        switch self {
        case .focus:
            prompts = [
                ("끝내고 싶은 한 가지를 먼저 정해 보세요.", "이번 주에 가장 마음을 쓰고 싶은 일은 무엇인가요?"),
                ("시작을 작게 만들면 다시 시작하기도 쉬워요.", "오늘 10분만 쓸 수 있다면 무엇부터 할까요?"),
                ("모든 일을 앞당길 필요는 없어요.", "덜어 내면 중요한 일에 도움이 될 것은 무엇인가요?")
            ]
        case .relationships:
            prompts = [
                ("고마운 마음은 작게라도 전할 수 있어요.", "이번 주에 고맙다고 말하고 싶은 사람은 누구인가요?"),
                ("한 번 더 듣는 것만으로 대화가 달라질 때가 있어요.", "이번 주에 누구의 이야기를 여유 있게 듣고 싶나요?"),
                ("나를 대하듯 다정하게, 나에게도 다정하게.", "어떤 관계에서 조금 더 솔직해지고 싶나요?")
            ]
        case .rest:
            prompts = [
                ("쉬는 시간도 한 주의 일부예요.", "이번 주에는 언제 잠깐 쉬어 갈 수 있나요?"),
                ("지금 필요한 만큼만 해도 괜찮아요.", "이번 주에 잠시 내려놓고 싶은 일은 무엇인가요?"),
                ("나를 회복시키는 일은 작아도 좋아요.", "어떤 장면을 다시 만나면 마음이 편안해질까요?")
            ]
        }
        let weekNumber = WeeklyWindow.calendar.component(.weekOfYear, from: week)
        return prompts[(weekNumber - 1) % prompts.count]
    }
}

struct WeeklyReflection: Codable {
    var sentence: String
    var action: String

    static let storageKey = "journal.weekly-reflections.v1"
    static let birthDateKey = "journal.birth-date.v1"
    static let themeKey = "journal.weekly-theme.v1"

    static func load(_ data: Data) -> [String: Self] {
        (try? JSONDecoder().decode([String: Self].self, from: data)) ?? [:]
    }

    static func isBirthdayWeek(birthDate: Date, week: Date) -> Bool {
        let calendar = WeeklyWindow.calendar
        let birthday = calendar.dateComponents([.month, .day], from: birthDate)
        return (0..<7).contains { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week) else { return false }
            let day = calendar.dateComponents([.year, .month, .day], from: date)
            if day.month == birthday.month && day.day == birthday.day { return true }
            // A leap-day birthday is observed on February 28 in common years.
            return birthday.month == 2 && birthday.day == 29 && day.month == 2 && day.day == 28
                && calendar.range(of: .day, in: .month, for: date)?.count == 28
        }
    }
}

enum SentenceNumberGenerator {
    // Version 1 counts modern Hangul jamo strokes, including compound jamo.
    private static let initial = [1, 2, 1, 2, 4, 3, 3, 4, 8, 2, 4, 1, 3, 6, 4, 2, 3, 4, 3]
    private static let vowel = [2, 3, 3, 4, 2, 3, 3, 4, 2, 4, 5, 3, 3, 2, 4, 5, 3, 3, 1, 2, 1]
    private static let final = [0, 1, 2, 3, 1, 4, 4, 2, 3, 4, 6, 7, 5, 6, 7, 6, 3, 4, 6, 2, 4, 1, 3, 4, 2, 3, 4, 3]

    static func strokes(in sentence: String) -> [Int] {
        sentence.precomposedStringWithCanonicalMapping.unicodeScalars.compactMap { scalar in
            guard (0xAC00...0xD7A3).contains(scalar.value) else { return nil }
            let index = Int(scalar.value - 0xAC00)
            return initial[index / 588] + vowel[(index % 588) / 28] + final[index % 28]
        }
    }

    static func sets(for strokes: [Int], weekKey: String) -> [[Int]] {
        guard !strokes.isEmpty else { return [] }
        var state: UInt64 = 14695981039346656037
        for value in Array(weekKey.utf8) + [0] + strokes.map({ UInt8(clamping: $0) }) {
            state = (state ^ UInt64(value)) &* 1099511628211
        }
        func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
        return (0..<5).map { _ in
            var pool = Array(1...45)
            for index in 0..<6 {
                pool.swapAt(index, index + Int(next() % UInt64(pool.count - index)))
            }
            return pool.prefix(6).sorted()
        }
    }
}

struct AnalysisDraftInputs: Codable, Equatable {
    var name = ""
    var birthText = ""
    var timeBranch = "unknown"
    var longitude = 126.978
}
struct AnalysisSessionDraft: Codable {
    let preparedAt: Date
    let chartData: Data
    var answers: [String: String]
    var questions: [String: String]
    var numberSets: [[Int]]
    var questionsStarted: Bool
    var answersCompleted: Bool
    var showingNumbers: Bool
    var answersNeedSaving: Bool
    var savedInput: String
}
struct AnalysisDraftState: Codable {
    var inputs = AnalysisDraftInputs()
    var answers: [String: String] = [:]
    var sessions: [String: AnalysisSessionDraft] = [:]
    var currentSessionKey: String?
}

@MainActor final class AnalysisDraftStore {
    var state = AnalysisDraftState()
    private let file: URL
    private(set) var readable = true
    init(file: URL? = nil) {
        var chosen = file
        #if DEBUG
        if chosen == nil, let raw = ProcessInfo.processInfo.environment["REFLECTION_TEST_STORE"], let id = UUID(uuidString: raw) {
            chosen = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AnalysisUITests", isDirectory: true).appendingPathComponent(id.uuidString + ".json")
        }
        #endif
        self.file = chosen ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Analysis", isDirectory: true).appendingPathComponent("input-and-weekly-sessions.json")
        guard FileManager.default.fileExists(atPath: self.file.path) else { return }
        do { state = try JSONDecoder().decode(AnalysisDraftState.self, from: Data(contentsOf: self.file)) }
        catch { readable = false }
    }
    static func key(birth: Date, time: Date?, longitude: Double, timeBranch: String, now: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = WeeklyWindow.calendar; formatter.timeZone = WeeklyWindow.calendar.timeZone; formatter.dateFormat = "yyyyMMdd"
        let week = formatter.string(from: WeeklyWindow(containing: now).start)
        let date = formatter.string(from: birth)
        formatter.dateFormat = "HH:mm"
        let clock = time.map { formatter.string(from: $0) } ?? timeBranch
        return "\(week)|\(date)|\(clock)|\(longitude)"
    }
    func save() throws {
        guard readable else { throw ReflectionError.unreadable }
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }
    func reset() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        state = AnalysisDraftState(); readable = true
    }
}
