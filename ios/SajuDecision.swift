import SwiftUI
import UserNotifications

extension Element {
    var pastel: Color { bead }
    var color: Color {
        [Color(red: 0.37, green: 0.61, blue: 0.47), Color(red: 0.85, green: 0.45, blue: 0.31), Color(red: 0.78, green: 0.64, blue: 0.29),
         Color(red: 0.55, green: 0.59, blue: 0.71), Color(red: 0.31, green: 0.53, blue: 0.78)][rawValue]
    }
    /// 구슬 색 (B안: 톤 낮춘 파스텔) / 구슬 위 글자색
    var bead: Color {
        [Color(red: 0.725, green: 0.831, blue: 0.761), Color(red: 0.929, green: 0.722, blue: 0.604), Color(red: 0.902, green: 0.827, blue: 0.627),
         Color(red: 0.765, green: 0.800, blue: 0.878), Color(red: 0.612, green: 0.714, blue: 0.890)][rawValue]
    }
    var beadInk: Color {
        [Color(red: 0.141, green: 0.208, blue: 0.169), Color(red: 0.290, green: 0.169, blue: 0.106), Color(red: 0.263, green: 0.216, blue: 0.102),
         Color(red: 0.165, green: 0.200, blue: 0.314), Color(red: 0.122, green: 0.192, blue: 0.341)][rawValue]
    }
}

// MARK: - 주간 번호 (한 주 시간대에 한 세트만 생성)

enum SajuNumberGenerator {
    static func hash(_ text: String) -> UInt64 {
        var state: UInt64 = 14695981039346656037
        for byte in text.utf8 { state = (state ^ UInt64(byte)) &* 1099511628211 }
        return state
    }
    static func generator(_ seed: UInt64) -> () -> UInt64 {
        var state = seed
        return {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
    }

    /// 고른 날의 천간·지지 오행과 내게 필요한 오행(용신)에 가중치를 두고 5세트(각 6개)를 뽑는다. 같은 입력이면 같은 결과.
    @MainActor static func sets(chart: SajuChart, day: DayFortune) -> [[Int]] {
        let boosted: Set<Element> = [chart.lacking, day.pillar.stemElement, day.pillar.branchElement]
        let dayKey = ReflectionStore.journalDateKey(day.date)
        return (0..<5).map { setIndex in
            var pool = Array(1...45)
            var next = generator(hash(chart.signature + "|" + dayKey + "|\(setIndex)"))
            var picked: [Int] = []
            while picked.count < 6 {
                let weights = pool.map { (n: Int) -> UInt64 in
                    let e = Element.of(number: n)
                    return e == chart.lacking ? 4 : (boosted.contains(e) ? 2 : 1)
                }
                var roll = next() % weights.reduce(0, +)
                for (i, w) in weights.enumerated() {
                    if roll < w { picked.append(pool.remove(at: i)); break }
                    roll -= w
                }
            }
            return picked.sorted()
        }
    }
}

// MARK: - 이번 주 좋은 날 고르기

struct DayFortune: Identifiable {
    var id: Date { date }
    let date: Date
    let pillar: Pillar
    let raw: Int
    let reasons: [String]
    var pct: Int { min(98, max(45, 60 + raw * 4)) }
    var summary: String {
        "\(pillar.label)일 · \(pillar.stemElement.nature) 기운 · " + (reasons.isEmpty ? "무난하게 흘러가는 날이에요." : reasons.prefix(2).joined(separator: " "))
    }
    var label: String { WeeklyWindow.label(date) }
}

enum DayPicker {
    private static let harmony: Set<[Int]> = [[0, 1], [2, 11], [3, 10], [4, 9], [5, 8], [6, 7]]

    static func evaluate(chart: SajuChart, date: Date) -> DayFortune {
        let p = SajuEngine.dayPillar(date)
        let me = chart.dayMaster
        var raw = 0
        var reasons: [String] = []
        let yong = chart.yongshin, hee = chart.heeshin, gi = chart.gishin
        // 용신·희신·기신과 그날 간지의 오행
        for (element, weight, isStem) in [(p.stemElement, 1.0, true), (p.branchElement, 0.7, false)] {
            if element == yong { raw += Int((4 * weight).rounded()); if isStem { reasons.append("내게 필요한 \(yong.nature) 기운이 가득해요.") } else { reasons.append("땅의 기운이 \(yong.nature)을 채워 줘요.") } }
            else if element == hee { raw += Int((2 * weight).rounded()); if isStem { reasons.append("\(yong.nature) 기운을 돕는 \(hee.nature)의 날이에요.") } }
            else if element == gi { raw -= Int((3 * weight).rounded()); if isStem { reasons.append("\(gi.nature) 기운이 \(yong.nature)을 누르는 날이라 차분히 가요.") } }
        }
        // 십성: 신강이면 설기·재·관(식상·재성·관성)의 날, 신약이면 비겁·인성의 날이 이롭다
        let god = chart.tenGod(ofStem: p.stem)
        let strong = chart.supportRatio >= 0.5
        let helpful = strong ? [1, 2, 3].contains(god.group) : [0, 4].contains(god.group)
        if helpful { raw += 1; reasons.append("\(god.name)의 날이라 \(strong ? "넘치는 힘을 쓰기 좋아요" : "힘을 보태 줘요").") }
        else { raw -= 1 }
        // 일지·월지와의 합충
        let harmonyPairs: Set<[Int]> = [[0, 1], [2, 11], [3, 10], [4, 9], [5, 8], [6, 7]]
        let dayPair = [min(p.branch, chart.day.branch), max(p.branch, chart.day.branch)]
        if harmonyPairs.contains(dayPair) { raw += 2; reasons.append("내 일지와 합이라 일이 순조로워요.") }
        else if (p.branch - chart.day.branch + 12) % 12 == 6 { raw -= 2; reasons.append("내 일지와 충이라 변화가 많은 날이에요.") }
        if (p.branch - chart.month.branch + 12) % 12 == 6 { raw -= 1 }
        return DayFortune(date: date, pillar: p, raw: raw, reasons: reasons)
    }

    static func week(chart: SajuChart, week: WeeklyWindow) -> [DayFortune] {
        (0..<7).compactMap { WeeklyWindow.calendar.date(byAdding: .day, value: $0, to: week.start) }.map { evaluate(chart: chart, date: $0) }
    }
}

struct WeeklyNumberRecord: Codable { var sets: [[Int]]; let created: Date; var day: Date? = nil }

enum Pastel {
    static let setTints: [Color] = Element.allCases.map(\.bead)
}

/// 번호 구슬: 번호 끝자리의 오행 색, 작은 하이라이트
struct Bead: View {
    let number: Int
    var size: CGFloat = 46
    var body: some View {
        let e = Element.of(number: number)
        Text("\(number)").font(.system(size: size * 0.4, weight: .semibold, design: .rounded)).monospacedDigit()
            .foregroundStyle(e.beadInk)
            .frame(width: size, height: size)
            .background(e.bead, in: Circle())
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(0.6)).frame(width: size * 0.2, height: size * 0.11)
                    .rotationEffect(.degrees(-28)).offset(x: size * 0.2, y: size * 0.14)
            }
            .accessibilityLabel("\(number)")
    }
}

/// 번호 세트를 한 행씩 보여주는 카드. counts[i]개까지 구슬을 보여주고 나머지는 빈 자리로 둔다.
struct NumberRows: View {
    let sets: [[Int]]
    let counts: [Int]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sets.enumerated()), id: \.offset) { i, numbers in
                let shown = counts.indices.contains(i) ? counts[i] : 0
                HStack(spacing: 8) {
                    Text("\(i + 1)").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.secondary).frame(width: 16)
                    HStack(spacing: 0) {
                        ForEach(Array(numbers.enumerated()), id: \.offset) { j, n in
                            ZStack {
                                Circle().strokeBorder(AppTheme.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                                    .frame(width: 40, height: 40)
                                if j < shown {
                                    Bead(number: n, size: 40).transition(.scale(scale: 0.2).combined(with: .opacity))
                                }
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 9)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(shown == 0 ? "\(i + 1)세트 비어 있음" : "\(i + 1)세트 " + numbers.prefix(shown).map(String.init).joined(separator: ", "))
                .accessibilityIdentifier("number-set-\(i)")
                if i < sets.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .appGlass(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - 오늘의 선택

struct DecisionResult: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let options: [String]
    let winner: String
    let reason: String
    var feedback: Int? = nil   // 1 좋았어요, 0 보통, -1 별로
    var kind: String? = nil
    var match: Int? = nil
    var matches: [Int]? = nil   // options와 같은 순서의 일치도
}

struct DecisionEngine {
    let need: Element?
    let signature: String
    let today: Pillar
    init(chart: SajuChart?, today: Pillar) { need = chart?.lacking; signature = chart?.signature ?? ""; self.today = today }
    init(need: Element?, signature: String, today: Pillar) { self.need = need; self.signature = signature; self.today = today }

    struct Scored {
        let text: String; let element: Element; let score: Double; let note: String
        var match: Int { min(98, max(50, Int(58 + score * 8))) }
    }

    private static let keywords: [(Element, [String])] = [
        (.water, ["아메리카노", "커피", "짜장", "냉면", "해산물", "회", "물", "콜라", "맥주", "생선", "순대", "수영", "블랙", "검정", "네이비", "남색", "아이스티", "참는다", "미룬다", "영화관", "집밥"]),
        (.fire, ["짬뽕", "떡볶이", "치킨", "마라", "불고기", "매운", "라면", "삼겹", "고기", "닭", "커리", "탕수육", "러닝", "헬스", "빨강", "레드", "핑크", "산다", "지른다", "노래방", "곱창", "제육", "족발", "배달"]),
        (.wood, ["샐러드", "비빔밥", "채소", "나물", "녹차", "차", "과일", "쌈", "김밥", "스무디", "요가", "산책", "등산", "초록", "그린", "카키", "공원", "전시", "보쌈", "외식"]),
        (.earth, ["라떼", "우유", "피자", "파스타", "빵", "죽", "감자", "밥", "카페", "케이크", "치즈", "집콕", "베이지", "노랑", "브라운", "보드게임", "칼국수", "김치찌개"]),
        (.metal, ["돈까스", "초밥", "국수", "만두", "튀김", "스테이크", "버거", "햄버거", "샌드위치", "쌀국수", "자전거", "클라이밍", "흰", "화이트", "실버", "회색", "볼링", "방탈출", "파전"]),
    ]

    static func element(for text: String) -> Element {
        let clean = text.replacingOccurrences(of: " ", with: "")
        for (element, words) in keywords where words.contains(where: { clean.contains($0) }) { return element }
        return Element(rawValue: Int(SajuNumberGenerator.hash(clean) % 5))!
    }

    func evaluate(_ options: [String], dayKey: String) -> [Scored] {
        let dayElement = today.stemElement
        return options.map { text in
            let e = Self.element(for: text)
            var score = 0.0
            var notes: [String] = []
            if e == need { score += 3; notes.append("내 사주에 필요한 \(e.nature)(\(e.hanja)) 기운을 채워요") }
            if dayElement.generates == e { score += 2; notes.append("오늘의 \(dayElement.nature) 기운이 \(e.nature) 기운을 북돋아요") }
            else if dayElement == e { score += 1; notes.append("오늘의 \(e.nature) 기운과 같은 결이에요") }
            if dayElement.controls == e { score -= 1.5; notes.append("오늘의 \(dayElement.nature) 기운에 눌리는 날이에요") }
            let tiebreak = Double(SajuNumberGenerator.hash(text + dayKey + signature) % 1000) / 1000
            return Scored(text: text, element: e, score: score + tiebreak,
                          note: notes.first ?? "오늘의 흐름과 무난하게 어울려요")
        }
    }
}

// MARK: - 화면 공통: 사주 프로필

enum SajuProfile {
    static let hourKey = "sajuBirthHour"
    /// 성별·출생지·정확한 시각을 한 문자열로 저장 ("m|서울|1430"). 바뀌면 화면이 다시 계산된다.
    static let extraKey = "sajuProfileExtra"

    struct Extra: Equatable {
        var gender: Gender? = nil
        var place = BirthPlace.defaultPlace
        var exact = ""      // "HHMM" 4자리 또는 빈 문자열
        init() {}
        init(_ raw: String) {
            let p = raw.components(separatedBy: "|")
            if p.count == 3 { gender = Gender(rawValue: p[0]); place = BirthPlace.named(p[1]); exact = p[2] }
        }
        var raw: String { "\(gender?.rawValue ?? "")|\(place.name)|\(exact)" }
        var time: (hour: Int, minute: Int)? {
            guard exact.count == 4, let h = Int(exact.prefix(2)), let m = Int(exact.suffix(2)), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
            return (h, m)
        }
    }

    static func chart(birthText: String, hourRaw: String, extra: String = "") -> SajuChart? {
        guard let birth = BirthDateInput.parse(birthText) else { return nil }
        let e = Extra(extra)
        let time: SajuEngine.Time?
        if let t = e.time { time = .init(hour: t.hour, minute: t.minute, exact: true) }
        else if let branch = Int(hourRaw) { time = .init(hour: (branch * 2) % 24, minute: 0, exact: false) }
        else { time = nil }
        return SajuEngine.chart(birth: birth, time: time, gender: e.gender, place: e.place)
    }
}

struct SajuProfileCard: View {
    @AppStorage(WeeklyReflection.birthDateKey) private var savedBirth = ""
    @AppStorage(SajuProfile.hourKey) private var savedHour = BirthHour.unknown.rawValue
    @AppStorage(SajuProfile.extraKey) private var savedExtra = ""
    @State private var birth = ""
    @State private var hour = BirthHour.unknown.rawValue
    @State private var extra = SajuProfile.Extra()
    @State private var justSaved = false
    @FocusState private var focused: Bool

    private var valid: Bool { BirthDateInput.parse(birth) != nil }
    private var exactValid: Bool { extra.exact.isEmpty || extra.time != nil }
    private var changed: Bool { birth != savedBirth || hour != savedHour || extra.raw != SajuProfile.Extra(savedExtra).raw || savedExtra.isEmpty && !savedBirth.isEmpty }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("내 사주 정보", systemImage: "person.text.rectangle").font(.headline)
                field("양력 생년월일 8자리 (예: 19950512)", text: $birth, id: "profile-birth")
                    .onChange(of: birth) { _, v in birth = String(v.filter(\.isNumber).prefix(8)); justSaved = false }
                if birth.count == 8 && !valid {
                    Text("실제 생년월일을 입력해 주세요. (1900~2027년)").font(.footnote).foregroundStyle(Element.fire.color)
                }
                row("태어난 시간") {
                    Picker("태어난 시간", selection: $hour) { ForEach(BirthHour.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) } }
                        .pickerStyle(.menu).accessibilityIdentifier("birth-hour")
                }
                field("정확한 시각 (선택, 예: 1430)", text: $extra.exact, id: "profile-exact")
                    .onChange(of: extra.exact) { _, v in extra.exact = String(v.filter(\.isNumber).prefix(4)); justSaved = false }
                if !exactValid && extra.exact.count == 4 { Text("00:00~23:59 사이로 입력해 주세요.").font(.footnote).foregroundStyle(Element.fire.color) }
                row("성별 (대운 계산용)") {
                    Picker("성별", selection: Binding(get: { extra.gender?.rawValue ?? "" }, set: { extra.gender = Gender(rawValue: $0); justSaved = false })) {
                        Text("선택 안 함").tag(""); Text("남성").tag("m"); Text("여성").tag("f")
                    }.pickerStyle(.menu).accessibilityIdentifier("profile-gender")
                }
                row("출생지 (시각 보정용)") {
                    Picker("출생지", selection: Binding(get: { extra.place.name }, set: { extra.place = BirthPlace.named($0); justSaved = false })) {
                        ForEach(BirthPlace.all, id: \.name) { Text($0.name).tag($0.name) }
                    }.pickerStyle(.menu).accessibilityIdentifier("profile-place")
                }
                Button(justSaved && !changed ? "저장됨" : "저장") {
                    savedBirth = birth; savedHour = hour; savedExtra = extra.raw; focused = false; justSaved = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                .buttonStyle(ToneButtonStyle(element: SajuEngine.dayPillar(Date()).stemElement))
                .disabled(!valid || !exactValid || !changed).accessibilityIdentifier("profile-save")
                if !savedBirth.isEmpty {
                    Button("저장한 정보 삭제", role: .destructive) {
                        savedBirth = ""; savedHour = BirthHour.unknown.rawValue; savedExtra = ""
                        birth = ""; hour = BirthHour.unknown.rawValue; extra = SajuProfile.Extra(); focused = false
                    }.font(.subheadline)
                }
                Text("입력한 정보는 이 기기에만 저장돼요. 정확한 시각과 출생지를 넣으면 지방시 보정이 적용되고, 모르면 비워 두세요.")
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
            }
        }
        .onAppear { birth = savedBirth; hour = savedHour; extra = SajuProfile.Extra(savedExtra) }
    }

    private func field(_ title: String, text: Binding<String>, id: String) -> some View {
        TextField(title, text: text).keyboardType(.numberPad).focused($focused)
            .padding(.horizontal, 14).padding(.vertical, 12).background(AppTheme.surface.opacity(0.7), in: Capsule())
            .accessibilityIdentifier(id)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { focused = false } } }
    }

    private func row<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        HStack { Text(title).font(.subheadline); Spacer(); content() }
    }
}

struct ToneChip: View {
    let text: String
    var body: some View {
        let e = SajuEngine.dayPillar(Date()).stemElement
        Text(text).font(.footnote.weight(.bold)).foregroundStyle(e.beadInk)
            .padding(.horizontal, 10).padding(.vertical, 5).background(e.bead, in: Capsule())
    }
}

// MARK: - 내 사주 자세히 보기

struct SajuDetailView: View {
    @AppStorage(WeeklyReflection.birthDateKey) private var birthText = ""
    @AppStorage(SajuProfile.hourKey) private var hourRaw = BirthHour.unknown.rawValue
    @AppStorage(SajuProfile.extraKey) private var profileExtra = ""
    private var chart: SajuChart? { SajuProfile.chart(birthText: birthText, hourRaw: hourRaw, extra: profileExtra) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let chart {
                    pillarsCard(chart)
                    strengthCard(chart)
                    elementsCard(chart)
                    luckCard(chart)
                    if !chart.daeun.isEmpty { daeunCard(chart) }
                    if !chart.notes.isEmpty { notesCard(chart) }
                } else {
                    Text("생년월일을 저장하면 내 사주를 볼 수 있어요.").font(.subheadline).foregroundStyle(AppTheme.secondary)
                    SajuProfileCard()
                }
                Text("간략화한 규칙(절입 시각, 지장간 가중, 억부·조후)으로 계산한 오락·참고용 결과예요. 전문 명리 풀이와 다를 수 있어요.")
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
            }.padding(20).padding(.bottom, 40).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationTitle("내 사주").navigationBarTitleDisplayMode(.inline)
    }

    private func glyph(_ text: String, _ e: Element, size: CGFloat = 26) -> some View {
        Text(text).font(.system(size: size, weight: .bold, design: .serif)).foregroundStyle(e.beadInk)
            .frame(maxWidth: .infinity, minHeight: size + 22).background(e.bead, in: RoundedRectangle(cornerRadius: 12))
    }

    private func pillarsCard(_ chart: SajuChart) -> some View {
        let columns: [(String, Pillar?, Bool)] = [("시주", chart.hour, false), ("일주", chart.day, true), ("월주", chart.month, false), ("연주", chart.year, false)]
        return AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("사주 팔자").font(.headline)
                HStack(alignment: .top, spacing: 8) {
                    ForEach(columns, id: \.0) { title, p, isDay in
                        VStack(spacing: 6) {
                            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
                            if let p {
                                Text(isDay ? "나(일간)" : chart.tenGod(ofStem: p.stem).name).font(.footnote).foregroundStyle(AppTheme.ink)
                                glyph(Pillar.stemHanja[p.stem], p.stemElement)
                                glyph(Pillar.branchHanja[p.branch], p.branchElement)
                                Text(chart.tenGod(ofBranch: p.branch).name).font(.footnote).foregroundStyle(AppTheme.ink)
                                Text(HiddenStems.of(branch: p.branch).map { Pillar.stemHanja[$0.stem] }.joined(separator: " "))
                                    .font(.footnote).foregroundStyle(AppTheme.secondary)
                            } else {
                                Text("모름").font(.footnote).foregroundStyle(AppTheme.secondary).padding(.top, 40)
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }
                Text("위: 천간의 십성 · 아래: 지지(본기)의 십성과 지장간").font(.caption).foregroundStyle(AppTheme.secondary)
            }
        }
    }

    private func strengthCard(_ chart: SajuChart) -> some View {
        let yong = chart.yongshin
        return AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("강약과 용신").font(.headline)
                Text("\(chart.strengthLabel) · 일간(\(chart.dayMaster.nature))을 돕는 힘 \(Int((chart.supportRatio * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    chip("용신", yong); chip("희신", chart.heeshin); chip("기신", chart.gishin)
                }
                Text(chart.seasonalElement != nil
                     ? "태어난 계절의 한기·열기를 맞추는 \(yong.nature) 기운(조후)을 가장 필요한 기운으로 봤어요."
                     : "일간의 강약을 맞추는(억부) \(yong.nature) 기운을 가장 필요한 기운으로 봤어요.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
            }
        }
    }

    private func chip(_ title: String, _ e: Element) -> some View {
        Label("\(title) \(e.nature)", systemImage: e.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(e.beadInk)
            .padding(.horizontal, 12).padding(.vertical, 7).background(e.bead, in: Capsule())
    }

    private func elementsCard(_ chart: SajuChart) -> some View {
        let w = chart.weighted, top = max(w.values.max() ?? 1, 0.1)
        return AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("오행 세기").font(.headline)
                ForEach(Element.allCases, id: \.rawValue) { e in
                    HStack(spacing: 10) {
                        Label(e.nature, systemImage: e.symbol).font(.subheadline).frame(width: 76, alignment: .leading).foregroundStyle(AppTheme.ink)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.secondary.opacity(0.15))
                                Capsule().fill(e.color).frame(width: g.size.width * CGFloat((w[e] ?? 0) / top))
                            }
                        }.frame(height: 10)
                        Text(String(format: "%.1f", w[e] ?? 0)).font(.subheadline.monospacedDigit()).frame(width: 36, alignment: .trailing)
                    }
                }
                Text("지장간과 월령(태어난 달의 힘)을 반영한 값이에요.").font(.caption).foregroundStyle(AppTheme.secondary)
            }
        }
    }

    private func luckCard(_ chart: SajuChart) -> some View {
        let luck = SajuEngine.currentLuck()
        func line(_ title: String, _ p: Pillar) -> some View {
            let god = chart.tenGod(ofStem: p.stem)
            let e = p.stemElement
            let mood = e == chart.yongshin ? "내게 필요한 기운이 들어와요" : e == chart.heeshin ? "필요한 기운을 도와줘요" : e == chart.gishin ? "조금 조심하며 가요" : "무난하게 흘러가요"
            return HStack(spacing: 12) {
                Text(p.hanja).font(.system(size: 22, weight: .bold, design: .serif)).foregroundStyle(e.beadInk)
                    .frame(width: 70, height: 46).background(e.bead, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(title) \(p.label) · \(god.name)").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    Text("\(e.nature) 기운 · \(mood)").font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
            }
        }
        return AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("지금의 흐름").font(.headline)
                line("올해(세운)", luck.year)
                line("이번 달(월운)", luck.month)
            }
        }
    }

    private func daeunCard(_ chart: SajuChart) -> some View {
        let age: Double = chart.birth.map { Date().timeIntervalSince($0) / (365.2425 * 86400) } ?? 0
        return AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("대운 · \(chart.forward == true ? "순행" : "역행")").font(.headline)
                Text("\(String(format: "%.1f", chart.daeunStartAge ?? 0))세부터 10년마다 바뀌어요.").font(.subheadline).foregroundStyle(AppTheme.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(chart.daeun.enumerated()), id: \.offset) { _, d in
                            let current = age >= d.startAge && age < d.startAge + 10
                            VStack(spacing: 4) {
                                Text("\(Int(d.startAge.rounded(.down)))세").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
                                Text(d.pillar.hanja).font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(d.pillar.stemElement.beadInk)
                                    .frame(width: 64, height: 44).background(d.pillar.stemElement.bead, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(current ? AppTheme.ink : Color.clear, lineWidth: 2))
                                Text(chart.tenGod(ofStem: d.pillar.stem).name).font(.footnote).foregroundStyle(AppTheme.ink)
                            }
                        }
                    }.padding(.vertical, 2)
                }
            }
        }
    }

    private func notesCard(_ chart: SajuChart) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("계산 안내", systemImage: "info.circle").font(.headline)
                ForEach(chart.notes, id: \.self) { Text("· " + $0).font(.subheadline).foregroundStyle(AppTheme.secondary) }
            }
        }
    }
}

// MARK: - 번호 탭

struct WeeklyNumberView: View {
    @AppStorage(WeeklyReflection.birthDateKey) private var birthText = ""
    @AppStorage(SajuProfile.hourKey) private var hourRaw = BirthHour.unknown.rawValue
    @AppStorage("sajuWeeklyNumbers") private var stored = Data()
    @AppStorage("sajuDecisionHistory") private var historyData = Data()
    @State private var now = Date()
    @State private var picked: Date?
    @State private var confirm = false
    @State private var revealed: [Int] = []
    @State private var playing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(SajuProfile.extraKey) private var profileExtra = ""
    private var chart: SajuChart? { SajuProfile.chart(birthText: birthText, hourRaw: hourRaw, extra: profileExtra) }
    private var week: WeeklyWindow { WeeklyWindow(containing: now) }
    private var weekKey: String { ReflectionStore.journalDateKey(week.start) }
    private var records: [String: WeeklyNumberRecord] { (try? JSONDecoder().decode([String: WeeklyNumberRecord].self, from: stored)) ?? [:] }
    private var today: Date { WeeklyWindow.calendar.startOfDay(for: now) }
    private var history: [DecisionResult] { (try? JSONDecoder().decode([DecisionResult].self, from: historyData)) ?? [] }

    private func isSelectable(_ f: DayFortune) -> Bool { f.date >= today && f.date < week.deadline }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let chart {
                        let fortunes = DayPicker.week(chart: chart, week: week)
                        let record = records[weekKey]
                        let best = fortunes.filter(isSelectable).max { $0.pct < $1.pct }
                        let chosen = record?.day.flatMap { d in fortunes.first { $0.date == d } }
                            ?? fortunes.first { $0.date == picked && isSelectable($0) } ?? best
                        dayStrip(fortunes, best: best, chosen: chosen, locked: record != nil)
                        if let chosen { readingCard(chosen, isBest: chosen.date == best?.date) }
                        WeekChoiceList(history: history)
                        Text("덤으로 · 오락용 번호").font(.headline).foregroundStyle(AppTheme.ink).padding(.top, 4)
                        numberSection(chart, record: record, chosen: chosen)
                        luckyCard(chart)
                        NavigationLink { SajuDetailView().toolbar(.visible, for: .navigationBar) } label: {
                            HStack {
                                Label("내 사주 자세히 보기", systemImage: "scroll").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(chart.strengthLabel) · 용신 \(chart.yongshin.nature)").font(.footnote).foregroundStyle(AppTheme.secondary)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
                            }
                            .foregroundStyle(AppTheme.ink).padding(14).frame(maxWidth: .infinity).appGlass(RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).accessibilityIdentifier("saju-detail-link")
                    } else {
                        Text("생년월일을 넣으면 이번 주에서 내 사주에 가장 좋은 날을 찾아 번호를 만들어요.")
                            .font(.subheadline).foregroundStyle(AppTheme.secondary)
                        SajuProfileCard()
                        WeekChoiceList(history: history)
                    }
                    Text("오락용 번호예요. 당첨을 예측하거나 확률을 높이지 않아요.")
                        .font(.footnote).foregroundStyle(AppTheme.secondary)
                }.padding(20).padding(.bottom, 90).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in now = Date() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(WeeklyWindow.label(week.start)) 시작 주").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
            Text("이번 주의 픽").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                let remain = week.deadline.timeIntervalSince(ctx.date)
                let open = remain > 0
                HStack(spacing: 6) {
                    Image(systemName: open ? "clock" : "checkmark.circle")
                    Text(open ? countdown(remain) : "이번 주 마감")
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Element.fire.beadInk)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(open ? Element.fire.bead : Element.metal.bead, in: Capsule())
                .accessibilityIdentifier("week-countdown")
            }
        }
    }

    private func countdown(_ remain: TimeInterval) -> String {
        let days = Int(remain / 86400)
        let hours = Int(remain.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(remain.truncatingRemainder(dividingBy: 3600) / 60)
        return days > 0 ? "토 19:35 마감까지 \(days)일 \(hours)시간" : "토 19:35 마감까지 \(hours)시간 \(minutes)분"
    }

    private func dayStrip(_ fortunes: [DayFortune], best: DayFortune?, chosen: DayFortune?, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(locked ? "고른 날" : "내 사주에 좋은 날을 골라요").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
            HStack(spacing: 6) {
                ForEach(fortunes) { f in
                    let selectable = isSelectable(f) && !locked
                    let isChosen = f.date == chosen?.date
                    let e = f.pillar.stemElement
                    Button { picked = f.date; UISelectionFeedbackGenerator().selectionChanged() } label: {
                        VStack(spacing: 3) {
                            Text(weekday(f.date)).font(.caption.weight(.semibold))
                            Text(day(f.date)).font(.system(.subheadline, design: .rounded).weight(.bold))
                            Text("\(f.pct)").font(.caption.monospacedDigit())
                            Image(systemName: f.date == best?.date ? "star.fill" : e.symbol).font(.system(size: 9))
                        }
                        .foregroundStyle(isChosen ? e.beadInk : AppTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 78)
                        .background(isChosen ? e.bead : AppTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                        .opacity(isSelectable(f) || isChosen ? 1 : 0.6)
                    }.buttonStyle(.plain).disabled(!selectable)
                    .accessibilityLabel("\(f.label) 좋은 정도 \(f.pct)" + (f.date == best?.date ? " 추천" : ""))
                }
            }
        }
    }

    private func weekday(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.calendar = WeeklyWindow.calendar; f.timeZone = WeeklyWindow.calendar.timeZone; f.dateFormat = "E"
        return f.string(from: d)
    }
    private func day(_ d: Date) -> String { String(WeeklyWindow.calendar.component(.day, from: d)) }

    private func readingCard(_ f: DayFortune, isBest: Bool) -> some View {
        let e = f.pillar.stemElement
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: e.symbol).font(.title3).foregroundStyle(e.beadInk).frame(width: 40, height: 40).background(e.bead, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(f.label) \(f.pillar.label)일").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                    if isBest { Text("추천").font(.caption.weight(.bold)).foregroundStyle(Element.earth.beadInk)
                        .padding(.horizontal, 7).padding(.vertical, 2).background(Element.earth.bead, in: Capsule()) }
                    Spacer()
                    Text("\(f.pct)점").font(.subheadline.weight(.heavy)).monospacedDigit().foregroundStyle(e.color)
                }
                Text(f.summary).font(.subheadline).foregroundStyle(AppTheme.secondary)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(RoundedRectangle(cornerRadius: 20), tint: e.bead.opacity(0.35))
        .accessibilityIdentifier("day-reading")
    }

    private func luckyCard(_ chart: SajuChart) -> some View {
        let e = chart.lacking
        let n = WeeklyLucky.number(chart: chart, week: week)
        return HStack(spacing: 10) {
            Image(systemName: e.symbol).foregroundStyle(e.color)
            Text("행운 \(WeeklyLucky.colors[e.rawValue]) · \(WeeklyLucky.directions[e.rawValue]) · 숫자 \(n)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink).accessibilityIdentifier("lucky-line")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(RoundedRectangle(cornerRadius: 16), tint: e.pastel.opacity(0.5))
    }

    @ViewBuilder private func numberSection(_ chart: SajuChart, record: WeeklyNumberRecord?, chosen: DayFortune?) -> some View {
        let open = week.isOpen(at: now)
        if record != nil || (chosen != nil && open) {
            let sets = record?.sets ?? Array(repeating: Array(repeating: 0, count: 6), count: 5)
            let counts = playing ? revealed : (record == nil ? Array(repeating: 0, count: sets.count) : sets.map(\.count))
            NumberRows(sets: sets, counts: counts)
        }
        if let record {
            Text("\(WeeklyWindow.label(record.day ?? record.created)) 기준으로 만들었어요. 이번 주에는 다시 만들 수 없고, 다시 보기만 할 수 있어요.")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
            HStack(spacing: 10) {
                Button { play(record.sets) } label: { Label("다시 보기", systemImage: "play.circle") }
                    .buttonStyle(AppPrimaryButtonStyle()).disabled(playing).accessibilityIdentifier("replay-weekly-number")
                ShareLink(item: record.sets.enumerated().map { "\($0.offset + 1)  " + $0.element.map(String.init).joined(separator: ", ") }.joined(separator: "\n") + "\n\n오락용 번호입니다. 당첨 확률을 높이지 않습니다.") {
                    Image(systemName: "square.and.arrow.up").font(.body.weight(.semibold)).frame(width: 50, height: 50).appGlass(Circle())
                }.foregroundStyle(AppTheme.ink).accessibilityLabel("번호 공유")
            }
        } else if let chosen, open {
            Button("\(chosen.label)로 생성하기") { confirm = true }
                .buttonStyle(AppPrimaryButtonStyle()).disabled(playing).accessibilityIdentifier("make-weekly-number")
                .confirmationDialog("\(chosen.label) \(chosen.pillar.label)일 기운으로 생성할까요?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("생성하기") { create(chart, chosen) }
                    Button("다른 날 고르기", role: .cancel) {}
                } message: { Text("번호는 이번 주에 한 번만 만들 수 있어요.") }
        } else {
            Label("이번 주 번호 생성 시간이 지났어요. 일요일 00:00(한국 시간)부터 다시 만들 수 있어요.", systemImage: "clock")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).appGlass(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func create(_ chart: SajuChart, _ day: DayFortune) {
        var all = records
        guard all[weekKey] == nil else { return }
        let sets = SajuNumberGenerator.sets(chart: chart, day: day)
        all[weekKey] = WeeklyNumberRecord(sets: sets, created: Date(), day: day.date)
        if let data = try? JSONEncoder().encode(all) { stored = data }
        play(sets)
    }

    /// 세트별·번호별로 구슬이 하나씩 나타나는 애니메이션
    private func play(_ sets: [[Int]]) {
        guard !playing else { return }
        playing = true
        revealed = Array(repeating: 0, count: sets.count)
        Task { @MainActor in
            for i in sets.indices {
                for j in sets[i].indices {
                    try? await Task.sleep(nanoseconds: reduceMotion ? 30_000_000 : 150_000_000)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) { revealed[i] = j + 1 }
                    if !reduceMotion { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5) }
                }
                try? await Task.sleep(nanoseconds: reduceMotion ? 30_000_000 : 220_000_000)
            }
            if !reduceMotion { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            playing = false
        }
    }
}

// MARK: - 이번 주 행운 한 줄 · 오늘의 주의 · 프리셋

enum WeeklyLucky {
    static let colors = ["초록", "빨강", "노랑·베이지", "흰색", "검정·남색"]
    static let directions = ["동쪽", "남쪽", "중앙", "서쪽", "북쪽"]
    static let hints = ["샐러드·산책", "매운 음식·격한 운동", "빵·집콕", "튀김·자전거", "찬 음료·수영"]

    @MainActor static func number(chart: SajuChart, week: WeeklyWindow) -> Int {
        let pool = (1...45).filter { Element.of(number: $0) == chart.lacking }
        let key = chart.signature + "|" + ReflectionStore.journalDateKey(week.start) + "|lucky"
        return pool[Int(SajuNumberGenerator.hash(key) % UInt64(pool.count))]
    }
    static func caution(today: Pillar) -> String {
        let day = today.stemElement, pressed = day.controls
        return "오늘은 \(day.nature) 기운이 \(pressed.nature) 기운을 누르는 날이에요. 가볍게 즐기면 좋은 것 · \(hints[pressed.rawValue])"
    }
}

struct Preset: Identifiable {
    var id: String { title }
    let title: String, icon: String, items: [String]
}

enum Presets {
    static let solo: [Preset] = [
        Preset(title: "점심 메뉴", icon: "fork.knife", items: ["김치찌개", "제육볶음", "비빔밥", "돈까스", "짜장면", "짬뽕", "샐러드", "쌀국수", "햄버거", "초밥", "칼국수", "냉면"]),
        Preset(title: "저녁·야식", icon: "moon.stars", items: ["치킨", "족발", "떡볶이", "라면", "피자", "곱창", "보쌈", "파스타"]),
        Preset(title: "음료", icon: "cup.and.saucer", items: ["아메리카노", "라떼", "녹차", "아이스티", "스무디", "콜드브루"]),
        Preset(title: "술안주", icon: "wineglass", items: ["삼겹살", "골뱅이무침", "감자튀김", "회", "파전", "치즈"]),
        Preset(title: "배달 vs 외식", icon: "bag", items: ["배달", "외식", "집밥"]),
        Preset(title: "옷 색", icon: "tshirt", items: ["화이트", "블랙", "네이비", "베이지", "그린", "레드"]),
        Preset(title: "운동", icon: "figure.run", items: ["러닝", "헬스", "요가", "수영", "산책", "자전거", "클라이밍"]),
        Preset(title: "주말", icon: "sun.max", items: ["집콕", "나들이", "영화", "카페 투어", "등산", "친구 만나기", "전시회"]),
        Preset(title: "살까 말까", icon: "cart", items: ["산다", "참는다"]),
    ]
    static let group: [Preset] = [
        Preset(title: "모임 메뉴", icon: "fork.knife", items: ["고깃집", "초밥", "파스타", "치킨", "샤브샤브", "쌀국수", "곱창", "피자"]),
        Preset(title: "모임 장소", icon: "mappin.and.ellipse", items: ["공원 산책", "보드게임카페", "노래방", "영화관", "방탈출", "볼링장", "전시회"]),
        Preset(title: "카페·음료", icon: "cup.and.saucer", items: ["아메리카노", "라떼", "녹차", "스무디", "아이스티"]),
    ]
}

struct PresetBar: View {
    let presets: [Preset]
    let onPick: (Preset) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(presets.enumerated()), id: \.element.id) { i, p in
                    let e = Element(rawValue: i % 5)!
                    Button { onPick(p) } label: {
                        Label(p.title, systemImage: p.icon).font(.subheadline.weight(.semibold))
                            .foregroundStyle(e.beadInk).padding(.horizontal, 14).padding(.vertical, 9)
                            .background(e.bead, in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.vertical, 2)
        }
    }
}

@MainActor final class WheelDriver: ObservableObject {
    @Published var angle = 0.0
    @Published var spinning = false
    @Published var stageText: String?

    func spin(count: Int, winner: Int, stages: [String], reduceMotion: Bool) async {
        spinning = true
        let mid = (Double(winner) + 0.5) / Double(count) * 360
        let delta = (((-mid - angle).truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let target = angle + (reduceMotion ? 0 : 360 * 5) + delta
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { angle = target }
            try? await Task.sleep(nanoseconds: 400_000_000)
        } else {
            withAnimation(.timingCurve(0.12, 0.75, 0.15, 1, duration: 4.2)) { angle = target }
            let step = UInt64(4_200_000_000) / UInt64(max(stages.count, 1))
            for text in stages {
                withAnimation { stageText = text }
                try? await Task.sleep(nanoseconds: step)
            }
        }
        spinning = false
        withAnimation { stageText = nil }
    }
}

func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

// MARK: - 선택 탭 (룰렛)

struct WheelWedge: Shape {
    let from: Double   // 0...1, 위쪽에서 시계 방향
    let to: Double
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                    startAngle: .degrees(from * 360 - 90), endAngle: .degrees(to * 360 - 90), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct DecisionWheel: View {
    let labels: [String]
    let colors: [Color]
    let angle: Double
    let spinning: Bool
    let canSpin: Bool
    let onSpin: () -> Void
    private let ink = Color(red: 0.23, green: 0.16, blue: 0.13)

    var body: some View {
        let n = labels.count
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            ZStack {
                ZStack {
                    ForEach(0..<n, id: \.self) { i in
                        WheelWedge(from: Double(i) / Double(n), to: Double(i + 1) / Double(n))
                            .fill(colors[i])
                            .overlay(WheelWedge(from: Double(i) / Double(n), to: Double(i + 1) / Double(n)).stroke(.white.opacity(0.85), lineWidth: 3))
                    }
                    ForEach(0..<n, id: \.self) { i in
                        let mid = (Double(i) + 0.5) / Double(n) * 360
                        Text(labels[i]).font(.system(size: n == 2 ? 22 : (n == 3 ? 18 : 14), weight: .bold, design: .rounded))
                            .foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
                            .frame(width: radius * 0.8)
                            .offset(y: -radius * 0.58)
                            .rotationEffect(.degrees(mid))
                    }
                }
                .frame(width: size, height: size).clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 6))
                .rotationEffect(.degrees(angle))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                Button(action: onSpin) {
                    VStack(spacing: 2) {
                        Image(systemName: spinning ? "sparkles" : "play.fill").font(.title3)
                        Text(spinning ? "풀이 중" : "돌리기").font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(ink).frame(width: 84, height: 84)
                    .appGlass(Circle(), tint: .white.opacity(0.7))
                }.buttonStyle(.plain).disabled(!canSpin || spinning).opacity(canSpin ? 1 : 0.55)
                    .accessibilityIdentifier("decision-start")
                Image(systemName: "arrowtriangle.down.fill").font(.title2).foregroundStyle(AppTheme.accent)
                    .offset(y: -radius - 6).shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            }.frame(width: geo.size.width, height: geo.size.height)
        }.aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 오행 일치도 (결과 화면의 주인공)

struct MatchRing: View {
    let percent: Int
    let color: Color
    var size: CGFloat = 124
    @State private var shown = 0
    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: 16)
            Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(shown)").font(.system(size: size * 0.32, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text("%").font(.title3.weight(.bold))
                }
                Text("오행 일치도").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
            }.foregroundStyle(AppTheme.ink)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore).accessibilityLabel("오행 일치도 \(percent)퍼센트")
        .accessibilityIdentifier("match-ring")
        .task(id: percent) {
            shown = 0; progress = 0
            if reduceMotion { shown = percent; progress = Double(percent) / 100; return }
            withAnimation(.easeOut(duration: 1.0)) { progress = Double(percent) / 100 }
            for i in 1...max(percent, 1) {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / max(percent, 1)))
                shown = i
            }
        }
    }
}

/// 선택지를 하나씩 재서 오행 일치도를 보여주는 측정기. 혼자·함께 모드가 함께 쓴다.
struct MatchMeter<Footer: View>: View {
    @Binding var inputs: [String]
    @Binding var rows: Int
    let ready: Bool
    let tone: Element
    let idleHint: String
    let doneTitle: String
    let stages: [String]
    var extra: String? = nil
    let evaluate: ([String]) -> [DecisionEngine.Scored]
    let onDone: (DecisionEngine.Scored, [DecisionEngine.Scored]) -> Void
    @ViewBuilder let footer: Footer

    @State private var running = false
    @State private var stageText: String?
    @State private var current: DecisionEngine.Scored?
    @State private var winner: DecisionEngine.Scored?
    @State private var measured: [String: Int] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let darkInk = Color(red: 0.23, green: 0.16, blue: 0.13)

    private var texts: [String] { inputs.prefix(rows).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var canMeasure: Bool { ready && !texts.contains("") && Set(texts).count == texts.count }

    var body: some View {
        VStack(spacing: 12) {
            hero
            rowsCard
        }
        .onChange(of: inputs) { _, _ in reset() }
        .onChange(of: rows) { _, _ in reset() }
    }

    private func reset() {
        guard !running else { return }
        winner = nil; current = nil; measured = [:]
    }

    private var hero: some View {
        let shown = winner ?? current
        return VStack(spacing: 8) {
            if winner != nil {
                Text(doneTitle).font(.footnote.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6).background(AppTheme.accent, in: Capsule()).transition(.identity)
            } else {
                Text(stageText ?? (canMeasure ? "준비됐어요. 아래 버튼으로 일치도를 확인해요" : idleHint)).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.secondary)
                    .multilineTextAlignment(.center).contentTransition(.identity).transition(.identity)
            }
            if let shown {
                Text(shown.text).font(.system(size: winner == nil ? 22 : 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.ink).minimumScaleFactor(0.5).lineLimit(1)
                    .contentTransition(.identity).transition(.identity)
                    .accessibilityIdentifier(winner == nil ? "decision-current" : "decision-winner")
                MatchRing(percent: shown.match, color: shown.element.color).id(shown.text).transition(.identity)
            } else {
                ZStack {
                    Circle().fill(tone.bead.opacity(0.5))
                    Circle().stroke(tone.color.opacity(0.55), style: StrokeStyle(lineWidth: 12, dash: [2, 10]))
                    VStack(spacing: 6) {
                        Image(systemName: running ? "sparkles" : tone.symbol).font(.system(size: 30, weight: .bold))
                        Text("오늘의 \(tone.nature) 기운").font(.footnote.weight(.semibold))
                    }.foregroundStyle(tone.color)
                }.frame(width: 124, height: 124)
            }
            if let winner {
                HStack(spacing: 6) {
                    Image(systemName: winner.element.symbol).foregroundStyle(winner.element.color)
                    Text("\(winner.element.nature)(\(winner.element.hanja)) · \(winner.note)")
                        .font(.subheadline).foregroundStyle(AppTheme.secondary)
                }.multilineTextAlignment(.center)
                if let extra { Text(extra).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink) }
                Divider()
                footer
            }
        }
        .padding(.vertical, 16).padding(.horizontal, 20).frame(maxWidth: .infinity)
        .appGlass(RoundedRectangle(cornerRadius: 32), tint: (shown?.element ?? tone).bead.opacity(shown == nil ? 0.45 : 0.75))
    }

    private var rowsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("선택지별 오행 일치도").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                    Spacer()
                    if texts.contains(where: { !$0.isEmpty }) && !running {
                        Button("지우기") { inputs = ["", "", ""] }.font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                    }
                }
                ForEach(0..<rows, id: \.self) { i in
                    let text = texts[i]
                    let pct = text.isEmpty ? nil : measured[text]
                    let element = DecisionEngine.element(for: text)
                    let isWinner = winner != nil && winner?.text == text
                    HStack(spacing: 10) {
                        Circle().fill(text.isEmpty ? AppTheme.secondary.opacity(0.25) : element.color).frame(width: 14, height: 14)
                        TextField(["예: 아메리카노", "예: 라떼", "예: 녹차"][i], text: $inputs[i])
                            .submitLabel(.done).disabled(running)
                            .foregroundStyle(pct == nil ? AppTheme.ink : darkInk)
                            .accessibilityIdentifier("decision-option-\(i)")
                        if let pct {
                            Text("\(pct)%").font(.system(.headline, design: .rounded).weight(.heavy)).monospacedDigit()
                                .foregroundStyle(darkInk).accessibilityIdentifier("decision-match-\(i)")
                        }
                        if isWinner { Image(systemName: "checkmark.seal.fill").foregroundStyle(element.color) }
                        if rows == 3 && i == 2 && pct == nil && !running {
                            Button { rows = 2; inputs[2] = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.secondary) }
                                .accessibilityLabel("선택지 삭제")
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                (text.isEmpty ? AppTheme.surface.opacity(0.7) : element.bead.opacity(0.32))
                                if let pct { element.pastel.frame(width: g.size.width * CGFloat(pct) / 100) }
                            }
                        }
                    }
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(isWinner ? element.color : Color.clear, lineWidth: 2))
                }
                if rows == 2 && !running {
                    Button { rows = 3 } label: { Label("선택지 추가", systemImage: "plus") }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                }
                Button(winner == nil ? "오행 일치도 보기" : "다시 보기") { measure() }
                    .buttonStyle(ToneButtonStyle(element: tone)).disabled(!canMeasure || running)
                    .accessibilityIdentifier("decision-start")
            }
        }
    }

    private func measure() {
        guard canMeasure, !running else { return }
        hideKeyboard()
        let scored = evaluate(texts)
        guard let best = scored.max(by: { $0.score < $1.score }) else { return }
        running = true
        withAnimation { winner = nil; current = nil; measured = [:] }
        Task { @MainActor in
            if reduceMotion {
                for item in scored { measured[item.text] = item.match }
            } else {
                for text in stages {
                    stageText = text
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                for item in scored {
                    current = item; stageText = "\(item.text)의 기운을 재는 중…"
                    try? await Task.sleep(nanoseconds: 1_350_000_000)
                    withAnimation(.easeOut(duration: 0.4)) { measured[item.text] = item.match }
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { stageText = nil; current = nil; winner = best }
            if !reduceMotion { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            running = false
            onDone(best, scored)
        }
    }
}

// MARK: - 선택 허브 (혼자 · 함께 · 순서)

struct DecisionView: View {
    let openReflection: () -> Void
    @State private var mode = 0
    private var today: Pillar { SajuEngine.dayPillar(Date()) }
    private var headline: String { ["오늘은 무엇을 선택할까요?", "우리 모임은 무엇을 고를까요?", "오늘은 누구 차례일까요?"][mode] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Label("오늘의 \(today.stemElement.nature) 기운", systemImage: today.stemElement.symbol)
                                .font(.footnote.weight(.bold)).foregroundStyle(today.stemElement.beadInk)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(today.stemElement.bead, in: Capsule())
                            Text("\(WeeklyWindow.label(Date())) \(today.label)일").font(.footnote).foregroundStyle(AppTheme.secondary)
                        }
                        Text(headline).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Picker("방식", selection: $mode) {
                        Text("혼자").tag(0); Text("함께").tag(1); Text("순서").tag(2)
                    }.pickerStyle(.segmented).accessibilityIdentifier("decision-mode")
                    switch mode {
                    case 0: SoloChoiceView(openReflection: openReflection)
                    case 1: GroupChoiceView()
                    default: OrderChoiceView()
                    }
                }.padding(20).padding(.bottom, 90).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { hideKeyboard() } } }
        }
    }
}


// MARK: 혼자 정하기

struct SoloChoiceView: View {
    let openReflection: () -> Void
    @AppStorage(WeeklyReflection.birthDateKey) private var birthText = ""
    @AppStorage(SajuProfile.hourKey) private var hourRaw = BirthHour.unknown.rawValue
    @AppStorage("sajuDecisionHistory") private var historyData = Data()
    @State private var inputs = ["", "", ""]
    @State private var rows = 2
    @State private var lastID: UUID?

    @AppStorage(SajuProfile.extraKey) private var profileExtra = ""
    private var chart: SajuChart? { SajuProfile.chart(birthText: birthText, hourRaw: hourRaw, extra: profileExtra) }
    private var today: Pillar { SajuEngine.dayPillar(Date()) }
    private var history: [DecisionResult] { (try? JSONDecoder().decode([DecisionResult].self, from: historyData)) ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if chart == nil { SajuProfileCard() }
            PresetBar(presets: Presets.solo, onPick: pick)
            MatchMeter(inputs: $inputs, rows: $rows, ready: true, tone: today.stemElement,
                       idleHint: "선택지를 넣으면 오늘의 기운과 맞는 정도를 재요",
                       doneTitle: "오늘의 선택",
                       stages: ["오늘은 \(today.label)(\(today.hanja))일 · \(today.stemElement.nature) 기운",
                                chart.map { "내 사주에 가장 필요한 기운은 \($0.yongshin.nature)(\($0.yongshin.hanja))" } ?? "오늘의 기운만 살펴보는 중…"],
                       evaluate: { DecisionEngine(chart: chart, today: today).evaluate($0, dayKey: ReflectionStore.journalDateKey(Date())) },
                       onDone: save) { feedbackRow }
            cautionCard
            WeekSummaryCard(history: history, openReflection: openReflection)
            recent
        }
    }

    private var cautionCard: some View {
        Label(WeeklyLucky.caution(today: today), systemImage: "exclamationmark.circle")
            .font(.subheadline).foregroundStyle(AppTheme.secondary)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(RoundedRectangle(cornerRadius: 18))
    }

    private func pick(_ preset: Preset) {
        let items = preset.items.shuffled()
        for i in 0..<rows { inputs[i] = i < items.count ? items[i] : "" }
    }

    private func save(_ winner: DecisionEngine.Scored, _ all: [DecisionEngine.Scored]) {
        var list = history
        let entry = DecisionResult(date: Date(), options: all.map(\.text), winner: winner.text, reason: winner.note, kind: "solo", match: winner.match, matches: all.map(\.match))
        list.insert(entry, at: 0)
        lastID = entry.id
        if let data = try? JSONEncoder().encode(Array(list.prefix(60))) { historyData = data }
    }

    private var feedbackRow: some View {
        let entry = history.first { $0.id == lastID }
        return VStack(spacing: 8) {
            Text("선택 후 어땠나요?").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
            HStack(spacing: 8) {
                ForEach([(1, "좋았어요"), (0, "보통"), (-1, "별로")], id: \.0) { value, title in
                    Button { setFeedback(value) } label: {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .appGlass(Capsule(), tint: entry?.feedback == value ? AppTheme.accent.opacity(0.35) : nil)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func setFeedback(_ value: Int) {
        var all = history
        guard let i = all.firstIndex(where: { $0.id == lastID }) else { return }
        all[i].feedback = value
        if let data = try? JSONEncoder().encode(all) { historyData = data }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !history.isEmpty { Text("최근 선택").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(history.prefix(10)) { item in
                        let e = DecisionEngine.element(for: item.winner)
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().stroke(e.color.opacity(0.2), lineWidth: 5)
                                Circle().trim(from: 0, to: CGFloat(item.match ?? 0) / 100)
                                    .stroke(e.color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                                Text(item.match.map { "\($0)" } ?? String(item.winner.prefix(1)))
                                    .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(AppTheme.ink)
                            }.frame(width: 52, height: 52)
                            Text(item.winner).font(.caption).foregroundStyle(AppTheme.secondary).lineLimit(1).frame(width: 60)
                        }
                    }
                }.padding(.vertical, 3).padding(.horizontal, 3)
            }
        }
    }
}

// MARK: 이번 주 선택 목록 (한 행에 선택지들을 놓고 고른 쪽을 더 길고 진하게)

struct ChoiceRow: View {
    let item: DecisionResult
    private var weights: [Double] {
        if let m = item.matches, m.count == item.options.count { return m.map { Double(max($0, 1)) } }
        return item.options.map { $0 == item.winner ? Double(item.match ?? 70) : 40 }
    }
    var body: some View {
        let total = weights.reduce(0, +)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(WeeklyWindow.label(item.date)).font(.footnote).foregroundStyle(AppTheme.secondary)
                if item.kind == "group" { Text("함께").font(.caption.weight(.bold)).foregroundStyle(Element.water.beadInk)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Element.water.bead, in: Capsule()) }
                Spacer()
                if let m = item.match { Text("\(item.winner) \(m)%").font(.footnote.weight(.bold)).monospacedDigit().foregroundStyle(AppTheme.ink) }
            }
            GeometryReader { g in
                let gap: CGFloat = 4
                let usable = g.size.width - gap * CGFloat(max(item.options.count - 1, 0))
                HStack(spacing: gap) {
                    ForEach(Array(item.options.enumerated()), id: \.offset) { i, option in
                        let isWinner = option == item.winner
                        let e = DecisionEngine.element(for: option)
                        HStack(spacing: 4) {
                            if isWinner { Image(systemName: "checkmark.circle.fill").font(.footnote) }
                            Text(option).font(.subheadline.weight(isWinner ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(isWinner ? e.beadInk : AppTheme.secondary)
                        .frame(width: max(usable * CGFloat(weights[i] / total), 56), height: 38)
                        .background(isWinner ? e.bead : e.bead.opacity(0.32), in: Capsule())
                        .overlay(Capsule().strokeBorder(isWinner ? e.color.opacity(0.7) : Color.clear, lineWidth: 1.5))
                    }
                }
            }.frame(height: 38)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(WeeklyWindow.label(item.date)) " + item.options.joined(separator: ", ") + " 중 \(item.winner) 선택")
    }
}

struct WeekChoiceList: View {
    let history: [DecisionResult]
    private var items: [DecisionResult] {
        let start = WeeklyWindow(containing: Date()).start
        return history.filter { $0.date >= start }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이번 주 나의 선택").font(.headline).foregroundStyle(AppTheme.ink)
            if items.isEmpty {
                Text("선택 탭에서 고르면 여기에 한 줄씩 쌓여요.").font(.subheadline).foregroundStyle(AppTheme.secondary)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).appGlass(RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(items.prefix(8).enumerated()), id: \.element.id) { i, item in
                        ChoiceRow(item: item)
                        if i < min(items.count, 8) - 1 { Divider() }
                    }
                    if items.count > 8 { Text("외 \(items.count - 8)개").font(.footnote).foregroundStyle(AppTheme.secondary) }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).appGlass(RoundedRectangle(cornerRadius: 22))
            }
        }
    }
}

// MARK: 이번 주 나의 선택 (기운 빙고 + 회고 연결)

struct WeekSummaryCard: View {
    let history: [DecisionResult]
    let openReflection: () -> Void
    private var week: WeeklyWindow { WeeklyWindow(containing: Date()) }
    private var items: [DecisionResult] { history.filter { $0.date >= week.start && ($0.kind ?? "solo") == "solo" } }
    var body: some View {
        let elements = Set(items.map { DecisionEngine.element(for: $0.winner) })
        let good = items.filter { $0.feedback == 1 }.count
        let matches = items.compactMap(\.match)
        let average = matches.isEmpty ? nil : matches.reduce(0, +) / matches.count
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("이번 주 나의 선택").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                HStack(spacing: 10) {
                    ForEach(Element.allCases, id: \.rawValue) { e in
                        VStack(spacing: 4) {
                            Image(systemName: e.symbol).foregroundStyle(elements.contains(e) ? Color(red: 0.23, green: 0.16, blue: 0.13) : AppTheme.secondary)
                                .frame(width: 40, height: 40)
                                .background(elements.contains(e) ? e.pastel : Color.clear, in: Circle())
                                .overlay(Circle().strokeBorder(AppTheme.secondary.opacity(0.3), lineWidth: elements.contains(e) ? 0 : 1))
                            Text(e.nature).font(.caption).foregroundStyle(AppTheme.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
                Text(items.isEmpty ? "아직 이번 주 선택이 없어요. 오행 5개를 모두 채워 보세요."
                     : "\(items.count)번 선택했고 \(good)번은 좋았어요. 채운 기운 \(elements.count)/5" + (average.map { " · 평균 오행 일치도 \($0)%" } ?? ""))
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                Button { openReflection() } label: { Label("한 주 회고 쓰러 가기", systemImage: "book.pages") }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
            }
        }
    }
}

// MARK: 함께 정하기

struct GroupMember: Identifiable { let id = UUID(); var name = ""; var birth = "" }

struct GroupChoiceView: View {
    @AppStorage(WeeklyReflection.birthDateKey) private var myBirth = ""
    @AppStorage("sajuDecisionHistory") private var historyData = Data()
    @State private var members = [GroupMember(name: "나"), GroupMember(name: "친구")]
    @State private var inputs = ["", "", ""]
    @State private var rows = 2
    @State private var shareText = ""
    @State private var harmony: Int?

    private var today: Pillar { SajuEngine.dayPillar(Date()) }
    private var charts: [SajuChart] { members.compactMap { m in BirthDateInput.parse(m.birth).map { SajuEngine.chart(birth: $0, hourBranch: nil) } } }
    private var totals: [Element: Int] {
        var sum = Dictionary(uniqueKeysWithValues: Element.allCases.map { ($0, 0) })
        for c in charts { for (e, n) in c.counts { sum[e, default: 0] += n } }
        return sum
    }
    private var need: Element { Element.allCases.min { (totals[$0] ?? 0) < (totals[$1] ?? 0) }! }

    private func harmonyScore() -> Int {
        let cs = charts
        var pairs = 0, good = 0
        for i in 0..<cs.count { for j in (i + 1)..<cs.count {
            pairs += 1
            if (cs[j].counts[cs[i].lacking] ?? 0) >= 2 || (cs[i].counts[cs[j].lacking] ?? 0) >= 2 { good += 1 }
        } }
        return pairs == 0 ? 0 : 55 + Int(40.0 * Double(good) / Double(pairs))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            membersCard
            PresetBar(presets: Presets.group, onPick: pick)
            MatchMeter(inputs: $inputs, rows: $rows, ready: charts.count >= 2, tone: today.stemElement,
                       idleHint: charts.count >= 2 ? "모임의 기운과 얼마나 맞는지 재 드려요" : "두 명 이상의 생년월일을 넣어 주세요",
                       doneTitle: "우리 모임의 선택",
                       stages: ["오늘은 \(today.label)(\(today.hanja))일 · \(today.stemElement.nature) 기운",
                                "\(charts.count)명의 오행을 합쳐 보는 중…",
                                "모임에 필요한 기운은 \(need.nature)(\(need.hanja))"],
                       extra: harmony.map { "모임 오행 궁합 \($0)%" },
                       evaluate: { options in
                           DecisionEngine(need: need, signature: charts.map(\.signature).sorted().joined(), today: today)
                               .evaluate(options, dayKey: ReflectionStore.journalDateKey(Date()))
                       },
                       onDone: save) {
                ShareLink(item: shareText) { Label("결과 공유", systemImage: "square.and.arrow.up") }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .onAppear { if members[0].birth.isEmpty { members[0].birth = myBirth } }
        .onChange(of: charts.map(\.signature)) { _, _ in harmony = charts.count >= 2 ? harmonyScore() : nil }
    }

    private func save(_ winner: DecisionEngine.Scored, _ all: [DecisionEngine.Scored]) {
        harmony = harmonyScore()
        shareText = "오늘 우리 모임의 선택: \(winner.text) (오행 일치도 \(winner.match)%)\n오락용 결과예요."
        var list = (try? JSONDecoder().decode([DecisionResult].self, from: historyData)) ?? []
        list.insert(DecisionResult(date: Date(), options: all.map(\.text), winner: winner.text, reason: winner.note, kind: "group", match: winner.match, matches: all.map(\.match)), at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(60))) { historyData = data }
    }

    private var membersCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("함께하는 사람").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                    Spacer()
                    if members.count < 4 {
                        Button("추가") { members.append(GroupMember()) }.font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                    }
                }
                ForEach($members) { $m in
                    HStack(spacing: 10) {
                        TextField("이름", text: $m.name).frame(width: 60)
                        TextField("생년월일 8자리", text: $m.birth).keyboardType(.numberPad)
                            .onChange(of: m.birth) { _, v in
                                m.birth = String(v.filter(\.isNumber).prefix(8))
                                if m.birth.count == 8 { hideKeyboard() }
                            }
                        if members.count > 2 {
                            Button("삭제") { members.removeAll { $0.id == m.id } }
                                .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9).background(AppTheme.surface.opacity(0.7), in: Capsule())
                }
                if charts.count >= 2 {
                    Text("모임에 필요한 기운: \(need.nature)(\(need.hanja))").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                }
                Text("생년월일은 저장하지 않고 이 화면에서만 써요.").font(.footnote).foregroundStyle(AppTheme.secondary)
            }
        }
    }

    private func pick(_ preset: Preset) {
        let items = preset.items.shuffled()
        for i in 0..<rows { inputs[i] = i < items.count ? items[i] : "" }
    }
}

// MARK: 순서 정하기 (누가 쏠지)

struct OrderChoiceView: View {
    @StateObject private var driver = WheelDriver()
    @State private var names = ["", ""]
    @State private var order: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clean: [String] { names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var canSpin: Bool { !clean.contains("") && Set(clean).count == clean.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DecisionWheel(labels: clean.map { $0.isEmpty ? "?" : $0 },
                          colors: clean.indices.map { Pastel.setTints[$0 % 5] },
                          angle: driver.angle, spinning: driver.spinning, canSpin: canSpin, onSpin: spin)
                .padding(.horizontal, 44).padding(.top, 8)
            if let stage = driver.stageText {
                Text(stage).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.secondary).frame(maxWidth: .infinity)
            }
            if !order.isEmpty && !driver.spinning {
                VStack(spacing: 8) {
                    Text("첫 번째는 \(order[0])!").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(AppTheme.ink)
                        .accessibilityIdentifier("order-winner")
                    Text(order.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "   "))
                        .font(.subheadline).foregroundStyle(AppTheme.secondary).multilineTextAlignment(.center)
                    Text("재미를 위한 무작위 순서예요.").font(.caption).foregroundStyle(AppTheme.secondary)
                }
                .padding(.vertical, 20).padding(.horizontal, 16).frame(maxWidth: .infinity)
                .appGlass(RoundedRectangle(cornerRadius: 28), tint: Pastel.setTints[0].opacity(0.6))
            }
            AppCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("참가자 (2~6명)").font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                    ForEach(names.indices, id: \.self) { i in
                        HStack {
                            Circle().fill(Pastel.setTints[i % 5]).frame(width: 14, height: 14)
                            TextField("이름 \(i + 1)", text: $names[i]).submitLabel(.done)
                            if names.count > 2 {
                                Button { names.remove(at: i) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.secondary) }
                                    .accessibilityLabel("삭제")
                            }
                        }.padding(.horizontal, 14).padding(.vertical, 11).background(AppTheme.surface.opacity(0.7), in: Capsule())
                    }
                    if names.count < 6 {
                        Button { names.append("") } label: { Label("참가자 추가", systemImage: "plus") }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                    }
                }.disabled(driver.spinning)
            }
        }
    }

    private func spin() {
        guard canSpin, !driver.spinning else { return }
        hideKeyboard()
        let shuffled = clean.shuffled()
        let index = clean.firstIndex(of: shuffled[0]) ?? 0
        order = []
        Task { @MainActor in
            await driver.spin(count: clean.count, winner: index, stages: ["돌아가는 중…", "곧 정해져요…"], reduceMotion: reduceMotion)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { order = shuffled }
            if !reduceMotion { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }
}

// MARK: - 톤 버튼 · 알림 · 온보딩

struct ToneButtonStyle: ButtonStyle {
    let element: Element
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline)
            .foregroundStyle(element == .earth || element == .metal ? element.beadInk : .white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(enabled ? element.color : element.color.opacity(0.35), in: Capsule())
            .contentShape(Capsule()).opacity(configuration.isPressed ? 0.85 : 1)
    }
}

enum WeeklyReminder {
    private static let ids = ["weekpick.start", "weekpick.deadline"]
    /// 켜면 권한을 요청하고 주간 알림 2개를 예약한다. 권한이 없으면 false.
    static func set(_ on: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard on else { return true }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        func add(_ id: String, weekday: Int, hour: Int, minute: Int, title: String, body: String) async {
            var c = DateComponents(); c.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
            c.weekday = weekday; c.hour = hour; c.minute = minute
            let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
        }
        await add(ids[0], weekday: 1, hour: 9, minute: 0, title: "이번 주의 픽", body: "새 주가 시작됐어요. 이번 주의 좋은 날을 확인해 보세요.")
        await add(ids[1], weekday: 7, hour: 16, minute: 35, title: "마감 3시간 전", body: "오늘 19:35에 이번 주 오락용 번호 생성이 마감돼요.")
        return true
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image("BrandIcon").resizable().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 19))
                VStack(alignment: .leading, spacing: 6) {
                    Text("주간픽").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                    Text("이번 주의 선택을 내 사주로 골라요").font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
                VStack(alignment: .leading, spacing: 14) {
                    feature(.fire, "wand.and.stars", "오늘의 선택", "선택지를 넣으면 오늘의 기운과 얼마나 맞는지(오행 일치도)를 재서 하나를 골라요.")
                    feature(.water, "person.3", "함께 정하기", "모임 사람들의 오행을 합쳐 메뉴와 장소를 정해요.")
                    feature(.wood, "calendar", "이번 주의 픽", "한 주의 좋은 날을 보고, 덤으로 오락용 번호도 한 번 만들어 볼 수 있어요.")
                }
                SajuProfileCard()
                Text("오락용 앱이에요. 당첨을 예측하거나 확률을 높이지 않아요. 생년월일을 입력했다면 위의 저장 버튼을 먼저 눌러 주세요.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                Button("시작하기", action: onFinish).buttonStyle(AppPrimaryButtonStyle()).accessibilityIdentifier("onboarding-start")
                Button("나중에 입력할게요", action: onFinish).font(.subheadline).foregroundStyle(AppTheme.secondary).frame(maxWidth: .infinity)
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.paper.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func feature(_ e: Element, _ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(e.beadInk).frame(width: 44, height: 44).background(e.bead, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(AppTheme.ink)
                Text(text).font(.subheadline).foregroundStyle(AppTheme.secondary)
            }
        }
    }
}
