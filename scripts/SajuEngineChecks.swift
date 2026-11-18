import Foundation

// 사주 엔진 검증. 기존 JS 엔진(vendor/saju-calendar.js)이 만든 기준 데이터와 직접 계산한 값을 대조한다.
// 실행: swiftc -parse-as-library ios/SajuCore.swift ios/SolarTermsData.swift scripts/SajuEngineChecks.swift -o /tmp/SajuEngineChecks
//       /tmp/SajuEngineChecks [fixture.txt]   (fixture: "y m d H M lon -> yStem yBranch mStem mBranch dStem dBranch hStem hBranch")
@main struct SajuEngineChecks {
    static var failures = 0
    static func check(_ ok: Bool, _ message: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: \(message())") } }
    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    static func label(_ p: Pillar?) -> String { p?.hanja ?? "--" }

    static func main() {
        check(SajuEngine.epochDay(year: 1970, month: 1, day: 1) == 0, "epoch 1970")
        check(SajuEngine.epochDay(year: 2000, month: 1, day: 1) == 10957, "epoch 2000")
        check(SajuEngine.dayPillar(date(2024, 1, 1)).hanja == "甲子", "2024-01-01 갑자일")
        check(SajuEngine.dayPillar(date(2000, 1, 1)).hanja == "戊午", "2000-01-01 무오일")

        // 알려진 값
        var c = SajuEngine.chart(birth: date(2000, 1, 1), time: .init(hour: 12, minute: 0, exact: true), historical: false)
        check(label(c.year) == "己卯" && label(c.month) == "丙子" && label(c.day) == "戊午" && label(c.hour) == "戊午", "2000-01-01 12:00 → \(c.pillars.map(\.hanja))")
        c = SajuEngine.chart(birth: date(2024, 2, 4), time: .init(hour: 16, minute: 0, exact: true), historical: false)
        check(label(c.year) == "癸卯" && label(c.month) == "乙丑" && label(c.day) == "戊戌", "입춘 전 2024-02-04 16:00")
        c = SajuEngine.chart(birth: date(2024, 2, 4), time: .init(hour: 18, minute: 0, exact: true), historical: false)
        check(label(c.year) == "甲辰" && label(c.month) == "丙寅" && label(c.day) == "戊戌", "입춘 후 2024-02-04 18:00")
        // 2026 입춘 = 05:02 KST
        c = SajuEngine.chart(birth: date(2026, 2, 4), time: .init(hour: 5, minute: 1, exact: true), historical: false)
        check(label(c.year) == "乙巳" && c.month.branch == 1, "2026-02-04 05:01 입춘 직전")
        c = SajuEngine.chart(birth: date(2026, 2, 4), time: .init(hour: 5, minute: 2, exact: true), historical: false)
        check(label(c.year) == "丙午" && c.month.branch == 2, "2026-02-04 05:02 입춘")

        // 서머타임·표준시
        c = SajuEngine.chart(birth: date(1987, 6, 1), time: .init(hour: 12, minute: 0, exact: true))
        check(c.notes.contains { $0.contains("서머타임") }, "1987 서머타임 안내")
        c = SajuEngine.chart(birth: date(1958, 3, 1), time: .init(hour: 12, minute: 0, exact: true))
        check(c.notes.contains { $0.contains("8:30") }, "1958 UTC+8:30 안내")

        // 십성
        let expected = ["甲": "비견", "乙": "겁재", "丙": "식신", "丁": "상관", "戊": "편재", "己": "정재", "庚": "편관", "辛": "정관", "壬": "편인", "癸": "정인"]
        for (i, h) in Pillar.stemHanja.enumerated() { check(TenGod.of(stem: i, dayStem: 0).name == expected[h], "십성 갑 vs \(h)") }
        check(TenGod.of(stem: 1, dayStem: 1) == .bigyeon && TenGod.of(stem: 7, dayStem: 3) == .pyeonjae, "십성 정 vs 신 = 편재")

        // 대운: 己卯년(음) 남성 → 역행, 여성 → 순행
        c = SajuEngine.chart(birth: date(2000, 1, 1), time: .init(hour: 12, minute: 0, exact: true), gender: .male, historical: false)
        check(c.forward == false && (c.daeunStartAge ?? -1) >= 0 && (c.daeunStartAge ?? 99) <= 10 && c.daeun.count == 8, "남성 역행 대운")
        check(c.daeun.first?.pillar.hanja == "乙亥", "역행 첫 대운 병자 이전 = 을해: \(c.daeun.first?.pillar.hanja ?? "")")
        c = SajuEngine.chart(birth: date(2000, 1, 1), time: .init(hour: 12, minute: 0, exact: true), gender: .female, historical: false)
        check(c.forward == true && c.daeun.first?.pillar.hanja == "丁丑", "여성 순행 첫 대운 정축")

        // 강약·용신 불변식
        for y in stride(from: 1950, to: 2025, by: 7) {
            let ch = SajuEngine.chart(birth: date(y, 6, 15), time: .init(hour: 10, minute: 30, exact: true), place: BirthPlace.defaultPlace)
            let total = ch.weighted.values.reduce(0, +)
            check(abs(total - 8.0 - 0.0) < 8.0 && total > 6.5, "가중치 합 \(total)")
            check(ch.supportRatio >= 0 && ch.supportRatio <= 1, "비율")
            check(ch.yongshin != ch.gishin, "용신≠기신")
        }

        // 기준 데이터(기존 JS 엔진) 대조
        if CommandLine.arguments.count > 1, let text = try? String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8) {
            var n = 0, bad = 0
            for line in text.split(separator: "\n") {
                let parts = line.components(separatedBy: " -> ")
                guard parts.count == 2 else { continue }
                let i = parts[0].split(separator: " ").compactMap { Double($0) }, o = parts[1].split(separator: " ").compactMap { Int($0) }
                guard i.count == 6, o.count == 8 else { continue }
                let known = i[3] >= 0
                let time: SajuEngine.Time? = known ? .init(hour: Int(i[3]), minute: Int(i[4]), exact: true) : nil
                let place = BirthPlace(name: "t", longitude: i[5])
                let ch = SajuEngine.chart(birth: date(Int(i[0]), Int(i[1]), Int(i[2])), time: time, place: place, historical: false)
                let got = [ch.year.stem, ch.year.branch, ch.month.stem, ch.month.branch, ch.day.stem, ch.day.branch]
                n += 1
                var ok = Array(o[0..<6]) == got
                if known, o[6] >= 0 {
                    // 야자시(보정 후 23시대)는 의도적으로 다음 날 일간으로 시간(時干)을 계산하므로 시지만 비교한다.
                    let lateZi = ch.notes.contains { $0.contains("야자시") }
                    ok = ok && ch.hour?.branch == o[7] && (lateZi || ch.hour?.stem == o[6])
                }
                if !ok { bad += 1; if bad <= 8 { print("MISMATCH \(line) got \(got) hour \(label(ch.hour))") } }
            }
            check(bad == 0, "기준 데이터 불일치 \(bad)/\(n)")
            print("기준 데이터 \(n)건 대조, 불일치 \(bad)건")
        }
        print(failures == 0 ? "PASS" : "FAILURES: \(failures)")
        exit(failures == 0 ? 0 : 1)
    }
}
