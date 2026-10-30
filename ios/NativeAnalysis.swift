import SwiftUI
import JavaScriptCore

struct NativeChart: Decodable {
    struct Pillar: Decodable {
        struct HiddenStem: Decodable { let stem: String; let tenGod: String }
        let position: String; let value: String; let reading: String; let tenGod: String
        let hiddenStems: [HiddenStem]
    }
    struct Day: Decodable { let day: String; let date: String; let score: Int; let tenGod: String; let relation: String }
    struct Basis: Decodable {
        let source: String; let retrievedAt: String; let timePolicy: String; let precision: String
        let longitudeCorrectionMinutes: Double; let previousTerm: String?; let nextTerm: String?; let warnings: [String]
    }
    let pillars: [Pillar]; let distribution: [String: Int]; let days: [Day]
    let bestDay: String; let basis: Basis; let limits: String
    var aiDetails: String {
        let pillarsText = pillars.map { p in
            "\(p.position) \(p.value) · \(p.tenGod) · 지장간: " + p.hiddenStems.map { "\($0.stem)(\($0.tenGod))" }.joined(separator: ", ")
        }.joined(separator: "\n")
        // Only explicitly approved derived values enter the AI request.
        return pillarsText + "\n오행: \(distribution)\n계산 출처: \(basis.source)\n시간 기준: \(basis.timePolicy)\n정밀도: \(basis.precision)\n경고: \(basis.warnings.joined(separator: "; "))\n\(limits)\n참고 요일: \(bestDay)\n주간 자체 비교: " + days.map { "\($0.day) \($0.score) · \($0.tenGod) · \($0.relation)" }.joined(separator: "; ")
    }
}

@MainActor enum NativeCalendarEngine {
    static func calculate(birth: Date, time: Date?, longitude: Double, now: Date = Date()) throws -> NativeChart {
        let calendar = ReflectionStore.calendar
        let b = calendar.dateComponents([.year, .month, .day], from: birth)
        let w = calendar.dateComponents([.year, .month, .day], from: now)
        guard let context = JSContext() else { throw EngineError.unavailable }
        context.evaluateScript("var window = globalThis;")
        for name in ["solar-terms", "saju-calendar", "native-engine"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "Web/vendor") else { throw EngineError.unavailable }
            context.evaluateScript(try String(contentsOf: url, encoding: .utf8))
            guard context.exception == nil else { throw EngineError.unavailable }
        }
        var exact = ""
        if let time {
            let c = calendar.dateComponents([.hour, .minute], from: time)
            exact = String(format: "%02d:%02d", c.hour!, c.minute!)
        }
        let input: [String: Any] = ["year": b.year!, "month": b.month!, "day": b.day!, "timeVal": "unknown", "exactTime": exact, "longitude": longitude,
                                    "weekYear": w.year!, "weekMonth": w.month!, "weekDay": w.day!]
        guard let function = context.objectForKeyedSubscript("nativeChart"),
              let json = function.call(withArguments: [input])?.toString(), context.exception == nil,
              let data = json.data(using: .utf8) else { throw EngineError.unavailable }
        return try JSONDecoder().decode(NativeChart.self, from: data)
    }
    enum EngineError: LocalizedError {
        case unavailable
        var errorDescription: String? { "계산 자료를 읽지 못했습니다. 지원 범위(1900~2027년)의 날짜인지 확인해주세요." }
    }
}

struct NativeAnalysisView: View {
    @ObservedObject var model: AnalysisViewModel
    @ObservedObject var store: ReportStore
    @State private var birth = ReflectionStore.calendar.date(from: DateComponents(year: 1995, month: 5, day: 12))!
    @State private var knowsTime = false
    @State private var time = ReflectionStore.calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!
    @State private var longitude = 126.978
    @State private var name = ""
    private let cities: [(String, Double)] = [("서울",126.978),("부산",129.076),("대구",128.601),("인천",126.705),("광주",126.853),("대전",127.385),("울산",129.311),("제주",126.531),("표준 경도 · 보정 없음",135)]
    private var dateRange: ClosedRange<Date> {
        let calendar = ReflectionStore.calendar
        return calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))!...min(Date(), calendar.date(from: DateComponents(year: 2027, month: 12, day: 31))!)
    }
    var body: some View {
        Form {
            if let chart = model.chart {
                Section {
                    Text("전통 명리학을 일상의 회고 소재로 읽어보세요. 미래나 복권 당첨을 예측하는 기능은 아닙니다.")
                        .foregroundStyle(AppTheme.secondary)
                } header: { Text("나의 사주 원국") }
                Section("네 기둥") {
                    ForEach(Array(chart.pillars.enumerated()), id: \.offset) { _, p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(p.position).foregroundStyle(AppTheme.secondary); Spacer(); Text(p.value).font(.title2.bold()); Text(p.reading) }
                            Text("\(p.tenGod) · 지장간: " + (p.hiddenStems.isEmpty ? "미상" : p.hiddenStems.map { "\($0.stem)(\($0.tenGod))" }.joined(separator: ", "))).font(.footnote)
                        }.padding(.vertical, 4)
                    }
                }
                Section("오행 · 표면 개수") {
                    ForEach(["wood", "fire", "earth", "metal", "water"], id: \.self) { key in
                        LabeledContent(["wood":"목(木)","fire":"화(火)","earth":"토(土)","metal":"금(金)","water":"수(水)"][key]!, value: "\(chart.distribution[key, default: 0])개")
                    }
                    Text(chart.limits).font(.footnote).foregroundStyle(AppTheme.secondary)
                }
                Section("이번 주 · 자기성찰을 위한 비교") {
                    Text("참고 요일: \(chart.bestDay)").font(.headline)
                    ForEach(Array(chart.days.enumerated()), id: \.offset) { _, day in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(day.day, value: "자체 지표 \(day.score)")
                            Text("\(day.date) · \(day.tenGod) · \(day.relation)").font(.caption).foregroundStyle(AppTheme.secondary)
                        }
                    }
                    Text("점수는 전통 용어를 활용한 앱의 비교 규칙입니다. 행운·당첨 확률이나 재정적 성과를 뜻하지 않습니다.").font(.footnote).foregroundStyle(AppTheme.secondary)
                }
                Section("참고용 무작위 번호 5세트") {
                    ForEach(Array(model.numberSets.enumerated()), id: \.offset) { index, numbers in
                        VStack(alignment: .leading) {
                            Text("조합 \(String(UnicodeScalar(65 + index)!))").font(.caption).foregroundStyle(AppTheme.secondary)
                            Text(numbers.map(String.init).joined(separator: " · ")).font(.headline.monospacedDigit())
                        }.padding(.vertical, 3)
                    }
                    Text("사주와 관계없이 기기에서 무작위로 생성합니다. 모든 6개 조합의 확률은 동일하며 당첨 확률을 높이지 않습니다.").font(.footnote).foregroundStyle(AppTheme.secondary)
                    Button("번호 저장", systemImage: "bookmark") { model.saveNative(to: store) }.accessibilityIdentifier("native-save")
                    ShareLink(item: model.numberText + "\n오락용 무작위 조합이며 당첨 확률을 높이지 않습니다.") { Label("번호 공유", systemImage: "square.and.arrow.up") }
                }
                Section("계산 근거와 한계") {
                    Text(chart.basis.source)
                    Text("자료 확인: \(chart.basis.retrievedAt)")
                    Text(chart.basis.timePolicy)
                    Text(chart.basis.precision)
                    Text("경도 보정: \(chart.basis.longitudeCorrectionMinutes, specifier: "%.2f")분")
                    if let previous = chart.basis.previousTerm { Text("이전 절입: " + previous) }
                    if let next = chart.basis.nextTerm { Text("다음 절입: " + next) }
                    ForEach(chart.basis.warnings, id: \.self) { Text($0).foregroundStyle(AppTheme.secondary) }
                    Text("천문 날짜의 정확성이 사주 예측의 과학적 타당성을 보장하지 않습니다. 한국천문연구원은 앱의 해석을 제공하거나 보증하지 않습니다.").foregroundStyle(AppTheme.secondary)
                }.font(.footnote)
            } else {
                Section {
                    Text("양력 생년월일로 전통 명리학의 원국과 계산 근거를 살펴봅니다. 기본 분석은 인터넷 없이 기기에서 처리합니다.").foregroundStyle(AppTheme.secondary)
                }
                Section("출생 정보") {
                    TextField("이름 · 선택", text: $name).textContentType(.nickname).accessibilityIdentifier("native-name")
                    DatePicker("생년월일 · 양력", selection: $birth, in: dateRange, displayedComponents: .date).accessibilityIdentifier("native-birth")
                    Toggle("정확한 출생 시각을 알아요", isOn: $knowsTime)
                    if knowsTime { DatePicker("출생 시각 · 한국 표준시", selection: $time, displayedComponents: .hourAndMinute) }
                    Picker("출생 지역 · 경도 보정", selection: $longitude) {
                        ForEach(cities, id: \.1) { city in Text(city.0).tag(city.1) }
                    }
                    Text("한국 출생·UTC+09:00 기준입니다. 시각 미상은 시주를 산출하지 않으며, 과거 표준시·서머타임은 별도 대조가 필요합니다.").font(.footnote).foregroundStyle(AppTheme.secondary)
                }
                Section {
                    Button("분석 및 번호 생성") {
                        model.calculate(birth: birth, time: knowsTime ? time : nil, longitude: longitude, name: name, city: cities.first { $0.1 == longitude }!.0)
                    }.accessibilityIdentifier("native-generate")
                } footer: { Text("오락과 자기성찰용입니다. 당첨·재정적 이익을 예측하지 않습니다. 이름은 입력하지 않아도 이용할 수 있습니다.") }
            }
        }
        .scrollContentBackground(.hidden).background(AppTheme.paper)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 9 * 3600)!)
        .navigationTitle("사주 돌아보기").navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("천기누설 개인정보 처리방침").font(.title2.bold())
                Text("시행일: 2026년 10월 31일 · 운영자: outinletter")
                Text("기본 분석").font(.headline).padding(.top, 8)
                Text("선택적으로 입력한 이름, 생년월일, 출생 시간과 지역은 기기에서 사주·오행 계산에 사용합니다. 기본 분석은 인터넷 없이 이용할 수 있으며 해당 입력 정보를 외부 서버에 전송하지 않습니다. 번호 저장을 선택한 경우 입력 정보와 번호를 함께 기기에 보관하며, 그 외 입력은 새 분석 또는 앱 종료 시 사라집니다.")
                Text("선택적 AI 해석").font(.headline).padding(.top, 8)
                Text("iOS 앱의 AI 해석은 새 요청 전에 별도 동의를 받으며 같은 분석의 완료된 응답은 앱 실행 중 재사용합니다. 동의하면 계산된 사주팔자·오행·주간 비교·번호 조합·십성·지장간·절기 이름·계산 방식·불확실성 경고를 Cloudflare Worker 서버를 거쳐 외부 AI 제공업체에 보내 해석을 생성합니다. 이름, 원본 생년월일, 정확한 출생 시각과 지역·경도값은 보내지 않습니다. 파생 사주 값은 출생 정보와 관련될 수 있으므로 익명 데이터라고 단정하지 않습니다. 동의를 취소해도 기본 분석과 번호 생성은 사용할 수 있습니다.")
                Text("네트워크 요청을 처리하는 Cloudflare 서버는 연결 IP를 확인할 수 있습니다. 앱은 AI 요청이나 응답을 영구 저장하지 않습니다. 외부 제공업체의 처리 및 보관에는 해당 서비스의 적용 정책이 따르며, 앱이 제공업체의 삭제 완료나 보관 기간을 보장하지 않습니다.")
                Text("AI 제공업체는 Hangzhou DeepSeek Artificial Intelligence Co., Ltd.입니다. 자세한 정보는 AI 제공업체 개인정보 처리방침과 Cloudflare 개인정보 처리방침을 확인하세요. 제공업체 정책은 앱 운영자의 본 방침을 대체하지 않습니다.")
                Text("한 줄 회고·주간 도감").font(.headline).padding(.top, 8)
                Text("회고 본문, 마음 색, 이전 버전에서 저장한 손그림과 무작위 번호는 기기에만 저장하며 AI 등 외부 서버에 보내지 않습니다. 기기 백업에 포함될 수 있습니다. 카드 상세에서 수정·삭제할 수 있습니다. 이미지 공유는 본문 숨김이 기본값이고 손그림은 포함되므로 개인정보가 없는지 공유 전 확인해주세요. 사용자가 공유를 실행하면 선택한 앱으로 카드 이미지가 전달됩니다. 감정과 기록 내용은 번호의 당첨 확률에 영향을 주지 않습니다.")
                Text("번호 저장·공유·삭제").font(.headline).padding(.top, 8)
                Text("직접 저장한 입력 정보, 참고 요일과 번호를 기기에 보관합니다. 저장 기록은 운영체제의 기기 백업에 포함될 수 있습니다. 기록 탭에서 삭제할 수 있으며, 번호 저장을 선택하면 이름과 생년월일도 저장 기록에 포함됩니다. 공유를 선택하면 번호가 선택한 앱으로 전달되며 이후 처리는 해당 앱의 정책을 따릅니다.")
                Text("광고 및 추적").font(.headline).padding(.top, 8)
                Text("앱에는 광고나 추적 SDK가 없습니다. 사주 및 번호 해석은 오락용이며 당첨이나 재정적 이익을 예측하거나 보장하지 않습니다.")
                Text("문의").font(.headline).padding(.top, 8)
                Text("앱 지원 및 개인정보 관련 요청은 개발자 문의로 연락해 주세요. 공개 게시물에 생년월일이나 다른 민감한 개인정보를 올리지 마세요.")
                Link("AI 제공업체 개인정보 처리방침", destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
                Link("Cloudflare 개인정보 처리방침", destination: URL(string: "https://www.cloudflare.com/privacypolicy/")!)
                Link("개발자 문의", destination: URL(string: "https://github.com/outinletter/sajulotto/issues")!)
            }.padding().frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
        }.background(AppTheme.paper).navigationTitle("개인정보 처리방침").navigationBarTitleDisplayMode(.inline).textSelection(.enabled)
    }
}

struct AIConsentView: View {
    @ObservedObject var model: AnalysisViewModel
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("선택적 AI 해설", systemImage: "sparkles").font(.headline)
                    Text("동의하지 않아도 모든 기본 분석과 회고 기능을 이용할 수 있습니다.")
                }
                Section("전송 항목") {
                    Text("계산된 사주팔자·오행·십성·지장간·주간 비교·번호 조합·계산 방식·불확실성 경고를 해설 생성에 사용합니다.")
                    Text("이름·생년월일 원문·정확한 출생 시각·지역·경도값·회고는 전송하지 않습니다. 파생 사주 값은 출생 정보와 관련될 수 있습니다.").foregroundStyle(AppTheme.secondary)
                }
                Section("전송 대상과 보관") {
                    Text("sajulotto.outinletter.workers.dev (Cloudflare)를 거쳐 api.deepseek.com (DeepSeek)에 전송합니다. 서버는 연결 IP를 확인할 수 있습니다.")
                    Text("앱은 AI 요청과 응답을 영구 저장하지 않습니다. 외부 제공업체의 처리·보관에는 각 서비스 정책이 적용됩니다.")
                    NavigationLink("앱 개인정보 처리방침") { PrivacyPolicyView() }
                    Link("DeepSeek 개인정보 처리방침", destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
                    Link("Cloudflare 개인정보 처리방침", destination: URL(string: "https://www.cloudflare.com/privacypolicy/")!)
                }
                Section {
                    Button("동의하고 AI 해석 요청") { model.approveAI() }
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                        .accessibilityIdentifier("ai-consent-approve")
                } footer: { Text("AI 해설에는 오류가 있을 수 있습니다. 당첨이나 재정적 이익을 예측하지 않습니다.") }
            }
            .scrollContentBackground(.hidden).background(AppTheme.paper)
            .navigationTitle("AI 정보 전송 동의").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("취소", role: .cancel) { model.showAIConsent = false }.accessibilityIdentifier("ai-consent-cancel")
            } }
        }.tint(AppTheme.accent)
    }
}
