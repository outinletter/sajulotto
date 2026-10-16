import SwiftUI
import WebKit

struct SavedReport: Codable, Identifiable {
    var id = UUID()
    let created: Date
    let text: String
    var inputInfo: String? = nil
}

final class ReportStore: ObservableObject {
    @Published var reports: [SavedReport] = []
    init() {
        if let data = UserDefaults.standard.data(forKey: "savedReports"),
           let saved = try? JSONDecoder().decode([SavedReport].self, from: data) { reports = saved }
    }
    func save(_ text: String, inputInfo: String? = nil) {
        reports.insert(SavedReport(created: Date(), text: text, inputInfo: inputInfo), at: 0)
        persist()
    }
    func delete(_ offsets: IndexSet) { reports.remove(atOffsets: offsets); persist() }
    func persist() {
        if let data = try? JSONEncoder().encode(reports) { UserDefaults.standard.set(data, forKey: "savedReports") }
    }
}

@MainActor final class AnalysisViewModel: ObservableObject {
    let webView: WKWebView
    @Published var message = ""
    @Published var showMessage = false
    @Published var showAIConsent = false
    @Published var showAIResult = false
    @Published var aiText = ""
    @Published var aiLoading = false
    private var aiTask: Task<Void, Never>?
    private var cachedDetails: String?
    private var cachedText = ""
    private var requestID = UUID()
    private func analysisDetails() async throws -> String? {
        let value = try await webView.evaluateJavaScript(#"""
                (() => {
                    if (document.getElementById('dashboard').classList.contains('hidden')) return null;
                    const pillars = ['year','month','day','hour'].map(p => document.getElementById('saju-'+p+'-hanja').innerText.replace(/\n/g, ''));
                    const elements = ['wood','fire','earth','metal','water'].map(p => document.getElementById('dist-'+p).innerText);
                    const calculation = window.sajuCalculation;
                    const basis = calculation?.basis;
                    const aiCalculation = calculation && {pillars:calculation.pillars, interpretationLimits:calculation.interpretationLimits,
                        basis:{source:basis.source,timePolicy:basis.timePolicy,precision:basis.precision,warnings:basis.warnings,
                            previousTerm:basis.previousTerm?.split(' ')[0],nextTerm:basis.nextTerm?.split(' ')[0]}};
                    return '사주팔자(년월일시): '+pillars.join(', ')+'; 오행(목화토금수): '+elements.join(', ')+'; 참고 요일: '+document.getElementById('bestDayInfo').innerText+'; 주간 비교 및 참고 번호: '+JSON.stringify(window.sajuWeeklyContext)+'; 원국과 계산 근거: '+JSON.stringify(aiCalculation);
                })()
                """#)
        return value as? String
    }
    func openAI() {
        Task {
            do {
                let details = try await analysisDetails()
                if let details, details == cachedDetails, !cachedText.isEmpty {
                    aiText = cachedText; showAIResult = true
                } else if aiLoading {
                    showAIResult = true
                } else {
                    showAIConsent = true
                }
            } catch {
                message = "분석 화면을 확인하고 다시 시도해주세요."; showMessage = true
            }
        }
    }
    func requestAI() {
        guard !aiLoading else { return }
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DeepSeekProxyURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else {
            message = "AI 서버 주소가 설정되지 않았습니다."; showMessage = true; return
        }
        let id = UUID(); requestID = id
        aiText = ""; aiLoading = true; showAIResult = true
        aiTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.requestID == id { self.aiLoading = false } }
            do {
                let details = try await self.analysisDetails()
                try Task.checkCancellation()
                guard let details else {
                    self.aiText = "먼저 사주 분석을 완료해주세요."; return
                }
                let prompt = """
                당신은 한국 전통 명리학을 근거와 한계까지 설명하는 해설자입니다. 전달된 원국·십성·지장간·계산 근거만 사용해 한국어 Markdown으로 2,000~2,600자의 원국 해설을 작성하세요. 천문 날짜의 정확성이 사주 예측의 과학적 타당성을 보장하지 않음을 구분하세요. 한국천문연구원이 사주 해석을 제공하거나 보증한다고 쓰지 마세요.
                연주는 입춘, 월주는 12절입 기준이며 음력 월건을 대신 적용하지 마세요. 계산 근거의 출처·입력 정밀도·시간 보정·경계 경고를 먼저 설명하세요. 시각 미상이면 시주를 해석하지 말고 연주·월주의 경계 불확실성을 유지하세요. 오행 표면 개수와 월령·지장간은 구분하세요. 미산출 격국·용신·신강신약·대운 시작 나이·대운·세운은 추정하거나 확정하지 마세요. 합충형파해는 입력에 있는 관계만 설명하며, 입력에 없는 운명·사건·수명·질병·혼인·재정적 이익을 예측하지 마세요.
                # 사주 원국 해설
                ## 계산 출처와 해석 범위
                ## 일간과 월령의 계절적 배경
                ## 천간 십성과 지장간
                ## 오행 분포와 균형을 읽는 방법
                ## 일·관계·휴식의 자기성찰 제안
                ## 이번 주 참고 흐름과 번호
                주간 점수는 앱의 오락용 자체 비교 지표이며 확률이나 공인 지수가 아닙니다. 선택된 요일을 임의 변경하지 말고, 입력에 없는 시간대를 만들어 추천하지 마세요. 전달된 numberSets 5세트는 별도 글머리표로 그대로 표시하고 어떤 조합도 당첨 확률을 높이지 않는다고 설명하세요. 토요일 시간 언급은 19:35(KST) 이전으로 제한하세요.
                문단은 2문장 이내로 나누고 빈 줄을 넣으세요. 제목과 목록은 각각 별도 줄로 작성하세요. 표·코드 블록·내부 변수명은 쓰지 마세요. 굵은 글씨는 문단당 핵심 구절 한 곳에만 사용하세요. 용어는 쉬운 풀이를 붙이고 계산 사실 → 전통적 해석 → 생활 예시를 구분하세요. 마지막에 오락과 자기성찰용이며 중요한 의사결정의 근거로 사용하지 말라는 안내를 포함하세요.

                계산 결과:
                """ + details
                var request = URLRequest(url: url)
                request.httpMethod = "POST"; request.timeoutInterval = 90
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["prompt": prompt])
                let session = URLSession(configuration: .ephemeral)
                defer { session.invalidateAndCancel() }
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let text = message["content"] as? String, !text.isEmpty else {
                    self.aiText = "AI 서버 응답을 받지 못했습니다. 잠시 후 다시 시도해주세요."; return
                }
                guard choices.first?["finish_reason"] as? String != "length" else {
                    self.aiText = "AI 응답이 길이 제한으로 중단되었습니다. 잠시 후 다시 시도해주세요."; return
                }
                self.cachedDetails = details
                self.cachedText = text
                self.aiText = text
            } catch is CancellationError {
                if self.requestID == id { self.aiText = "" }
            } catch {
                if !Task.isCancelled { self.aiText = "AI 연결에 실패했습니다. 인터넷 연결을 확인하고 다시 시도해주세요." }
            }
        }
    }
    func cancelAI() {
        requestID = UUID(); aiTask?.cancel(); aiTask = nil
        aiLoading = false; aiText = ""; cachedDetails = nil; cachedText = ""
    }
    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    }
    func save(to store: ReportStore) {
        webView.evaluateJavaScript(#"""
        (() => {
          const dashboard = document.getElementById('dashboard');
          if (!dashboard || dashboard.classList.contains('hidden')) return null;
          const sets = Array.from(document.querySelectorAll('[id^="numberContainer"]'))
            .map(el => el.innerText.trim().split(/\s+/));
          if (sets.length !== 5 || sets.some(s => s.length !== 6 || new Set(s).size !== 6 || s.some(n => !/^\d{1,2}$/.test(n) || Number(n) < 1 || Number(n) > 45))) return null;
          const selected = id => document.getElementById(id).selectedOptions[0].textContent.trim();
          const inputInfo = '이름: ' + (document.getElementById('inputName').value.trim() || '익명') + '\n' +
            '생년월일 (양력): ' + document.getElementById('inputBirth').value + '\n' +
            '성별: ' + (document.querySelector('input[name="gender"]:checked').value === 'M' ? '남성' : '여성') + '\n' +
            '출생 시간: ' + (document.getElementById('inputExactTime').value || selected('inputTime')) + '\n출생 지역: ' + selected('inputCity');
          const text = '행운 요일: ' + document.getElementById('bestDayInfo').innerText + '\n\n' +
            sets.map((s, i) => '조합 ' + String.fromCharCode(65 + i) + ': ' + s.join(', ')).join('\n');
          return {text, inputInfo};
        })()
        """#) { [weak self] value, error in
            guard let self else { return }
            if let result = value as? [String: String], let text = result["text"], error == nil {
                store.save(text, inputInfo: result["inputInfo"])
                self.message = "입력 정보와 번호 조합을 기기에 저장했습니다. 기록 탭에서 공유하거나 삭제할 수 있습니다."
            } else { self.message = "먼저 분석을 완료하고 번호가 모두 표시될 때까지 기다려주세요." }
            self.showMessage = true
        }
    }
}

struct AnalysisWebView: UIViewRepresentable {
    @ObservedObject var model: AnalysisViewModel
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let view = model.webView
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.isFileURL == true ? .allow : .cancel)
        }
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let scene = webView.window?.windowScene,
                  let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { completionHandler(); return }
            var presenter = root
            while let presented = presenter.presentedViewController { presenter = presented }
            let alert = UIAlertController(title: "입력 확인", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
            presenter.present(alert, animated: true)
        }
    }
}

@main struct SajuLottoApp: App {
    @StateObject private var reflections = ReflectionStore()
    @StateObject private var store = ReportStore()
    @StateObject private var analysis = AnalysisViewModel()
    var body: some Scene {
        WindowGroup {
            TabView {
                ReflectionHomeView(store: reflections).tabItem { Label("회고", systemImage: "pencil.and.outline") }
                ReflectionCollectionView(store: reflections).tabItem { Label("도감", systemImage: "book.closed") }
                NavigationStack {
                    AnalysisWebView(model: analysis)
                        .navigationTitle("천기누설")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("새 분석", systemImage: "arrow.clockwise") { analysis.cancelAI(); analysis.webView.reload() }
                            }
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button("AI 해석", systemImage: "sparkles") { analysis.openAI() }
                                Button("번호 저장", systemImage: "bookmark") { analysis.save(to: store) }
                            }
                        }
                        .alert("안내", isPresented: $analysis.showMessage) { Button("확인", role: .cancel) {} } message: { Text(analysis.message) }
                        .confirmationDialog("AI 분석 서비스로 정보 전송", isPresented: $analysis.showAIConsent, titleVisibility: .visible) {
                            Button("동의하고 AI 해석 요청") { analysis.requestAI() }
                            Button("취소", role: .cancel) {}
                        } message: {
                            Text("계산된 사주팔자·오행·주간 비교·번호 조합·십성·지장간·절기 이름·계산 방식·불확실성 경고를 sajulotto.outinletter.workers.dev(Cloudflare)와 api.deepseek.com(DeepSeek)에 전송하여 해설을 받습니다. 이름·생년월일 원문·정확한 출생 시각·지역·경도값은 전송하지 않습니다. 서버는 연결 IP를 확인할 수 있으며 처리·보관은 각 서비스 정책을 따릅니다. 동의하지 않아도 기본 분석과 번호 생성은 이용할 수 있습니다.")
                        }
                        .sheet(isPresented: $analysis.showAIResult) {
                            NavigationStack {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Text("AI 생성 해석은 오류가 있을 수 있으며 당첨이나 재정적 이익을 예측하지 않습니다.").font(.footnote).foregroundStyle(.secondary)
                                        if analysis.aiLoading { ProgressView("AI 해석을 요청하고 있습니다…") }
                                        AIArticleView(markdown: analysis.aiText).accessibilityElement(children: .combine).accessibilityIdentifier("aiResultText")
                                        Link("AI 제공업체 개인정보 처리방침", destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
                                        Link("Cloudflare 개인정보 처리방침", destination: URL(string: "https://www.cloudflare.com/privacypolicy/")!)
                                    }.padding(.horizontal, 24).padding(.vertical, 28)
                                }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("AI 해석").navigationBarTitleDisplayMode(.inline).toolbar {
                                    Button("닫기") { analysis.showAIResult = false }
                                }
                            }
                        }
                }.tabItem { Label("분석", systemImage: "sparkles") }
                NavigationStack {
                    List {
                        if store.reports.isEmpty { Text("분석 후 ‘번호 저장’을 누르면 이곳에서 번호를 확인할 수 있습니다.").foregroundStyle(.secondary) }
                        ForEach(store.reports) { report in
                            NavigationLink {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 24) {
                                        Text(report.created, format: .dateTime.year().month().day())
                                        if let inputInfo = report.inputInfo {
                                            Text(inputInfo).font(.subheadline).textSelection(.enabled)
                                        }
                                        SavedNumberView(text: report.text)
                                        Text("오락용 번호이며 당첨을 예측하거나 당첨 확률을 높이지 않습니다.").font(.footnote).foregroundStyle(.secondary)
                                        ShareLink(item: report.text + "\n\n오락용 번호입니다. 당첨을 보장하지 않습니다.") { Label("번호 공유", systemImage: "square.and.arrow.up") }
                                    }.padding()
                                }.navigationTitle("저장한 번호")
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(report.created, format: .dateTime.year().month().day().hour().minute())
                                    Text(report.text.components(separatedBy: "\n").first ?? "번호 조합").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.onDelete(perform: store.delete)
                    }.navigationTitle("나의 기록").toolbar { EditButton() }
                }.tabItem { Label("기록", systemImage: "bookmark") }
                NavigationStack {
                    List {
                        Section("한 줄 회고와 주간 도감") {
                            Text("다섯 가지 주제 중 하나에 마음 색과 한 줄을 남기면 번호 카드가 완성됩니다. 한 주에 주제별 한 장을 만들고, 다시 열거나 수정해도 번호는 유지됩니다. 번호는 기기에서 1~45 중 중복 없이 6개를 무작위로 선택하며 기록 내용과 감정은 당첨 확률에 영향을 주지 않습니다.")
                            Text("회고 본문과 손그림은 기기에만 저장하며 AI 서버에 보내지 않습니다. 기기 백업에 포함될 수 있습니다. 공유 미리보기에서는 본문을 기본적으로 숨기며 손그림은 포함되므로 사적인 표시가 없는지 확인하세요. 카드 상세에서 수정·삭제할 수 있습니다.")
                        }
                        Section("서비스 안내") {
                            Text("천기누설은 오락용 사주 해석 및 번호 생성 앱입니다. 복권 구매·판매·베팅 기능이 없으며 당첨이나 재정적 이익을 예측하지 않습니다.")
                            Text("양력만 지원합니다. 절기는 검증된 한국천문연구원 API 자료 또는 천문 계산값을 사용합니다. 원국 계산 근거에서 출처와 시간대·경계 한계를 확인하세요. 중요한 의사결정의 근거로 사용하지 마세요.")
                        }
                        Section("개인정보 처리 안내") {
                            Text("기본 사주 분석과 번호 생성은 기기 안에서 계산합니다. 입력 정보는 번호 저장을 누를 때만 번호와 함께 기기에 보관합니다. AI 해석 요청 시에만 별도 동의를 받아 계산된 사주팔자·오행·주간 비교·번호 조합·십성·지장간·절기 이름·계산 방식·불확실성 경고를 Cloudflare와 DeepSeek에 전송합니다. 이름·생년월일 원문·정확한 시각·지역·경도값은 전송하지 않습니다. 연결 IP와 전송 정보의 처리·보관은 각 서비스 정책을 따릅니다.")
                            Text("직접 저장한 입력 정보, 행운 요일과 번호는 기기에 보관되며 운영체제의 기기 백업에 포함될 수 있습니다. 기록에서 삭제할 수 있습니다.")
                            Text("공유 버튼을 사용하면 선택한 앱에 번호가 전달됩니다. 광고와 추적 SDK는 사용하지 않습니다. AI 해석에는 인터넷 연결과 AI 분석 API를 사용합니다. AI 결과는 앱 실행 중 메모리에만 유지하며 새 분석 또는 앱 종료 시 삭제합니다.")
                        }
                        Section("오픈소스 고지") {
                            Text("Chart.js 4.4.8 · Tailwind CSS — MIT License. 과거 절기 보완 데이터는 Astronomy Engine 2.1.19(MIT)로 산출했습니다. 전체 라이선스는 앱 번들에 포함되어 있습니다.")
                        }
                    }.navigationTitle("안내")
                }.tabItem { Label("안내", systemImage: "info.circle") }
            }.tint(Color(red: 0.63, green: 0.45, blue: 0.27))
        }
    }
}

// Render blocks separately: a single AttributedString loses Markdown paragraph layout.
private struct AIArticleView: View {
    let markdown: String
    private var blocks: [String] {
        markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"(?m)^[ \t]*#{1,6}[ \t]+(.+)$"#, with: "\n## $1\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^[ \t]*[-*_]{3,}[ \t]*$"#, with: "\n", options: .regularExpression)
            .components(separatedBy: "\n")
            .flatMap { line -> [String] in
                let line = line.trimmingCharacters(in: .whitespaces)
                guard !line.hasPrefix("#"), !line.hasPrefix("- "), !line.hasPrefix("* "), line.count > 180 else { return [line] }
                return line.replacingOccurrences(of: #"([.!?。])\s+"#, with: "$1\n", options: .regularExpression)
                    .components(separatedBy: "\n")
            }
            .filter { !$0.isEmpty }
    }
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.hasPrefix("# ") || block.hasPrefix("## ") || block.hasPrefix("### ") {
                    Text(inline(String(block.drop(while: { $0 == "#" || $0 == " " }))))
                        .font(.title3.bold()).foregroundStyle(Color.primary)
                        .padding(.top, 14).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                } else if block.hasPrefix("- ") || block.hasPrefix("* ") {
                    HStack(alignment: .top, spacing: 12) {
                        Text("•").foregroundStyle(.secondary)
                        Text(inline(String(block.dropFirst(2)))).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(inline(block)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.body).lineSpacing(8)
        .frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        .textSelection(.enabled)
    }
}

private struct SavedNumberView: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(text.components(separatedBy: "\n").filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("조합 "), let colon = line.firstIndex(of: ":") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(line[..<colon])).font(.headline)
                        ViewThatFits(in: .horizontal) {
                            balls(line, after: colon, size: 40)
                            balls(line, after: colon, size: 32)
                        }
                    }
                } else {
                    Text(line).font(.subheadline)
                }
            }
        }
    }
    private func balls(_ line: String, after colon: String.Index, size: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(line[line.index(after: colon)...].split(separator: ",").enumerated()), id: \.offset) { _, number in
                Text(String(number).trimmingCharacters(in: .whitespaces))
                    .font(.system(size: size * 0.4, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.14))
                    .frame(width: size, height: size)
                    .background(RadialGradient(colors: [Color(red: 0.98, green: 0.93, blue: 0.85), Color(red: 0.64, green: 0.45, blue: 0.27)], center: .center, startRadius: 0, endRadius: size / 2), in: Circle())
                    .overlay(Circle().fill(Color(red: 0.98, green: 0.97, blue: 0.94)).padding(3))
                    .overlay(Text(String(number).trimmingCharacters(in: .whitespaces)).font(.system(size: size * 0.4, weight: .black, design: .serif)).foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.14)))
                    .overlay(Circle().stroke(Color.brown.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2])).padding(3))
                    .shadow(color: .brown.opacity(0.15), radius: 3, y: 2)
                    .accessibilityLabel(String(number).trimmingCharacters(in: .whitespaces))
            }
        }
    }
}
