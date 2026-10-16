# 천기누설 iOS

iOS 17 이상, iPhone용 SwiftUI 앱입니다. `SajuLotto.xcodeproj`의 공유 스킴 `SajuLotto`로 빌드합니다.

번들 ID: `com.addvalue.sajulotto`, 개발 팀: `A7QB8PT33N`. 자동 서명을 사용합니다.

`Web/`은 루트 HTML과 로컬 vendor 파일의 앱 번들 사본입니다. 웹 화면 변경 시 함께 갱신하세요. 기본 분석은 네트워크 연결 없이 기기에서 계산합니다. AI 해석은 새 요청마다 사용자의 동의를 받아 계산된 사주 정보만 HTTPS 프록시로 보냅니다. `Info.plist`의 `DeepSeekProxyURL`에 Cloudflare Worker 공개 주소를 설정하세요. API 키는 서버 환경변수에만 보관합니다. 직접 저장한 입력 정보와 번호는 UserDefaults에 보관하고 네이티브 공유 기능을 제공합니다.

첫 화면은 ‘한 줄 회고’이며 ‘도감’에서 한국 시간 일요일 시작 주별 카드를 확인합니다. 한 주에 주제별 한 장을 생성하고 수정·재열기로 번호를 바꾸지 않습니다. 번호는 SystemRandomNumberGenerator로 1~45 중 중복 없이 6개를 균등 추출합니다. 회고 본문·손그림은 Application Support/Reflection/weekly-cards.json에 파일 보호·원자적 쓰기로 저장하며 AI 요청과 연결하지 않습니다. 공유 이미지는 본문 숨김이 기본값이며 손그림은 포함됩니다. 기존 사주 분석·번호 기록은 해당 탭에 보존합니다.

모델 검증: `swiftc -parse-as-library ios/ReflectionModels.swift scripts/ReflectionModelChecks.swift -o /tmp/ReflectionModelChecks && /tmp/ReflectionModelChecks`. UI 검증: `testReflectionLifecycleAndPrivateSharing`. DEBUG UI 테스트는 UUID별 캐시 저장소를 사용해 실제 사용자의 회고를 수정하지 않습니다.
