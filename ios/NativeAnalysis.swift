import SwiftUI

struct LottoNumberSequence: View {
    let sets: [[Int]]
    @State private var revealed: [Int] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, numbers in
                AppCard(verticalPadding: 10) {
                    LottoNumberRow(numbers: numbers, theme: index, revealedCount: revealed.indices.contains(index) ? revealed[index] : 0)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("number-set-\(index)")
                }
            }
        }
        .task(id: sets) {
            revealed = Array(repeating: 0, count: sets.count)
            for index in sets.indices {
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.15)) { revealed[index] = sets[index].count }
                    do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                } else {
                    for ball in sets[index].indices {
                        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { revealed[index] = ball + 1 }
                    }
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                }
            }
            if !reduceMotion && !Task.isCancelled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }
}

extension View {
    /// iOS 26+ Liquid Glass, 이전 버전은 머티리얼로 대체
    @ViewBuilder func appGlass<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? .regular, in: shape)
        } else {
            self.background(tint ?? Color.clear, in: shape).background(.ultraThinMaterial, in: shape)
        }
    }
}

struct AppCard<Content: View>: View {
    var verticalPadding: CGFloat = 16
    @ViewBuilder let content: Content
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, verticalPadding)
            .appGlass(RoundedRectangle(cornerRadius: 22))
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52).padding(.horizontal, 16)
            .background(enabled ? AppTheme.accent : AppTheme.accent.opacity(0.35), in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}


struct PrivacyPolicyView: View {
    static let webURL = URL(string: "https://outinletter.github.io/privacy-policy/weekpick.html")!
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("주간픽 개인정보 처리방침").font(.title2.bold())
                Text("2026년 11월 18일부터 적용 · 운영자: BS Jeon")
                Text("기기 내 저장").font(.headline).padding(.top, 8)
                Text("생년월일, 선택 입력한 태어난 시간·성별·출생지, 선택한 항목과 결과 기록, 이번 주 번호, 한 줄 회고와 설정은 이 기기에만 저장합니다. 계정이나 로그인은 필요하지 않으며 정보를 운영자 서버로 전송하지 않습니다. 광고, 분석, 추적, 서드파티 SDK를 사용하지 않습니다. 기기에 저장된 정보는 운영체제(iCloud) 백업에 포함될 수 있습니다.")
                Text("함께 정하기").font(.headline).padding(.top, 8)
                Text("다른 사람의 이름과 생년월일은 계산에만 사용하고 저장하지 않습니다. 입력 전에 해당 사람의 동의를 받아 주세요.")
                Text("알림").font(.headline).padding(.top, 8)
                Text("설정에서 주간 알림을 켠 경우에만 알림 권한을 요청하며, 기기에 예약되는 로컬 알림(일요일 오전 9시, 토요일 오후 4시 35분)만 사용합니다. 언제든 끌 수 있습니다.")
                Text("공유").font(.headline).padding(.top, 8)
                Text("번호, 선택 결과, 회고 카드는 사용자가 공유 버튼을 눌렀을 때 선택한 앱으로만 전달됩니다.")
                Text("삭제").font(.headline).padding(.top, 8)
                Text("설정의 내 사주 정보에서 저장한 정보를 삭제하거나 앱 데이터 초기화로 모든 기록을 지울 수 있습니다. 앱을 삭제하면 기기 내 정보도 삭제됩니다.")
                Text("문의").font(.headline).padding(.top, 8)
                Text("지원과 개인정보 관련 문의는 아래 웹 페이지의 이메일로 연락해 주세요.")
                Link("처리방침·지원 웹 페이지", destination: Self.webURL)
            }.padding().frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
        }.background(AppTheme.paper).navigationTitle("개인정보 처리방침").navigationBarTitleDisplayMode(.inline).textSelection(.enabled)
    }
}
