import Foundation

// 사주 계산 핵심 (Foundation만 사용). 오락·참고용이며 전문 명리 해석과 다를 수 있다.
// 규칙: 연주는 입춘, 월주는 12절(節) 절입 시각 기준(KASI 특일 정보 + 천문 계산 표),
//       일주는 출생지 지방시 자정 기준, 시주는 지방시 기준 2시간 구간(야자시: 23시대는 당일 일주·다음 날 일간으로 시간 계산).

enum Element: Int, CaseIterable {
    case wood, fire, earth, metal, water
    var name: String { ["목", "화", "토", "금", "수"][rawValue] }
    /// 요일과 헷갈리지 않도록 화면에는 자연물 이름을 함께 쓴다
    var nature: String { ["나무", "불", "흙", "쇠", "물"][rawValue] }
    var hanja: String { ["木", "火", "土", "金", "水"][rawValue] }
    var symbol: String { ["leaf.fill", "flame.fill", "mountain.2.fill", "sparkles", "drop.fill"][rawValue] }
    /// 이 오행이 낳는 오행 (목→화→토→금→수→목)
    var generates: Element { Element(rawValue: (rawValue + 1) % 5)! }
    /// 이 오행이 극하는 오행 (목→토→수→화→금→목)
    var controls: Element { Element(rawValue: (rawValue + 2) % 5)! }
    /// 이 오행을 낳는 오행
    var generatedBy: Element { Element(rawValue: (rawValue + 4) % 5)! }
    /// 이 오행을 극하는 오행
    var controlledBy: Element { Element(rawValue: (rawValue + 3) % 5)! }
    /// 로또 번호의 오행: 끝자리 기준 (1·6 수, 2·7 화, 3·8 목, 4·9 금, 5·0 토)
    static func numberHint(_ e: Element) -> String { ["3·8", "2·7", "5·0", "4·9", "1·6"][e.rawValue] }
    static func of(number: Int) -> Element { [Element.earth, .water, .fire, .wood, .metal][number % 5] }
}

enum Gender: String { case male = "m", female = "f"
    var label: String { self == .male ? "남성" : "여성" }
}

struct BirthPlace: Equatable {
    let name: String
    let longitude: Double?   // 동경(도). nil이면 지방시 보정을 하지 않는다.
    static let all: [BirthPlace] = [
        BirthPlace(name: "서울", longitude: 126.98), BirthPlace(name: "인천", longitude: 126.70), BirthPlace(name: "수원", longitude: 127.03),
        BirthPlace(name: "춘천", longitude: 127.73), BirthPlace(name: "강릉", longitude: 128.88), BirthPlace(name: "대전", longitude: 127.38),
        BirthPlace(name: "세종", longitude: 127.29), BirthPlace(name: "청주", longitude: 127.49), BirthPlace(name: "전주", longitude: 127.15),
        BirthPlace(name: "광주", longitude: 126.85), BirthPlace(name: "대구", longitude: 128.60), BirthPlace(name: "포항", longitude: 129.37),
        BirthPlace(name: "울산", longitude: 129.31), BirthPlace(name: "부산", longitude: 129.08), BirthPlace(name: "창원", longitude: 128.68),
        BirthPlace(name: "제주", longitude: 126.53), BirthPlace(name: "해외·모름 (보정 안 함)", longitude: nil),
    ]
    static let defaultPlace = all[0]
    static func named(_ name: String) -> BirthPlace { all.first { $0.name == name } ?? defaultPlace }
}

struct Pillar: Equatable {
    let stem: Int
    let branch: Int
    static let stems = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"]
    static let stemHanja = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    static let branches = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"]
    static let branchHanja = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    var label: String { Pillar.stems[stem] + Pillar.branches[branch] }
    var hanja: String { Pillar.stemHanja[stem] + Pillar.branchHanja[branch] }
    var stemElement: Element { Element(rawValue: stem / 2)! }
    var branchElement: Element { Pillar.branchElements[branch] }
    static let branchElements: [Element] = [.water, .earth, .wood, .wood, .earth, .fire, .fire, .earth, .metal, .metal, .earth, .water]
    /// 60갑자 순번 (갑자 = 0). 천간·지지 조합이 맞지 않으면 nil.
    var cycleIndex: Int? { (0..<60).first { $0 % 10 == stem && $0 % 12 == branch } }
    static func fromCycle(_ n: Int) -> Pillar { let m = ((n % 60) + 60) % 60; return Pillar(stem: m % 10, branch: m % 12) }
    /// 천간이 양(甲丙戊庚壬)인가
    var isYang: Bool { stem % 2 == 0 }
}

/// 십성(十星): 일간을 기준으로 다른 글자와의 관계
enum TenGod: Int, CaseIterable {
    case bigyeon, geopjae, siksin, sanggwan, pyeonjae, jeongjae, pyeongwan, jeonggwan, pyeonin, jeongin
    var name: String { ["비견", "겁재", "식신", "상관", "편재", "정재", "편관", "정관", "편인", "정인"][rawValue] }
    /// 비겁(0) 식상(1) 재성(2) 관성(3) 인성(4)
    var group: Int { rawValue / 2 }
    var groupName: String { ["비겁", "식상", "재성", "관성", "인성"][group] }

    static func of(stem: Int, dayStem: Int) -> TenGod {
        let me = Pillar(stem: dayStem, branch: 0), other = Pillar(stem: stem, branch: 0)
        let same = me.isYang == other.isYang
        let a = me.stemElement, b = other.stemElement
        if a == b { return same ? .bigyeon : .geopjae }
        if a.generates == b { return same ? .siksin : .sanggwan }
        if a.controls == b { return same ? .pyeonjae : .jeongjae }
        if b.controls == a { return same ? .pyeongwan : .jeonggwan }
        return same ? .pyeonin : .jeongin   // b.generates == a
    }
}

/// 지장간: 지지 속에 숨은 천간 (여기 → 중기 → 본기 순, 일수)
enum HiddenStems {
    static let table: [[(stem: Int, days: Int)]] = [
        [(8, 10), (9, 20)],                 // 子: 壬 癸
        [(9, 9), (7, 3), (5, 18)],          // 丑: 癸 辛 己
        [(4, 7), (2, 7), (0, 16)],          // 寅: 戊 丙 甲
        [(0, 10), (1, 20)],                 // 卯: 甲 乙
        [(1, 9), (9, 3), (4, 18)],          // 辰: 乙 癸 戊
        [(4, 7), (6, 7), (2, 16)],          // 巳: 戊 庚 丙
        [(2, 10), (5, 9), (3, 11)],         // 午: 丙 己 丁
        [(3, 9), (1, 3), (5, 18)],          // 未: 丁 乙 己
        [(4, 7), (8, 7), (6, 16)],          // 申: 戊 壬 庚
        [(6, 10), (7, 20)],                 // 酉: 庚 辛
        [(7, 9), (3, 3), (4, 18)],          // 戌: 辛 丁 戊
        [(4, 7), (0, 7), (8, 16)],          // 亥: 戊 甲 壬
    ]
    static func of(branch: Int) -> [(stem: Int, days: Int)] { table[branch] }
    static func main(branch: Int) -> Int { table[branch].last!.stem }
}

struct DaeunPillar {
    let pillar: Pillar
    let startAge: Double   // 세는 나이가 아닌 만 나이(년)
}

struct SajuChart {
    let year: Pillar, month: Pillar, day: Pillar, hour: Pillar?
    var gender: Gender? = nil
    var birth: Date? = nil
    var daeun: [DaeunPillar] = []
    var forward: Bool? = nil
    var daeunStartAge: Double? = nil
    var notes: [String] = []

    var pillars: [Pillar] { [year, month, day] + (hour.map { [$0] } ?? []) }
    var dayMaster: Element { day.stemElement }

    /// 눈에 보이는 글자(천간·지지) 오행 개수
    var counts: [Element: Int] {
        var result = Dictionary(uniqueKeysWithValues: Element.allCases.map { ($0, 0) })
        for pillar in pillars { result[pillar.stemElement, default: 0] += 1; result[pillar.branchElement, default: 0] += 1 }
        return result
    }

    /// 지장간과 월령(월지 가중)을 반영한 오행 세기
    var weighted: [Element: Double] {
        var result = Dictionary(uniqueKeysWithValues: Element.allCases.map { ($0, 0.0) })
        func addStem(_ s: Int, _ w: Double) { result[Pillar(stem: s, branch: 0).stemElement, default: 0] += w }
        addStem(year.stem, 1); addStem(month.stem, 1); addStem(day.stem, 1)
        if let hour { addStem(hour.stem, 1) }
        let branches: [(Int, Double)] = [(year.branch, 0.8), (month.branch, 1.6), (day.branch, 1.2)] + (hour.map { [($0.branch, 1.0)] } ?? [])
        for (b, w) in branches {
            let items = HiddenStems.of(branch: b), total = Double(items.reduce(0) { $0 + $1.days })
            for item in items { addStem(item.stem, w * Double(item.days) / total) }
        }
        return result
    }

    /// 일간을 돕는 힘(비겁·인성)의 비율
    var supportRatio: Double {
        let w = weighted, me = dayMaster
        let support = (w[me] ?? 0) + (w[me.generatedBy] ?? 0)
        let total = w.values.reduce(0, +)
        return total == 0 ? 0.5 : support / total
    }
    var strengthLabel: String { supportRatio >= 0.55 ? "신강" : (supportRatio <= 0.45 ? "신약" : "중화") }

    /// 억부(일간 강약) 기준 필요한 오행
    var balanceElement: Element {
        let w = weighted, me = dayMaster
        let candidates: [Element] = supportRatio >= 0.5 ? [me.generates, me.controls, me.controlledBy] : [me.generatedBy, me]
        return candidates.min { (w[$0] ?? 0) < (w[$1] ?? 0) }!
    }

    /// 조후(계절 균형): 한여름엔 물, 한겨울엔 불이 부족하면 우선
    var seasonalElement: Element? {
        let w = weighted, avg = w.values.reduce(0, +) / 5
        switch month.branch {
        case 5, 6, 7: return (w[.water] ?? 0) < avg * 0.8 ? .water : nil
        case 11, 0, 1: return (w[.fire] ?? 0) < avg * 0.8 ? .fire : nil
        default: return nil
        }
    }

    /// 용신(가장 필요한 기운)
    var yongshin: Element { seasonalElement ?? balanceElement }
    /// 희신(용신을 돕는 기운)
    var heeshin: Element { yongshin.generatedBy }
    /// 기신(용신을 누르는 기운)
    var gishin: Element { yongshin.controlledBy }
    /// 기존 화면과의 호환: 내게 필요한 기운
    var lacking: Element { yongshin }

    func tenGod(ofStem stem: Int) -> TenGod { TenGod.of(stem: stem, dayStem: day.stem) }
    func tenGod(ofBranch branch: Int) -> TenGod { tenGod(ofStem: HiddenStems.main(branch: branch)) }

    var signature: String { pillars.map(\.label).joined() }
}

enum SajuEngine {
    private static let epochDayOf20000101 = 10957   // 1970-01-01부터 2000-01-01까지 일수
    private static var kst: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!; return c
    }

    // MARK: 일주

    static func dayPillar(epochDay: Int) -> Pillar {
        let n = epochDay - epochDayOf20000101
        return Pillar(stem: ((4 + n) % 10 + 10) % 10, branch: ((6 + n) % 12 + 12) % 12)
    }

    static func dayPillar(_ date: Date) -> Pillar {
        let c = kst.dateComponents([.year, .month, .day], from: date)
        return dayPillar(epochDay: epochDay(year: c.year!, month: c.month!, day: c.day!))
    }

    /// 그레고리력 날짜의 1970-01-01 기준 일수
    static func epochDay(year: Int, month: Int, day: Int) -> Int {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m - 3) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    // MARK: 시간대·서머타임 (Asia/Seoul tzdata 규칙)

    /// 서머타임 구간 [시작, 끝) — 시계 시각(분 단위, 해당 연도 1월 1일 0시부터)
    private static let dst: [Int: ((Int, Int, Int, Int), (Int, Int, Int, Int))] = [
        1948: ((6, 1, 0, 0), (9, 13, 0, 0)), 1949: ((4, 3, 0, 0), (9, 11, 0, 0)), 1950: ((4, 1, 0, 0), (9, 10, 0, 0)),
        1951: ((5, 6, 0, 0), (9, 9, 0, 0)), 1955: ((5, 5, 0, 0), (9, 9, 0, 0)), 1956: ((5, 20, 0, 0), (9, 29, 0, 0)),
        1957: ((5, 5, 0, 0), (9, 22, 0, 0)), 1958: ((5, 4, 0, 0), (9, 21, 0, 0)), 1959: ((5, 3, 0, 0), (9, 20, 0, 0)),
        1960: ((5, 1, 0, 0), (9, 18, 0, 0)), 1987: ((5, 10, 2, 0), (10, 11, 3, 0)), 1988: ((5, 8, 2, 0), (10, 9, 3, 0)),
    ]

    private static func key(_ m: Int, _ d: Int, _ h: Int, _ mi: Int) -> Int { ((m * 32 + d) * 24 + h) * 60 + mi }

    /// 시계 시각에서 UTC까지의 보정(분)과 안내 문구
    static func civilOffset(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> (minutes: Int, notes: [String]) {
        var notes: [String] = []
        let ymd = year * 10000 + month * 100 + day
        var offset = 9 * 60
        if (19080401...19111231).contains(ymd) || (19540321...19610809).contains(ymd) {
            offset = 8 * 60 + 30
            notes.append("당시 한국 표준시(동경 127.5도, UTC+8:30)를 반영했어요.")
        } else if ymd < 19080401 {
            notes.append("1908년 이전에는 표준시가 없어 지방시일 수 있어요. 시각 보정 없이 계산했어요.")
        }
        if let (s, e) = dst[year], key(month, day, hour, minute) >= key(s.0, s.1, s.2, s.3), key(month, day, hour, minute) < key(e.0, e.1, e.2, e.3) {
            offset += 60
            notes.append("당시 서머타임을 반영했어요.")
        }
        return (offset, notes)
    }

    // MARK: 절기

    /// 12절(소한·입춘·…·대설) 절입 시각들 (UTC 분), 오름차순
    private static func jeolMinutes(around year: Int) -> [(minute: Int, index: Int, year: Int)] {
        var result: [(Int, Int, Int)] = []
        for y in (year - 1)...(year + 1) {
            guard let list = SolarTermsData.jeol[y] else { continue }
            for (i, m) in list.enumerated() { result.append((m, i, y)) }
        }
        return result.sorted { $0.0 < $1.0 }
    }

    private static let branchOfJeol = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0]   // 소한→丑 … 대설→子

    private struct Period {
        let yearPillar: Pillar, monthPillar: Pillar
        let sajuYear: Int
        let previous: Int?, next: Int?   // 직전·다음 절입(UTC 분)
        let approximate: Bool
    }

    private static func period(instantMinutes: Int, civilYear: Int, civilMonth: Int, civilDay: Int) -> Period {
        let terms = jeolMinutes(around: civilYear)
        if SolarTermsData.jeol[civilYear] != nil, let idx = terms.lastIndex(where: { $0.minute <= instantMinutes }) {
            let t = terms[idx]
            // 사주상 연도: 직전 입춘이 속한 연도
            let lichun = terms[...idx].last { $0.index == 1 }
            let sajuYear = lichun?.year ?? (civilYear - 1)
            let yearPillar = Pillar(stem: ((sajuYear - 4) % 10 + 10) % 10, branch: ((sajuYear - 4) % 12 + 12) % 12)
            let branch = branchOfJeol[t.index]
            let fromYin = (branch - 2 + 12) % 12
            let monthPillar = Pillar(stem: ((yearPillar.stem % 5) * 2 + 2 + fromYin) % 10, branch: branch)
            return Period(yearPillar: yearPillar, monthPillar: monthPillar, sajuYear: sajuYear,
                          previous: t.minute, next: idx + 1 < terms.count ? terms[idx + 1].minute : nil, approximate: false)
        }
        // 표 범위 밖: 고정 날짜 근사
        let starts: [(Int, Int)] = [(2, 4), (3, 6), (4, 5), (5, 6), (6, 6), (7, 7), (8, 8), (9, 8), (10, 8), (11, 7), (12, 7), (1, 6)]
        let beforeLichun = civilMonth == 1 || (civilMonth == 2 && civilDay < 4)
        var index = 11
        if civilMonth == 1 { index = civilDay >= 6 ? 11 : 10 }
        else if !beforeLichun { for (i, s) in starts.enumerated().prefix(11) where (civilMonth, civilDay) >= (s.0, s.1) { index = i } }
        let sajuYear = beforeLichun ? civilYear - 1 : civilYear
        let yearPillar = Pillar(stem: ((sajuYear - 4) % 10 + 10) % 10, branch: ((sajuYear - 4) % 12 + 12) % 12)
        let monthPillar = Pillar(stem: ((yearPillar.stem % 5) * 2 + 2 + index) % 10, branch: (2 + index) % 12)
        return Period(yearPillar: yearPillar, monthPillar: monthPillar, sajuYear: sajuYear, previous: nil, next: nil, approximate: true)
    }

    // MARK: 사주 세우기

    struct Time { var hour: Int; var minute: Int; var exact: Bool }

    /// - time: 출생 시각. exact가 false면 hour는 시진(2시간) 대표 시각이며 지방시 보정을 하지 않는다. nil이면 시주 없음.
    /// - historical: 과거 표준시·서머타임 반영 여부 (검증용으로 끌 수 있다)
    static func chart(birth: Date, time: Time?, gender: Gender? = nil, place: BirthPlace? = nil,
                      historical: Bool = true, now: Date = Date()) -> SajuChart {
        let c = kst.dateComponents([.year, .month, .day], from: birth)
        let year = c.year!, month = c.month!, dayOfMonth = c.day!
        var notes: [String] = []
        let hour = time?.hour ?? 12, minute = time?.minute ?? 0

        // 1) 시계 시각 → 절대 시각(UTC 분)
        let clockDay = epochDay(year: year, month: month, day: dayOfMonth)
        let clockMinutes = clockDay * 1440 + hour * 60 + minute
        var offset = 9 * 60
        if historical {
            let civil = civilOffset(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute)
            offset = civil.minutes
            if time?.exact == true { notes.append(contentsOf: civil.notes) }
            else if civil.minutes != 9 * 60 { notes.append("과거 표준시·서머타임 구간 출생이에요. 정확한 시·분을 입력하면 더 정확해져요.") }
        }
        let instant = clockMinutes - offset

        // 2) 연주·월주 (절입 시각은 절대 시각으로 비교)
        let p = period(instantMinutes: instant, civilYear: year, civilMonth: month, civilDay: dayOfMonth)
        if p.approximate { notes.append("1899~2027년 밖 출생이라 절기 경계를 근사했어요.") }
        if let prev = p.previous, let next = p.next, time != nil {
            let near = min(abs(instant - prev), abs(next - instant))
            if near <= (time?.exact == true ? 30 : 120) { notes.append("절입 시각에 가까워 연주·월주가 달라질 수 있어요.") }
        } else if time == nil, let prev = p.previous, let next = p.next, min(abs(instant - prev), abs(next - instant)) <= 12 * 60 {
            notes.append("태어난 시간을 모르면 절입일 전후에는 연주·월주가 달라질 수 있어요.")
        }

        // 3) 일주·시주: 지방시(경도 보정) 기준. 시진만 알면 보정하지 않고 고른 시진을 그대로 쓴다.
        var localMinutes = clockMinutes   // 시계 시각 그대로(보정 없음)
        if time?.exact == true, let lon = place?.longitude {
            localMinutes = instant + Int((lon * 4).rounded())
            let shift = localMinutes - clockMinutes
            if shift != 0 { notes.append("출생지 경도에 맞춰 시각을 \(shift > 0 ? "+" : "")\(shift)분 보정했어요.") }
        } else if time?.exact == true { notes.append("출생지를 모르면 시각 보정 없이 계산해요.") }

        let localDay = Int((Double(localMinutes) / 1440).rounded(.down))
        let minuteOfDay = localMinutes - localDay * 1440
        var hourPillar: Pillar? = nil
        let dayPillar0 = dayPillar(epochDay: localDay)
        if time != nil {
            let branch = time?.exact == true ? ((minuteOfDay + 60) / 120) % 12 : ((hour * 60 + 60) / 120) % 12
            // 야자시: 23시대는 당일 일주를 유지하고 시간(時干)은 다음 날 일간으로 계산
            let lateZi = time?.exact == true && minuteOfDay >= 23 * 60
            let baseStem = lateZi ? dayPillar(epochDay: localDay + 1).stem : dayPillar0.stem
            hourPillar = Pillar(stem: ((baseStem % 5) * 2 + branch) % 10, branch: branch)
            if lateZi { notes.append("23시대 출생은 야자시 기준(당일 일주)으로 계산했어요.") }
        }

        var chart = SajuChart(year: p.yearPillar, month: p.monthPillar, day: dayPillar0, hour: hourPillar, gender: gender, birth: birth, notes: notes)

        // 4) 대운: 양남음녀 순행, 절입까지 일수 ÷ 3 = 시작 나이
        if let gender {
            let forward = p.yearPillar.isYang == (gender == .male)
            chart.forward = forward
            if let target = forward ? p.next : p.previous, let base = p.monthPillar.cycleIndex {
                let days = Double(abs(target - instant)) / 1440
                let start = days / 3
                chart.daeunStartAge = start
                chart.daeun = (0..<8).map { i in
                    DaeunPillar(pillar: Pillar.fromCycle(base + (forward ? i + 1 : -(i + 1))), startAge: start + Double(i) * 10)
                }
            }
        } else {
            chart.notes.append("성별을 입력하면 대운을 볼 수 있어요.")
        }
        return chart
    }

    /// 생년월일과 시진(0~11)만 아는 간단 입력 (모임 기능 등). 시진은 보정 없이 그대로 쓴다.
    static func chart(birth: Date, hourBranch: Int?) -> SajuChart {
        chart(birth: birth, time: hourBranch.map { Time(hour: ($0 * 2) % 24, minute: 0, exact: false) })
    }

    // MARK: 세운·월운

    /// 지금(또는 주어진 시각)의 세운(해의 간지)과 월운(달의 간지)
    static func currentLuck(now: Date = Date()) -> (year: Pillar, month: Pillar) {
        let c = kst.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let instant = epochDay(year: c.year!, month: c.month!, day: c.day!) * 1440 + c.hour! * 60 + c.minute! - 9 * 60
        let p = period(instantMinutes: instant, civilYear: c.year!, civilMonth: c.month!, civilDay: c.day!)
        return (p.yearPillar, p.monthPillar)
    }
}
