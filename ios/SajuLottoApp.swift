import SwiftUI
import WebKit

struct SavedReport: Codable, Identifiable {
    var id = UUID()
    let created: Date
    let text: String
}

final class ReportStore: ObservableObject {
    @Published var reports: [SavedReport] = []
    init() {
        if let data = UserDefaults.standard.data(forKey: "savedReports"),
           let saved = try? JSONDecoder().decode([SavedReport].self, from: data) { reports = saved }
    }
    func save(_ text: String) {
        reports.insert(SavedReport(created: Date(), text: text), at: 0)
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
    func requestAI() {
        guard !aiLoading else { return }
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DeepSeekProxyURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else {
            message = "AI 서버 주소가 설정되지 않았습니다."; showMessage = true; return
        }
        aiText = ""; aiLoading = true; showAIResult = true
        aiTask = Task { [weak self] in
            guard let self else { return }
            defer { self.aiLoading = false }
            do {
                let value = try await self.webView.evaluateJavaScript(#"""
                (() => {
                    if (document.getElementById('dashboard').classList.contains('hidden')) return null;
                    const pillars = ['year','month','day','hour'].map(p => document.getElementById('saju-'+p+'-hanja').innerText.replace(/\n/g, ''));
                    const elements = ['wood','fire','earth','metal','water'].map(p => document.getElementById('dist-'+p).innerText);
                    return '사주팔자(년월일시): '+pillars.join(', ')+'; 오행(목화토금수): '+elements.join(', ')+'; 참고 요일: '+document.getElementById('bestDayInfo').innerText;
                })()
                """#)
                guard let details = value as? String else {
                    self.aiText = "먼저 사주 분석을 완료해주세요."; return
                }
                let prompt = "오락용 사주 해석을 한국어로 800자 이내로 작성하세요. 한자는 한글과 함께 표기하고 일상적인 휴식과 동기부여를 제안하세요. 복권 당첨·확률 상승·재정적 이익을 예측하거나 보장하지 말고 의료·투자 조언을 하지 마세요. 불확실한 AI 생성 해석임을 밝히세요.\n" + details
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
                self.aiText = text
            } catch is CancellationError {
                self.aiText = ""
            } catch {
                if !Task.isCancelled { self.aiText = "AI 연결에 실패했습니다. 인터넷 연결을 확인하고 다시 시도해주세요." }
            }
        }
    }
    func cancelAI() { aiTask?.cancel(); aiTask = nil; aiText = "" }
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
          return '행운 요일: ' + document.getElementById('bestDayInfo').innerText + '\n\n' +
            sets.map((s, i) => '조합 ' + String.fromCharCode(65 + i) + ': ' + s.join(', ')).join('\n');
        })()
        """#) { [weak self] value, error in
            guard let self else { return }
            if let text = value as? String, error == nil {
                store.save(text)
                self.message = "번호 조합을 기기에 저장했습니다. 기록 탭에서 공유하거나 삭제할 수 있습니다."
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
    @StateObject private var store = ReportStore()
    @StateObject private var analysis = AnalysisViewModel()
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    AnalysisWebView(model: analysis)
                        .navigationTitle("천기누설")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("새 분석", systemImage: "arrow.clockwise") { analysis.cancelAI(); analysis.webView.reload() }
                            }
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button("AI 해석", systemImage: "sparkles") { analysis.showAIConsent = true }.disabled(analysis.aiLoading)
                                Button("번호 저장", systemImage: "bookmark") { analysis.save(to: store) }
                            }
                        }
                        .alert("안내", isPresented: $analysis.showMessage) { Button("확인", role: .cancel) {} } message: { Text(analysis.message) }
                        .confirmationDialog("AI 분석 서비스로 정보 전송", isPresented: $analysis.showAIConsent, titleVisibility: .visible) {
                            Button("동의하고 AI 해석 요청") { analysis.requestAI() }
                            Button("취소", role: .cancel) {}
                        } message: {
                            Text("계산된 사주팔자·오행 분포·참고 요일을 앱의 Cloudflare 서버와 외부 AI 분석 서비스에 전송하여 AI 해석을 받습니다. 이름·생년월일·지역은 전송하지 않습니다. 서버는 연결 IP를 확인할 수 있으며 처리·보관은 각 서비스 정책을 따릅니다. 동의하지 않아도 기본 분석과 번호 생성은 이용할 수 있습니다.")
                        }
                        .sheet(isPresented: $analysis.showAIResult, onDismiss: { analysis.cancelAI() }) {
                            NavigationStack {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Text("AI 생성 해석은 오류가 있을 수 있으며 당첨이나 재정적 이익을 예측하지 않습니다.").font(.footnote).foregroundStyle(.secondary)
                                        if analysis.aiLoading { ProgressView("AI 해석을 요청하고 있습니다…") }
                                        Text(analysis.aiText).textSelection(.enabled).accessibilityIdentifier("aiResultText")
                                        Link("AI 제공업체 개인정보 처리방침", destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
                                        Link("Cloudflare 개인정보 처리방침", destination: URL(string: "https://www.cloudflare.com/privacypolicy/")!)
                                    }.padding()
                                }.navigationTitle("AI 해석").toolbar {
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
                                        Text(report.text).font(.body.monospacedDigit()).textSelection(.enabled)
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
                        Section("서비스 안내") {
                            Text("천기누설은 오락용 사주 해석 및 번호 생성 앱입니다. 복권 구매·판매·베팅 기능이 없으며 당첨이나 재정적 이익을 예측하지 않습니다.")
                            Text("양력만 지원합니다. 절기 경계는 근사값이므로 전문 만세력과 결과가 다를 수 있습니다. 중요한 의사결정의 근거로 사용하지 마세요.")
                        }
                        Section("개인정보 처리 안내") {
                            Text("기본 사주 분석과 번호 생성은 기기 안에서 계산합니다. 이름, 생년월일, 성별, 출생 시간과 지역은 저장하지 않으며 새 분석 또는 앱 종료 시 사라집니다. AI 해석 요청 시에만 별도 동의를 받아 계산된 사주팔자·오행 분포·참고 요일을 Cloudflare 서버와 외부 AI 분석 서비스에 전송합니다. 연결 IP와 전송 정보의 처리·보관은 각 서비스 정책을 따릅니다.")
                            Text("직접 저장한 행운 요일과 번호는 기기에 보관되며 운영체제의 기기 백업에 포함될 수 있습니다. 기록에서 삭제할 수 있습니다. 이름과 생년월일은 저장하지 않습니다.")
                            Text("공유 버튼을 사용하면 선택한 앱에 번호가 전달됩니다. 광고와 추적 SDK는 사용하지 않습니다. AI 해석에는 인터넷 연결과 AI 분석 API를 사용합니다. AI 결과는 앱에 저장하지 않습니다.")
                        }
                        Section("오픈소스 고지") {
                            Text("Chart.js 4.4.8 · Tailwind CSS — MIT License. 전체 라이선스는 앱 번들에 포함되어 있습니다.")
                        }
                    }.navigationTitle("안내")
                }.tabItem { Label("안내", systemImage: "info.circle") }
            }.tint(Color(red: 0.63, green: 0.45, blue: 0.27))
        }
    }
}
