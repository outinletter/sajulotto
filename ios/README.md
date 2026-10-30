# 천기누설 iOS

iOS 17 이상, iPhone용 SwiftUI 앱입니다. `SajuLotto.xcodeproj`의 공유 스킴 `SajuLotto`로 빌드합니다.

번들 ID: `com.addvalue.sajulotto`, 개발 팀: `A7QB8PT33N`. 자동 서명을 사용합니다.

분석 UI는 `NativeAnalysis.swift`의 SwiftUI Form이며 WKWebView를 사용하지 않습니다. `Web/vendor/`의 기존 절기 데이터와 순수 계산 함수를 JavaScriptCore에서 오프라인 실행합니다. `scripts/build-native-engine.cjs`로 웹의 공통 계산 함수를 추출해 `native-engine.js`를 갱신합니다. 웹 화면은 iOS 화면에 로드하지 않습니다. 한국 출생·양력 1900~2027년만 지원하며 시각 미상은 시주를 산출하지 않습니다. 주간 지표는 자체 오락용 비교 규칙입니다. 번호는 사주와 독립적인 SystemRandomNumberGenerator로 생성합니다. 기본 분석은 네트워크 연결 없이 기기에서 계산합니다. AI 해석은 새 요청마다 사용자의 동의를 받아 계산된 사주 정보만 HTTPS 프록시로 보냅니다. `Info.plist`의 `DeepSeekProxyURL`에 Cloudflare Worker 공개 주소를 설정하세요. API 키는 서버 환경변수에만 보관합니다. 직접 저장한 입력 정보와 번호는 UserDefaults에 보관하고 네이티브 공유 기능을 제공합니다.

첫 화면은 ‘한 줄 회고’이며 ‘도감’에서 한국 시간 일요일 시작 주별 카드를 확인합니다. 주제를 누르면 카드 아래에 글·마음 색 입력창이 펼쳐지고, 완료하면 상단에 번호 한 세트씩 누적됩니다. 한 주에 주제별 한 장을 생성하고 수정·재열기로 번호를 바꾸지 않습니다. 번호는 SystemRandomNumberGenerator로 1~45 중 중복 없이 6개를 균등 추출합니다. 회고 본문·기존 손그림은 Application Support/Reflection/weekly-cards.json에 파일 보호·원자적 쓰기로 저장하며 AI 요청과 연결하지 않습니다. 공유 이미지는 본문 숨김이 기본값이며 손그림은 포함됩니다. 기존 사주 분석·번호 기록은 해당 탭에 보존합니다.

모델 검증: `swiftc -parse-as-library ios/ReflectionModels.swift scripts/ReflectionModelChecks.swift -o /tmp/ReflectionModelChecks && /tmp/ReflectionModelChecks`. UI 검증: `testReflectionLifecycleAndPrivateSharing`. DEBUG UI 테스트는 UUID별 캐시 저장소를 사용해 실제 사용자의 회고를 수정하지 않습니다.


네이티브 계산 검증: `swift scripts/NativeEngineChecks.swift`. 입춘 경계, 시각 미상, 자정·경도 보정, 한국 시간 주간 구간, 오행 개수와 지원 연도를 검사합니다. 네이티브 UI 테스트는 `testNativeAnalysisSavedNumbersAndConsent`, `testPrivacyPolicyAvailableOffline`입니다. 네트워크 호출 없이 생성·저장·AI 동의 취소·새 분석·개인정보 화면을 검증합니다. DEBUG 테스트 저장소는 실사용 기록과 분리합니다.

앱 심사 준비 내용과 제출 전 확인 사항은 `APP_REVIEW.md`를 참고하세요. 버전 1.0.0(10).
