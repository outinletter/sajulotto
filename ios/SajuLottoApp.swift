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
                                Button("새 분석", systemImage: "arrow.clockwise") { analysis.webView.reload() }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("번호 저장", systemImage: "bookmark") { analysis.save(to: store) }
                            }
                        }
                        .alert("안내", isPresented: $analysis.showMessage) { Button("확인", role: .cancel) {} } message: { Text(analysis.message) }
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
                            Text("입력한 이름, 생년월일, 성별, 출생 시간과 지역은 기기 안에서만 계산하며 저장하거나 외부 서버로 전송하지 않습니다. 새 분석 또는 앱 종료 시 사라집니다.")
                            Text("직접 저장한 행운 요일과 번호는 기기에 보관되며 운영체제의 기기 백업에 포함될 수 있습니다. 기록에서 삭제할 수 있습니다. 이름과 생년월일은 저장하지 않습니다.")
                            Text("공유 버튼을 사용하면 선택한 앱에 번호가 전달됩니다. 광고, 추적, 분석 SDK 및 외부 API를 사용하지 않습니다.")
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
