import SwiftUI

private let reflectionPaper = AppTheme.paper
extension ReflectionMood {
    var color: Color {
        switch self {
        case .warm: return Color(red: 0.76, green: 0.40, blue: 0.28)
        case .calm: return Color(red: 0.30, green: 0.47, blue: 0.41)
        case .fresh: return Color(red: 0.53, green: 0.57, blue: 0.25)
        case .quiet: return Color(red: 0.34, green: 0.46, blue: 0.64)
        case .complex: return Color(red: 0.54, green: 0.43, blue: 0.62)
        }
    }
}

extension WeeklyTheme {
    /// 한 줄 기록은 주제별로 하루 한 장씩 도감에 저장된다
    var topic: ReflectionTopic {
        switch self { case .focus: return .achievement; case .relationships: return .gratitude; case .rest: return .joy }
    }
}

struct ReflectionHomeView: View {
    @ObservedObject var store: ReflectionStore
    let openCollection: (String) -> Void
    @AppStorage(WeeklyReflection.themeKey) private var theme = WeeklyTheme.focus
    @State private var now = Date()
    @State private var text = ""
    @State private var savedText = ""
    @State private var message: String?
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var promptHeight: CGFloat = 92
    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 112

    private var week: Date { WeeklyWindow(containing: now).start }
    private var weekKey: String { ReflectionStore.journalDateKey(week) }
    private var tone: Element { SajuEngine.dayPillar(now).stemElement }
    private var prompt: (sentence: String, question: String) { theme.prompt(for: week) }
    private var weekCards: [ReflectionCard] { store.cards.filter { $0.isJournal && $0.weekID == weekKey } }
    private var clean: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !clean.isEmpty && clean.count <= 500 && clean != savedText }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        ToneChip(text: "\(WeeklyWindow.label(week)) 시작 주 · 회고")
                        Text("이번 주를\n한 줄로 남겨요").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                    }
                    writeCard
                    if !weekCards.isEmpty { recent }
                }.padding(20).padding(.bottom, 90).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(reflectionPaper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { focused = false } } }
            .environment(\.calendar, ReflectionStore.calendar)
            .environment(\.timeZone, ReflectionStore.calendar.timeZone)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in now = Date() }
            .task(id: theme) { load() }
            .alert("기록 안내", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("확인") { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private var writeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("이번 주 관심사", selection: $theme) {
                ForEach(WeeklyTheme.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityLabel("이번 주 관심사")
            VStack(alignment: .leading, spacing: 10) {
                Text(prompt.sentence).font(.subheadline).foregroundStyle(AppTheme.secondary).lineLimit(1).minimumScaleFactor(0.85)
                Text(prompt.question).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(AppTheme.ink)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }.frame(maxWidth: .infinity, minHeight: promptHeight, maxHeight: promptHeight, alignment: .topLeading)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text).focused($focused).scrollContentBackground(.hidden).font(.body)
                    .frame(height: editorHeight).padding(10)
                    .background(AppTheme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("reflection-text")
                if text.isEmpty {
                    Text("한 줄 쓰기 · 여기를 눌러 바로 적어 보세요").font(.body).foregroundStyle(AppTheme.secondary.opacity(0.75))
                        .padding(.horizontal, 15).padding(.vertical, 18).allowsHitTesting(false)
                }
            }
            HStack {
                Text("\(text.count)/500").font(.footnote).foregroundStyle(text.count > 500 ? .red : AppTheme.secondary)
                Spacer()
                if !clean.isEmpty && clean == savedText { Label("도감에 저장됨", systemImage: "checkmark.circle.fill").font(.footnote.weight(.semibold)).foregroundStyle(Element.wood.color) }
            }
            Button(!clean.isEmpty && clean == savedText ? "저장됨" : "저장하기") { save() }
                .buttonStyle(ToneButtonStyle(element: tone)).disabled(!canSave).accessibilityIdentifier("reflection-save")
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .appGlass(RoundedRectangle(cornerRadius: 28), tint: tone.bead.opacity(0.35))
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이번 주 기록").font(.headline).foregroundStyle(AppTheme.ink)
                Spacer()
                Button("도감 보기") { openCollection(ReflectionStore.journalDateKey(now)) }.font(.subheadline.weight(.semibold))
            }
            ForEach(weekCards.prefix(5)) { card in
                let e = Element(rawValue: card.topic.rawValue.utf8.reduce(0) { $0 &+ Int($1) } % 5)!
                Button { openCollection(card.referenceDate ?? ReflectionStore.journalDateKey(card.created)) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: card.topic.symbol).font(.body).foregroundStyle(e.beadInk)
                            .frame(width: 40, height: 40).background(e.bead, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.question ?? card.displayTitle).font(.footnote).foregroundStyle(AppTheme.secondary).lineLimit(1)
                            Text(card.text).font(.body).foregroundStyle(AppTheme.ink).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .appGlass(RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
        }
    }

    private func load() {
        let existing = store.journalCard(for: theme.topic, on: now)
        text = existing?.text ?? ""
        savedText = text
    }

    private func save() {
        do {
            let mood = store.journalCard(for: theme.topic, on: now)?.mood ?? .calm
            let card = try store.save(topic: theme.topic, mood: mood, text: text, strokes: [], now: now, journalDate: now, question: prompt.question)
            text = card.text; savedText = card.text; focused = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { message = error.localizedDescription }
    }
}

struct SentenceNumberView: View {
    @ObservedObject var store: ReflectionStore
    @AppStorage(WeeklyReflection.storageKey) private var weeklyData = Data()
    @State private var sentence = ""
    @State private var generated: [[Int]] = []
    @State private var resultWeek: String?
    @FocusState private var focused: Bool

    private var strokes: [Int] { SentenceNumberGenerator.strokes(in: sentence) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("한글 문장으로 번호 5세트를 만드는 오락 기능입니다. 당첨을 예측하거나 확률을 높이지 않습니다.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                let key = ReflectionStore.weekID(for: Date())
                let cards = store.cards.filter { $0.isJournal && $0.weekID == key }
                if let wrap = WeeklyReflection.load(weeklyData)[key] {
                    Button("이번 주에 남긴 문장 사용") { sentence = wrap.sentence }
                }
                if !cards.isEmpty {
                    Menu("이번 주 회고에서 고르기") {
                        ForEach(cards) { card in
                            Button(String(card.text.prefix(48))) { sentence = card.text }
                        }
                    }
                }
                TextField("사용할 한글 문장을 입력하세요", text: $sentence, axis: .vertical)
                    .lineLimit(3...5).padding(12).appGlass(RoundedRectangle(cornerRadius: 12))
                    .focused($focused).accessibilityIdentifier("number-sentence")
                Text("완성된 한글 글자만 사용해 자모의 획수를 세고, 글자 순서와 한국 시간 주차를 반영합니다. 같은 주에 획수 순서가 같으면 같은 번호가 나와요.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                Button("오락용 번호 5세트 만들기") {
                    focused = false
                    let currentWeek = ReflectionStore.weekID(for: Date())
                    generated = SentenceNumberGenerator.sets(for: strokes, weekKey: currentWeek)
                    resultWeek = currentWeek
                }.buttonStyle(AppPrimaryButtonStyle()).disabled(strokes.isEmpty || sentence.count > 500)
                if sentence.count > 500 { Text("500자 이내로 입력해 주세요.").font(.footnote).foregroundStyle(.red) }
                if let resultWeek, !generated.isEmpty {
                    Text("\(resultWeek) 시작 주 · 오락용 번호").font(.headline)
                    LottoNumberSequence(sets: generated)
                    let numbers = generated.map { $0.map(String.init).joined(separator: ", ") }.joined(separator: "\n")
                    ShareLink(item: numbers + "\n\n오락용 번호입니다. 당첨 확률을 높이지 않습니다.") {
                        Label("번호만 공유", systemImage: "square.and.arrow.up")
                    }
                }
            }.padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(AppTheme.paper)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("오락용 번호 만들기").navigationBarTitleDisplayMode(.inline)
        .onChange(of: sentence) { _, _ in generated = []; resultWeek = nil }
    }
}

    private struct ReflectionEditor: View {
        @ObservedObject var store: ReflectionStore
        let topic: ReflectionTopic
        let existing: ReflectionCard?
        let journalDate: Date?
        let inline: Bool
        let onCancel: (() -> Void)?
        let onSaved: (ReflectionCard) -> Void
        @Environment(\.dismiss) private var dismiss
        @State private var text: String
        @State private var mood: ReflectionMood
        @State private var strokes: [ReflectionStroke]
        @State private var error: String?
        @State private var saving = false
        @FocusState private var textFocused: Bool
        init(store: ReflectionStore, topic: ReflectionTopic, existing: ReflectionCard? = nil, inline: Bool = false, onCancel: (() -> Void)? = nil, journalDate: Date? = nil, onSaved: @escaping (ReflectionCard) -> Void) {
            self.store = store; self.topic = topic; self.existing = existing; self.inline = inline; self.onCancel = onCancel; self.onSaved = onSaved; self.journalDate = journalDate
            _text = State(initialValue: existing?.text ?? "")
            _mood = State(initialValue: existing?.mood ?? .warm)
            _strokes = State(initialValue: existing?.strokes ?? [])
        }
        private var fields: some View {
            VStack(alignment: .leading, spacing: 24) {
                if let journalDate {
                    Label(WeeklyWindow.label(journalDate), systemImage: "calendar")
                        .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.accent)
                }
                Text(existing?.question ?? (journalDate == nil ? topic.question : topic.journalQuestion))
                    .font(AppTheme.editorial(.title)).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("지금의 마음 색").font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ReflectionMood.allCases) { item in
                                Button { mood = item } label: {
                                    VStack(spacing: 7) {
                                        Circle().fill(item.color).frame(width: 36, height: 36)
                                            .overlay { if mood == item { Image(systemName: "checkmark").foregroundStyle(.white).font(.footnote.bold()) } }
                                        Text(item.title).font(.footnote).foregroundStyle(.primary)
                                    }.padding(8)
                                }.accessibilityLabel(item.title).accessibilityIdentifier("reflection-mood-\(item.rawValue)")
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("나에게 남기는 한 줄").font(.subheadline.weight(.semibold)); Spacer(); Text("\(text.count)/500").font(.footnote).foregroundStyle(text.count > 500 ? .red : .secondary) }
                    TextField("예: 바쁜 하루에도 잠깐 산책을 했다", text: $text, axis: .vertical)
                        .lineLimit(3...6).padding(16).appGlass(RoundedRectangle(cornerRadius: 16))
                        .focused($textFocused).accessibilityIdentifier("reflection-text")
                        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { textFocused = false } } }
                    Text("잘 쓸 필요 없어요. 다른 사람의 실명이나 연락처는 적지 않아도 됩니다.")
                        .font(.footnote).foregroundStyle(AppTheme.secondary)
                }
                if journalDate != nil || existing?.isJournal == true {
                    Text("저장하면 선택한 날짜의 도감에 기록됩니다.")
                        .font(.footnote).foregroundStyle(AppTheme.secondary)
                }
                Button {
                    guard !saving else { return }; saving = true
                    do {
                        let card = try store.save(topic: topic, mood: mood, text: text, strokes: strokes, editing: existing?.id, journalDate: journalDate)
                        textFocused = false
                        if !inline { dismiss() }; onSaved(card)
                    } catch { self.error = error.localizedDescription; saving = false }
                } label: {
                    Label(existing == nil ? "도감에 저장" : "기록 수정 저장", systemImage: "sparkles")
                        .font(.headline).frame(maxWidth: .infinity).padding(16)
                }.buttonStyle(.borderedProminent).tint(mood.color)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 500 || saving)
                    .accessibilityIdentifier("reflection-save")
            }.padding(22)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("입력 완료") { textFocused = false } }
            }
            .alert("저장 안내", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
        }
        var body: some View {
            if inline {
                VStack(spacing: 0) {
                    fields
                    Button("입력창 닫기") { textFocused = false; onCancel?() }.font(.footnote).padding(.bottom, 18)
                }
            } else {
                NavigationStack {
                    ScrollView { fields }
                        .background(reflectionPaper).scrollDismissesKeyboard(.interactively)
                        .navigationTitle(existing == nil ? topic.title : "기록 수정").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
                }
            }
        }
    }

    private struct ReflectionInk: View {
        let strokes: [ReflectionStroke]
        let color: Color
        var body: some View {
            Canvas { context, size in
                for stroke in strokes {
                    guard let first = stroke.points.first else { continue }
                    var path = Path(); path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in stroke.points.dropFirst() { path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }
                    if stroke.points.count == 1 { path.addLine(to: CGPoint(x: first.x * size.width + 0.5, y: first.y * size.height + 0.5)) }
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }.accessibilityHidden(true)
        }
    }

    private struct ReflectionArtwork: View {
        let card: ReflectionCard
        var includeBody = true
        var revealed = true
        var animateNumbers = false
        var body: some View {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text(card.isJournal ? "나의 회고" : "이번 주의 여섯 장면").font(.footnote.weight(.medium)); Spacer(); Image(systemName: card.topic.symbol) }
                    .foregroundStyle(card.mood.color)
                Text(card.displayTitle).font(.system(.title, design: .serif).bold())
                Text(card.referenceDate.map { "기준일: " + $0 } ?? card.dateText)
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
                if includeBody, let question = card.question { Text(question).font(.subheadline).foregroundStyle(AppTheme.secondary) }
                if includeBody { Text(card.text).font(.body).lineSpacing(6).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("reflection-body") }
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(card.mood.color.opacity(0.07))
                    Image(systemName: card.topic.symbol).font(.system(size: 62, weight: .ultraLight)).foregroundStyle(card.mood.color.opacity(0.2))
                    ReflectionInk(strokes: card.strokes, color: card.mood.color)
                }.frame(height: 120)
                Text(card.topic.affirmation).font(.subheadline.weight(.medium)).foregroundStyle(card.mood.color)
                if !card.isJournal {
                    LottoNumberRow(numbers: card.numbers, animate: animateNumbers, theme: ReflectionTopic.allCases.firstIndex(of: card.topic)).id(revealed).accessibilityIdentifier("reflection-numbers")
                    ForEach(Array((card.additionalNumberSets ?? []).enumerated()), id: \.offset) { index, numbers in
                        LottoNumberRow(numbers: numbers, theme: ReflectionTopic.analysisTopics.count + index)
                    }
                    Text("오락용 무작위 조합 · 당첨 확률을 높이지 않습니다.").font(.caption).foregroundStyle(AppTheme.secondary)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .appGlass(RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(card.mood.color.opacity(0.2)))
        }
    }

    private struct ReflectionDetailView: View {
        @ObservedObject var store: ReflectionStore
        let original: ReflectionCard
        @Environment(\.dismiss) private var dismiss
        @State private var editing: ReflectionCard?
        @State private var sharing: ReflectionCard?
        @State private var deleting = false
        @State private var revealed = false
        private var card: ReflectionCard { store.cards.first { $0.id == original.id } ?? original }
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    ReflectionArtwork(card: card, revealed: revealed, animateNumbers: true)
                    Button("흔적 다시 보기", systemImage: "arrow.clockwise") {
                        revealed = false
                        Task { try? await Task.sleep(for: .milliseconds(150)); revealed = true }
                    }.font(.subheadline).accessibilityIdentifier("reflection-replay")
                    Button { sharing = card } label: { Label("카드 공유", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(12) }
                        .buttonStyle(.borderedProminent).tint(card.mood.color).accessibilityIdentifier("reflection-share")
                    Text("공유 미리보기에서 본문을 숨길 수 있어요. 기본값은 본문 숨김입니다.").font(.footnote).foregroundStyle(AppTheme.secondary)
                    Button("이 카드 삭제", role: .destructive) { deleting = true }.font(.footnote).padding(.top, 14)
                }.padding(20)
            }.background(reflectionPaper).navigationTitle("나의 한 장면").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("수정") { editing = card }.accessibilityIdentifier("reflection-edit") }
                .task { revealed = true }
                .sheet(item: $editing) { card in ReflectionEditor(store: store, topic: card.topic, existing: card) { _ in } }
                .sheet(item: $sharing) { card in ReflectionShareView(card: card) }
                .confirmationDialog("이 기록을 삭제할까요?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("카드 삭제", role: .destructive) {
                        do { try store.delete(card); dismiss() } catch { store.errorMessage = error.localizedDescription }
                    }
                }
        }
    }

    private struct ReflectionShareView: View {
        let card: ReflectionCard
        @Environment(\.dismiss) private var dismiss
        @State private var includeBody = false
        @State private var image: UIImage?
        private func render() {
            let renderer = ImageRenderer(content: ReflectionArtwork(card: card, includeBody: includeBody).frame(width: 360).padding(16).background(reflectionPaper).environment(\.colorScheme, .light))
            renderer.scale = 3; image = renderer.uiImage
        }
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Toggle("기록 본문도 포함", isOn: $includeBody).accessibilityIdentifier("reflection-share-body")
                        Text("손그림은 카드에 포함됩니다. 이름이나 사적인 내용을 그렸다면 공유 전 확인하세요.").font(.footnote).foregroundStyle(AppTheme.secondary)
                        ReflectionArtwork(card: card, includeBody: includeBody).accessibilityIdentifier("reflection-share-preview")
                        if let image {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview("이번 주의 여섯 장면", image: Image(uiImage: image))) {
                                Label("이 카드 이미지 공유", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(12)
                            }.buttonStyle(.borderedProminent).tint(card.mood.color)
                        }
                    }.padding(20)
                }.background(reflectionPaper).navigationTitle("공유 미리보기").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("닫기") { dismiss() } }
                    .task { render() }.onChange(of: includeBody) { _, _ in render() }
            }
        }
    }

    struct ReflectionCollectionView: View {
        @ObservedObject var store: ReflectionStore
        @ObservedObject var reports: ReportStore
        let targetDate: String?
        @State private var expandedDates: Set<String> = []
        @State private var didOpenTarget = false
        @AppStorage(WeeklyReflection.storageKey) private var weeklyData = Data()
        private var dates: [String] {
            Set(store.cards.compactMap(\.referenceDate) + reports.reports.compactMap(\.referenceDate)).sorted(by: >)
        }

        var body: some View {
            NavigationStack {
                ScrollViewReader { proxy in
                List {
                    VStack(alignment: .leading, spacing: 8) {
                        ToneChip(text: "이번 주의 선택 · 도감")
                        Text("나의 도감").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
                        Text("하루의 한 줄과 한 주의 실천을 모아둡니다.")
                            .font(.subheadline).foregroundStyle(AppTheme.secondary)
                        if dates.isEmpty && WeeklyReflection.load(weeklyData).isEmpty {
                            Label("아직 기록이 없어요. 회고 탭에서 한 줄을 남기면 여기에 모여요.", systemImage: "books.vertical")
                                .font(.subheadline).foregroundStyle(AppTheme.secondary)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .appGlass(RoundedRectangle(cornerRadius: 20)).padding(.top, 8)
                        }
                    }.listRowBackground(Color.clear).listRowSeparator(.hidden)

                        let weeks = WeeklyReflection.load(weeklyData)
                        if !weeks.isEmpty {
                            Section("한 주 마무리") {
                                ForEach(weeks.keys.sorted(by: >), id: \.self) { key in
                                    if let record = weeks[key] {
                                        DisclosureGroup("\(key) 시작 주") {
                                            Text(record.sentence).font(.subheadline)
                                            Label(record.action, systemImage: "arrow.right.circle").font(.subheadline)
                                        }.swipeActions(allowsFullSwipe: false) {
                                            Button("삭제", role: .destructive) {
                                                var updated = weeks
                                                updated.removeValue(forKey: key)
                                                if let encoded = try? JSONEncoder().encode(updated) { weeklyData = encoded }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if dates.isEmpty && store.cards.isEmpty && reports.reports.isEmpty && weeks.isEmpty {
                        ContentUnavailableView("첫 장면을 기다리고 있어요", systemImage: "book.closed", description: Text("회고 탭에서 날짜를 골라 한 줄을 남겨보세요."))
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }

                    ForEach(dates, id: \.self) { date in
                        let dateCards = store.cards.filter { $0.referenceDate == date }
                        let dateReports = reports.reports.filter { $0.referenceDate == date }
                        let sets = store.numberSets(for: date)
                        let expanded = expandedDates.contains(date)
                        Button {
                            withAnimation {
                                if expanded { expandedDates.remove(date) }
                                else { expandedDates.insert(date) }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dateCards.contains(where: { $0.isJournal }) ? "한 줄 회고" : "이전 분석 기록").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.accent)
                                    Text(date).font(.headline)
                                }
                                Spacer()
                                if !dateCards.isEmpty {
                                    Text("답변 \(dateCards.count)개").font(.footnote).foregroundStyle(AppTheme.secondary)
                                }
                                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.footnote)
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.white.opacity(0.5))
                        .accessibilityIdentifier("chosen-day-\(date)")
                        .accessibilityValue(expanded ? "펼쳐짐" : "접힘")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                do {
                                    if !dateCards.isEmpty { try store.deleteReferenceDate(date) }
                                    reports.deleteReferenceDate(date)
                                    expandedDates.remove(date)
                                } catch { store.errorMessage = error.localizedDescription }
                            } label: { Label("삭제", systemImage: "trash") }
                        }
                        .id(date)

                        if expanded {
                            ForEach(dateCards.filter(\.isJournal)) { card in
                                cardRow(card)
                            }
                            ForEach(dateCards.filter { !$0.isJournal }) { card in
                                cardRow(card)
                            }
                            if !sets.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("이날의 번호 · \(sets.count)세트").font(.headline)
                                    ForEach(Array(sets.enumerated()), id: \.offset) { index, numbers in
                                        LottoNumberRow(numbers: numbers, theme: index)
                                            .frame(maxWidth: .infinity)
                                    }
                                    let numberText = sets.map { $0.map(String.init).joined(separator: ", ") }.joined(separator: "\n")
                                    ShareLink(item: "기준일: \(date)\n\(numberText)\n\n오락용 번호이며 당첨 확률을 높이지 않습니다.") {
                                        Label("번호 공유", systemImage: "square.and.arrow.up")
                                    }.buttonStyle(.borderless)
                                }.padding(.vertical, 6).listRowBackground(Color.white.opacity(0.5))
                            } else if let report = dateReports.first {
                                SavedNumberView(text: report.text).listRowBackground(Color.white.opacity(0.5))
                            }
                            ForEach(dateReports) { report in
                                let displayedNumbers = sets.isEmpty ? dateReports.first?.numberSets ?? [] : sets
                                reportRow(report, showNumbers: report.numberSets.isEmpty || report.numberSets != displayedNumbers)
                            }
                        }
                    }

                    let undatedCards = store.cards.filter { $0.referenceDate == nil }
                    let undatedReports = reports.reports.filter { $0.referenceDate == nil }
                    if !undatedCards.isEmpty || !undatedReports.isEmpty {
                        Section("기준일 없는 이전 기록") {
                            ForEach(undatedCards) { card in cardRow(card) }
                            ForEach(undatedReports) { report in reportRow(report, showNumbers: true) }
                        }
                    }
                }
                .task {
                    guard !didOpenTarget, let targetDate, dates.contains(targetDate) else { return }
                    expandedDates.insert(targetDate)
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo(targetDate, anchor: .top)
                    didOpenTarget = true
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(reflectionPaper.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .alert("기록 안내", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("확인") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
            }
        }
    }

    private func cardRow(_ card: ReflectionCard) -> some View {
        NavigationLink {
            ReflectionDetailView(store: store, original: card)
        } label: {
            let question = card.question.flatMap { $0.isEmpty ? nil : $0 } ?? card.displayTitle
            let title = Text(question).bold()
            Text("\(title) · \(card.text)")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }.listRowBackground(Color.white.opacity(0.5)).accessibilityIdentifier("reflection-card-\(card.id)")
    }

    private func reportRow(_ report: SavedReport, showNumbers: Bool) -> some View {
        NavigationLink {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(report.created, format: .dateTime.year().month().day())
                        .font(.footnote).foregroundStyle(AppTheme.secondary)
                    if let input = report.inputInfo { Text(input).textSelection(.enabled) }
                    if showNumbers { SavedNumberView(text: report.text) }
                    ShareLink(item: report.text + "\n\n오락용 번호이며 당첨 확률을 높이지 않습니다.") {
                        Label("번호 공유", systemImage: "square.and.arrow.up")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }.background(reflectionPaper).navigationTitle("저장 기록").navigationBarTitleDisplayMode(.inline)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.inputInfo == nil ? "저장한 번호" : "함께 저장한 출생 정보")
                Text(report.created, format: .dateTime.year().month().day().hour().minute())
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
            }
        }
        .listRowBackground(Color.white.opacity(0.5))
        .accessibilityIdentifier("catalog-report-\(report.id)")
        .swipeActions(allowsFullSwipe: false) {
            Button(role: .destructive) { reports.delete(report) } label: { Label("삭제", systemImage: "trash") }
        }
    }
}
