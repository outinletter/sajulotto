# 천기누설 iOS

iOS 17 이상, iPhone용 SwiftUI 앱입니다. `SajuLotto.xcodeproj`의 공유 스킴 `SajuLotto`로 빌드합니다.

번들 ID: `com.addvalue.sajulotto`, 개발 팀: `A7QB8PT33N`. 자동 서명을 사용합니다.

`Web/`은 루트 HTML과 로컬 vendor 파일의 앱 번들 사본입니다. 웹 화면 변경 시 함께 갱신하세요. 기본 분석은 네트워크 연결 없이 기기에서 계산합니다. AI 해석은 매 요청마다 사용자의 동의를 받아 계산된 사주 정보만 HTTPS 프록시로 보냅니다. `Info.plist`의 `DeepSeekProxyURL`에 Cloudflare Worker 공개 주소를 설정하세요. API 키는 서버 환경변수에만 보관합니다. 저장한 번호만 UserDefaults에 보관하고 네이티브 공유 기능을 제공합니다.
