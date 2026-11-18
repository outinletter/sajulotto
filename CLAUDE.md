# 주간픽 (WeekPick)

## 개요·기술 스택
- 일상의 작은 선택을 오늘의 기운(오행 일치도)으로 돕는 선택 도구. 번호 생성은 "이번 주의 픽" 안의 오락용 덤 기능이며 앱의 핵심이 아니다.
- 순수 iOS 네이티브: SwiftUI, 최소 iOS 17(Liquid Glass는 26+에서 적용), UserDefaults·JSON 파일 저장. 서버·SDK·계정 없음.
- 번들 ID `com.addvalue.weekpick`, 표시 이름 주간픽, 개발 팀 A7QB8PT33N.

## 폴더 구조
- `ios/` 앱 소스. `SajuCore.swift` 사주 엔진(Foundation 전용), `SolarTermsData.swift` 절기 표, `SajuDecision.swift` 선택·이번 주·프로필·온보딩 UI, `ReflectionViews/Models.swift` 기록·도감, `SajuLottoApp.swift` 앱·탭·설정.
- `scripts/` 엔진 검증, 아이콘 생성(`GenerateWeekPickIcon.swift`). `vendor/`, `ios/Web/`은 개발용 JS 기준 엔진 잔재(앱에 포함되지 않음).

## 규칙
- 오프라인 우선, 외부 API·SDK·광고·분석 금지. 번호는 오락용이며 당첨 예측·확률 향상 표현 금지.
- 앱 이름·키워드에 운세·점·로또·사주 풀이 금지(4.3(b) 이력). 번호 생성을 핵심 기능으로 설명하지 않는다.
- 시뮬레이터가 작동하지 않으니 실기기에 설치해 확인한다.

## 명령어·현재 상태
- 스킴 `SajuLotto`. 기기 빌드: `xcodebuild -project ios/SajuLotto.xcodeproj -scheme SajuLotto -destination 'id=<기기ID>' -allowProvisioningUpdates build`.
- 엔진 검증: `swiftc -parse-as-library ios/SajuCore.swift ios/SolarTermsData.swift scripts/SajuEngineChecks.swift -o /tmp/SajuEngineChecks && /tmp/SajuEngineChecks`.
- 처리방침·지원 URL: https://outinletter.github.io/privacy-policy/weekpick.html (앱 설정이 같은 주소 연결). 카테고리 라이프스타일.
- 상태: 새 앱 레코드 생성 전. 심사 노트·메타데이터 초안은 `ios/APP_REVIEW.md`. 연령 등급은 사실대로 새로 답변. 커밋 안 됨.
