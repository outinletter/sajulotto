import SwiftUI

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum AppTheme {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    static let paper = LinearGradient(colors: [dynamic(0xF3F1EC, 0x17161B), dynamic(0xF3F1EC, 0x17161B)], startPoint: .top, endPoint: .bottom)
    static let surface = dynamic(0xFBFAF7, 0x23222A)
    static let accent = dynamic(0x25242B, 0xEDEAF2)
    static let secondary = dynamic(0x74706A, 0xA9A6B4)
    static let bronze = dynamic(0x8A7F6C, 0xC9BFA8)
    static let ink = dynamic(0x25242B, 0xF3F1F7)
    static let line = ink.opacity(0.08)
    static let selection = accent.opacity(0.10)
    static func editorial(_ style: Font.TextStyle) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }
    static func ball(_ number: Int, theme: Int? = nil) -> (background: Color, text: Color) {
        let sample = theme.map { [15, 35, 45, 25, 5][(($0 % 5) + 5) % 5] } ?? number
        switch sample {
        case 1...10: return (Color(red: 241/255, green: 222/255, blue: 173/255), Color(red: 81/255, green: 69/255, blue: 44/255))
        case 11...20: return (Color(red: 214/255, green: 228/255, blue: 239/255), Color(red: 61/255, green: 83/255, blue: 104/255))
        case 21...30: return (Color(red: 234/255, green: 217/255, blue: 219/255), Color(red: 106/255, green: 74/255, blue: 80/255))
        case 31...40: return (Color(red: 223/255, green: 221/255, blue: 237/255), Color(red: 80/255, green: 75/255, blue: 104/255))
        default: return (Color(red: 220/255, green: 230/255, blue: 217/255), Color(red: 68/255, green: 91/255, blue: 73/255))
        }
    }
}

struct LottoNumberRow: View {
    let numbers: [Int]
    var compact = false
    var animate = false
    var theme: Int? = nil
    var revealedCount: Int? = nil
    private var visibleCount: Int { revealedCount ?? (animate ? visible : numbers.count) }
    private var showingAnimation: Bool { animate || revealedCount != nil }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = 0
    var body: some View {
        ViewThatFits(in: .horizontal) {
            balls(size: compact ? 32 : 44, spacing: compact ? 5 : 8)
            balls(size: compact ? 28 : 36, spacing: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(numbers.map(String.init).joined(separator: " · "))
        .accessibilityValue(showingAnimation && visibleCount < numbers.count ? "번호 공개 중" : "번호 공개 완료")
        .task(id: numbers) {
            guard revealedCount == nil else { return }
            guard animate else { visible = numbers.count; return }
            visible = 0
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.15)) { visible = numbers.count }
                return
            }
            for index in numbers.indices {
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { visible = index + 1 }
            }
            if !Task.isCancelled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }
    private func balls(size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(numbers.enumerated()), id: \.offset) { index, number in
                let palette = AppTheme.ball(number, theme: theme)
                ZStack {
                    Circle().stroke(AppTheme.accent.opacity(0.12), lineWidth: 1)
                    Text(String(number)).font(.system(size: size * 0.42, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(palette.text).frame(width: size, height: size)
                        .background(palette.background, in: Circle())
                        .opacity(!showingAnimation || index < visibleCount ? 1 : 0)
                        .scaleEffect(!showingAnimation || index < visibleCount || reduceMotion ? 1 : 0.88)
                        .offset(y: !showingAnimation || index < visibleCount || reduceMotion ? 0 : 6)
                }.frame(width: size, height: size)
            }
        }
    }
}

struct SavedReport: Codable, Identifiable {
    var id = UUID()
    let created: Date
    let text: String
    var inputInfo: String? = nil

    var referenceDate: String? {
        guard text.hasPrefix("기준일: ") else { return nil }
        let date = String(text.dropFirst("기준일: ".count).prefix(10))
        return WeeklyWindow.date(from: date) == nil ? nil : date
    }

    var numberSets: [[Int]] {
        text.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("조합 "), let colon = line.firstIndex(of: ":") else { return nil }
            return line[line.index(after: colon)...].split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
    }
}

final class ReportStore: ObservableObject {
    @Published var reports: [SavedReport] = []
    private let defaults: UserDefaults
    init(defaults: UserDefaults? = nil) {
        var selected = defaults ?? .standard
        #if DEBUG
        if defaults == nil, let raw = ProcessInfo.processInfo.environment["REFLECTION_TEST_STORE"], let id = UUID(uuidString: raw),
           let isolated = UserDefaults(suiteName: "SajuLottoTests." + id.uuidString) { selected = isolated }
        #endif
        self.defaults = selected
        if let data = selected.data(forKey: "savedReports"),
           let saved = try? JSONDecoder().decode([SavedReport].self, from: data) { reports = saved }
    }
    func save(_ text: String, inputInfo: String? = nil) {
        guard !reports.contains(where: { $0.text == text && $0.inputInfo == inputInfo }) else { return }
        reports.insert(SavedReport(created: Date(), text: text, inputInfo: inputInfo), at: 0)
        persist()
    }
    func reset() { defaults.removeObject(forKey: "savedReports"); reports = [] }
    func delete(_ report: SavedReport) { reports.removeAll { $0.id == report.id }; persist() }
    func deleteReferenceDate(_ date: String) { reports.removeAll { $0.referenceDate == date }; persist() }
    func persist() {
        if let data = try? JSONEncoder().encode(reports) { defaults.set(data, forKey: "savedReports") }
    }
}


private struct AppTabVisibility: ViewModifier {
    let isVisible: Bool
    func body(content: Content) -> some View {
        content.opacity(isVisible ? 1 : 0).allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible).zIndex(isVisible ? 1 : 0)
    }
}

@main struct SajuLottoApp: App {
    @StateObject private var reflections = ReflectionStore()
    @StateObject private var store = ReportStore()
    @State private var confirmReset = false
    @State private var resetError: String?
    @State private var resetID = UUID()
    @State private var selectedTab = 0
    @State private var recordsMode = 0
    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("weeklyReminders") private var reminders = false
    @State private var collectionDate: String?
    @State private var collectionID = UUID()
    @State private var keyboardVisible = false
    private func openCollection(_ date: String) {
        collectionDate = date
        collectionID = UUID()
        recordsMode = 1
        selectedTab = 2
    }
    private func resetApp() {
        do {
            try reflections.reset()
            store.reset()
            try AnalysisDraftStore().reset()
            for key in [WeeklyReflection.storageKey, WeeklyReflection.birthDateKey, WeeklyReflection.themeKey, SajuProfile.hourKey, SajuProfile.extraKey, "sajuWeeklyNumbers", "sajuDecisionHistory", "onboardingDone", "weeklyReminders"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            Task { _ = await WeeklyReminder.set(false) }
            selectedTab = 0; recordsMode = 0; collectionDate = nil; resetID = UUID()
        } catch { resetError = "초기화하지 못했습니다. 잠시 후 다시 시도해주세요." }
    }
    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(0, title: "선택", symbol: "wand.and.stars")
                tabButton(1, title: "이번 주", symbol: "calendar")
                tabButton(2, title: "기록", symbol: "book.pages")
                tabButton(3, title: "설정", symbol: "gearshape")
            }.padding(.horizontal, 12).padding(.vertical, 4)
                .appGlass(Capsule())
                .padding(.horizontal, 16).padding(.bottom, 4)
        }
    }
    private func tabButton(_ index: Int, title: String, symbol: String) -> some View {
        Button { selectedTab = index } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.body.weight(selectedTab == index ? .semibold : .regular))
                    .frame(minWidth: 48, minHeight: 29)
                    .foregroundStyle(selectedTab == index ? tone.beadInk : AppTheme.secondary)
                    .background(selectedTab == index ? tone.bead : Color.clear, in: Capsule())
                Text(title).font(.caption.weight(selectedTab == index ? .semibold : .regular))
            }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(selectedTab == index ? AppTheme.ink : AppTheme.secondary)
            .accessibilityLabel(title).accessibilityIdentifier("app-tab-\(index)").accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }

    private var settings: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 6) {
                    ToneChip(text: "이번 주의 선택 · 설정")
                    Text("설정").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                Section("내 사주 정보") {
                    NavigationLink {
                        ScrollView { SajuProfileCard().padding(20) }
                            .background(AppTheme.paper).navigationTitle("내 사주 정보")
                    } label: {
                        Label("생년월일·시각·성별·출생지", systemImage: "person.text.rectangle")
                    }
                    NavigationLink { SajuDetailView() } label: { Label("내 사주 자세히 보기", systemImage: "scroll") }
                }
                Section("알림") {
                    Toggle("주간 알림", isOn: Binding(get: { reminders }, set: { on in
                        Task { let ok = await WeeklyReminder.set(on); reminders = on && ok }
                    })).tint(Element.wood.color).accessibilityIdentifier("weekly-reminders")
                    Text("일요일 오전 9시에 번호 생성 알림, 토요일 오후 4시 35분에 마감 3시간 전 알림을 보내요.")
                        .font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
                Section("이용 안내") {
                    Text("선택: 선택지 2~3개를 넣으면 오늘의 기운과 내 사주로 오행 일치도를 재서 하나를 골라요.")
                    Text("이번 주: 한 주의 좋은 날을 보고, 덤으로 오락용 번호를 한 번 만들어 볼 수 있어요. 당첨을 예측하거나 확률을 높이지 않아요.")
                }
                Section("회고와 주간 도감") {
                    Text("회고 탭에서 날짜를 골라 한 가지 질문에만 답해도 도감에 저장할 수 있습니다.")
                    Text("한 주는 한국 시간 일요일에 시작합니다. 주간 마무리에 저장한 작은 행동은 다음 주 첫 화면에서 다시 볼 수 있습니다.")
                }
                Section("개인정보와 지원") {
                    NavigationLink("개인정보 처리방침") { PrivacyPolicyView() }
                    Link("지원·문의", destination: PrivacyPolicyView.webURL)
                    Text("문의할 때 생년월일 같은 개인정보는 보내지 않아도 돼요.")
                        .font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
                Section("데이터 관리") {
                    Button("앱 데이터 초기화", role: .destructive) { confirmReset = true }.accessibilityIdentifier("app-reset")
                    Text("회고, 주간 마무리, 생년월일 및 이전 버전의 저장 데이터를 삭제합니다.")
                        .font(.footnote).foregroundStyle(AppTheme.secondary)
                }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).contentMargins(.bottom, 90)
                .background(AppTheme.paper.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        }
    }

    private var records: some View {
        VStack(spacing: 0) {
            Picker("기록", selection: $recordsMode) { Text("회고").tag(0); Text("도감").tag(1) }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.top, 8)
            ZStack {
                ReflectionHomeView(store: reflections, openCollection: openCollection)
                    .modifier(AppTabVisibility(isVisible: recordsMode == 0))
                ReflectionCollectionView(store: reflections, reports: store, targetDate: collectionDate)
                    .id(collectionID)
                    .modifier(AppTabVisibility(isVisible: recordsMode == 1))
            }
        }
    }

    private var tone: Element { SajuEngine.dayPillar(Date()).stemElement }

    private func openRecords() { recordsMode = 0; selectedTab = 2 }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
            ZStack {
                WeeklyNumberView().modifier(AppTabVisibility(isVisible: selectedTab == 1))
                DecisionView(openReflection: openRecords).modifier(AppTabVisibility(isVisible: selectedTab == 0))
                records.modifier(AppTabVisibility(isVisible: selectedTab == 2))
                settings.modifier(AppTabVisibility(isVisible: selectedTab == 3))
            }.id(resetID).frame(maxWidth: .infinity, maxHeight: .infinity)
            if !keyboardVisible { bottomBar }
            }.tint(AppTheme.accent).background(AppTheme.paper)
                .fullScreenCover(isPresented: Binding(get: { !onboardingDone }, set: { _ in })) {
                    OnboardingView { onboardingDone = true }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
                .alert("앱 데이터를 모두 초기화할까요?", isPresented: $confirmReset) {
                    Button("모든 데이터 삭제", role: .destructive) { resetApp() }
                    Button("취소", role: .cancel) {}
                } message: { Text("이 기기의 회고, 주간 마무리, 생년월일과 이전 기록이 삭제됩니다. 되돌릴 수 없습니다.") }
                .alert("초기화 안내", isPresented: Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } })) {
                    Button("확인") { resetError = nil }
                } message: { Text(resetError ?? "") }
        }
    }
}

// Render blocks separately: a single AttributedString loses Markdown paragraph layout.
struct SavedNumberView: View {
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
        let label = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        let theme = label.last?.asciiValue.map { Int($0) - 65 }
        return LottoNumberRow(numbers: line[line.index(after: colon)...].split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }, theme: theme)
    }
}
