import SwiftUI

private let reflectionPaper = Color(red: 0.97, green: 0.95, blue: 0.91)
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

struct ReflectionHomeView: View {
    @ObservedObject var store: ReflectionStore
    @State private var composing: ReflectionTopic?
    @State private var path: [UUID] = []
    private var weekCards: [ReflectionCard] { store.cards.filter { $0.weekID == ReflectionStore.weekID(for: Date()) }.reversed() }
    private var completed: Int { weekCards.count }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A MOMENT, A LITTLE LIGHT").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                        Text("이번 주의\n여섯 장면").font(.system(size: 38, weight: .bold, design: .serif))
                        Text("좋았던 일도, 아쉬웠던 일도.\n한 줄을 남기면 나만의 번호 카드가 완성돼요.")
                            .font(.subheadline).foregroundStyle(.secondary).lineSpacing(5)
                    }
                    ReflectionAccumulatedView(cards: weekCards) { card in path.append(card.id) }
                        .id("reflection-results")
                    HStack {
                        Label("이번 주의 조각", systemImage: "square.grid.2x2")
                        Spacer()
                        Text("\(completed) / 5").monospacedDigit()
                    }.font(.subheadline.weight(.medium))
                    VStack(spacing: 12) {
                        ForEach(ReflectionTopic.allCases) { topic in
                            VStack(spacing: 0) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        composing = composing == topic ? nil : topic
                                        if composing == topic { proxy.scrollTo("reflection-topic-" + topic.rawValue, anchor: .top) }
                                    }
                                } label: {
                                    ReflectionTopicRow(topic: topic, completed: store.card(for: topic) != nil, expanded: composing == topic)
                                }
                                .buttonStyle(.plain).id("reflection-topic-" + topic.rawValue).accessibilityIdentifier("reflection-topic-\(topic.rawValue)")
                                .accessibilityValue(composing == topic ? "펼쳐짐" : "접힘")
                                if composing == topic {
                                    ReflectionEditor(store: store, topic: topic, existing: store.card(for: topic), inline: true,
                                        onCancel: { withAnimation { composing = nil } }) { _ in
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                composing = nil
                                                proxy.scrollTo("reflection-results", anchor: .top)
                                            }
                                        }
                                        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("마음을 평가하지 않아요", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                        Text("한 가지만 써도 충분해요. 어떤 감정이든 같은 방식으로 번호를 만들어요. 기록은 기기에 보관하며 AI로 보내지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
                        Text("번호는 1~45 중 6개를 무작위로 선택합니다. 사주·감정·글의 길이는 당첨 확률에 영향을 주지 않습니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding(18).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                }.padding(22)
            }
            }
            .background(reflectionPaper).navigationTitle("한 줄 회고").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let card = store.cards.first(where: { $0.id == id }) { ReflectionDetailView(store: store, original: card) }
            }
            .alert("기록 안내", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("확인") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }
}

private struct ReflectionAccumulatedView: View {
    let cards: [ReflectionCard]
    let onOpen: (ReflectionCard) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("이번 주 모은 번호", systemImage: "circle.grid.2x3.fill").font(.headline)
                Spacer()
                Text("\(cards.count)세트").font(.caption).foregroundStyle(.secondary)
            }
            if cards.isEmpty {
                Text("아래 카드에 한 줄을 남기면 번호가 한 세트씩 쌓여요.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                Button { onOpen(card) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(card.topic.title).font(.caption.weight(.medium)); Spacer(); Image(systemName: "chevron.right").font(.caption2) }
                            .foregroundStyle(card.mood.color)
                        HStack(spacing: 5) {
                            ForEach(card.numbers, id: \.self) { number in
                                Text(String(format: "%02d", number)).font(.system(.body, design: .rounded).bold())
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(card.mood.color.opacity(0.12), in: Circle())
                                    .overlay(Circle().stroke(card.mood.color.opacity(0.25)))
                            }
                        }.foregroundStyle(.primary)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("reflection-result-\(card.topic.rawValue)")
                    .accessibilityLabel(card.topic.title + " · " + card.numberText)
            }
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct ReflectionTopicRow: View {
    let topic: ReflectionTopic
    let completed: Bool
    var expanded = false
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: topic.symbol).font(.title2).foregroundStyle(.brown)
                .frame(width: 48, height: 54).background(reflectionPaper, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text(topic.title).font(.headline).foregroundStyle(.primary)
                Text(completed ? "이번 주 카드가 완성됐어요 · 수정하기" : topic.question)
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
            Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(.brown)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct ReflectionEditor: View {
    @ObservedObject var store: ReflectionStore
    let topic: ReflectionTopic
    let existing: ReflectionCard?
    let inline: Bool
    let onCancel: (() -> Void)?
    let onSaved: (ReflectionCard) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var mood: ReflectionMood
    @State private var strokes: [ReflectionStroke]
    @State private var active: [ReflectionPoint] = []
    @State private var error: String?
    @State private var saving = false
    @FocusState private var textFocused: Bool
    init(store: ReflectionStore, topic: ReflectionTopic, existing: ReflectionCard? = nil, inline: Bool = false, onCancel: (() -> Void)? = nil, onSaved: @escaping (ReflectionCard) -> Void) {
        self.store = store; self.topic = topic; self.existing = existing; self.inline = inline; self.onCancel = onCancel; self.onSaved = onSaved
        _text = State(initialValue: existing?.text ?? "")
        _mood = State(initialValue: existing?.mood ?? .warm)
        _strokes = State(initialValue: existing?.strokes ?? [])
    }
    private var fields: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(topic.question).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                Text("01  지금의 마음 색").font(.subheadline.weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ReflectionMood.allCases) { item in
                            Button { mood = item } label: {
                                VStack(spacing: 7) {
                                    Circle().fill(item.color).frame(width: 36, height: 36)
                                        .overlay { if mood == item { Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) } }
                                    Text(item.title).font(.caption).foregroundStyle(.primary)
                                }.padding(8)
                            }.accessibilityLabel(item.title).accessibilityIdentifier("reflection-mood-\(item.rawValue)")
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("02  나에게 남기는 한 줄").font(.subheadline.weight(.semibold)); Spacer(); Text("\(text.count)/500").font(.caption).foregroundStyle(text.count > 500 ? .red : .secondary) }
                TextField("예: 바쁜 하루에도 잠깐 산책을 했다", text: $text, axis: .vertical)
                    .lineLimit(3...6).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .focused($textFocused).accessibilityIdentifier("reflection-text")
                Text("잘 쓸 필요 없어요. 다른 사람의 실명이나 연락처는 적지 않아도 됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("03  한 획으로 마무리 · 선택").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("지우기") { strokes = []; active = [] }.font(.caption)
                }
                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.8))
                        if strokes.isEmpty && active.isEmpty { Text("손가락으로 오늘의 흔적을 남겨요").font(.caption).foregroundStyle(.secondary) }
                        ReflectionInk(strokes: strokes + (active.isEmpty ? [] : [ReflectionStroke(points: active)]), color: mood.color)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard strokes.count < 64, active.count < 256 else { return }
                            active.append(ReflectionPoint(x: min(1, max(0, value.location.x / max(1, geometry.size.width))), y: min(1, max(0, value.location.y / max(1, geometry.size.height)))))
                        }
                        .onEnded { _ in
                            if !active.isEmpty { strokes.append(ReflectionStroke(points: active)); active = [] }
                        })
                    .accessibilityLabel("오늘의 손그림, 선택 항목").accessibilityIdentifier("reflection-ink")
                }.frame(height: 130)
            }
            Text(existing == nil ? "한 주에 주제별 카드 한 장을 만들어요. 번호는 기기에서 무작위로 생성되며, 다시 보거나 글을 고쳐도 유지됩니다." : "글과 색을 수정해도 기존 번호와 카드는 유지됩니다.")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
            Button {
                guard !saving else { return }; saving = true
                do {
                    let card = try store.save(topic: topic, mood: mood, text: text, strokes: strokes, editing: existing?.id)
                    textFocused = false
                    if !inline { dismiss() }; onSaved(card)
                } catch { self.error = error.localizedDescription; saving = false }
            } label: {
                Label(existing == nil ? "나의 카드 완성하기" : "기록 수정 저장", systemImage: "sparkles")
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
                Button("입력창 닫기") { textFocused = false; onCancel?() }.font(.caption).padding(.bottom, 18)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Text("이번 주의 여섯 장면").font(.caption.weight(.medium)); Spacer(); Image(systemName: card.topic.symbol) }
                .foregroundStyle(card.mood.color)
            Text(card.topic.title).font(.system(.title, design: .serif).bold())
            Text(card.dateText)
                .font(.caption).foregroundStyle(.secondary)
            if includeBody { Text(card.text).font(.body).lineSpacing(6).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("reflection-body") }
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(card.mood.color.opacity(0.07))
                Image(systemName: card.topic.symbol).font(.system(size: 62, weight: .ultraLight)).foregroundStyle(card.mood.color.opacity(0.2))
                ReflectionInk(strokes: card.strokes, color: card.mood.color)
            }.frame(height: 120)
            Text(card.topic.affirmation).font(.subheadline.weight(.medium)).foregroundStyle(card.mood.color)
            HStack(spacing: 5) {
                ForEach(Array(card.numbers.enumerated()), id: \.offset) { index, number in
                    Text(revealed ? String(format: "%02d", number) : "·")
                        .font(.system(.body, design: .rounded).bold()).minimumScaleFactor(0.6).lineLimit(1)
                        .frame(maxWidth: .infinity).frame(height: 43)
                        .background(card.mood.color.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(card.mood.color.opacity(0.25)))
                        .scaleEffect(revealed ? 1 : 0.6)
                        .animation(.spring(response: 0.45).delay(Double(index) * 0.09), value: revealed)
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel(card.numberText).accessibilityIdentifier("reflection-numbers")
            Text("오락용 무작위 조합 · 당첨 확률을 높이지 않습니다.").font(.caption2).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
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
                ReflectionArtwork(card: card, revealed: revealed)
                Button("흔적 다시 보기", systemImage: "arrow.clockwise") {
                    revealed = false
                    Task { try? await Task.sleep(for: .milliseconds(150)); revealed = true }
                }.font(.subheadline).accessibilityIdentifier("reflection-replay")
                Button { sharing = card } label: { Label("카드 공유", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(12) }
                    .buttonStyle(.borderedProminent).tint(card.mood.color).accessibilityIdentifier("reflection-share")
                Text("공유 미리보기에서 본문을 숨길 수 있어요. 기본값은 본문 숨김입니다.").font(.caption).foregroundStyle(.secondary)
                Button("이 카드 삭제", role: .destructive) { deleting = true }.font(.caption).padding(.top, 14)
            }.padding(20)
        }.background(reflectionPaper).navigationTitle("나의 한 장면").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("수정") { editing = card }.accessibilityIdentifier("reflection-edit") }
            .task { revealed = true }
            .sheet(item: $editing) { card in ReflectionEditor(store: store, topic: card.topic, existing: card) { _ in } }
            .sheet(item: $sharing) { card in ReflectionShareView(card: card) }
            .confirmationDialog("기록과 번호 카드를 삭제할까요?", isPresented: $deleting, titleVisibility: .visible) {
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
                    Text("손그림은 카드에 포함됩니다. 이름이나 사적인 내용을 그렸다면 공유 전 확인하세요.").font(.caption).foregroundStyle(.secondary)
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
    private var weeks: [String] { Array(Set(store.cards.map(\.weekID))).sorted(by: >) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("내가 남긴 시간들").font(.largeTitle.bold())
                    Text("다섯 가지 질문에 남긴 이야기와 여섯 숫자.\n서두르지 않고 모아 가는 나만의 도감입니다.").font(.subheadline).foregroundStyle(.secondary)
                    if store.cards.isEmpty {
                        ContentUnavailableView("첫 장면을 기다리고 있어요", systemImage: "book.closed", description: Text("회고 탭에서 한 줄을 남겨보세요."))
                    }
                    ForEach(weeks, id: \.self) { week in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(week) 시작 주 · 한국 시간").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(store.cards.filter { $0.weekID == week }) { card in
                                NavigationLink { ReflectionDetailView(store: store, original: card) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: card.topic.symbol).font(.title2).foregroundStyle(card.mood.color)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(card.topic.title).font(.headline)
                                            Text("\(card.mood.title) 마음 · \(card.numberText)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                                    }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
                                }.buttonStyle(.plain).accessibilityIdentifier("reflection-card-\(card.id)")
                            }
                        }
                    }
                }.padding(22)
            }.background(reflectionPaper).navigationTitle("주간 도감").navigationBarTitleDisplayMode(.inline)
        }
    }
}
