# 천기누설 1.0.0(10) 심사 준비

2026-10-31 저장된 Apple App Review Guidelines 및 Apple 공식 최신 지침을 검토했습니다.
https://developer.apple.com/app-store/review/guidelines/

## 제품과 심사 대응
- 첫 화면의 한 줄 회고, 마음 색, 주간 도감, 기존 카드 수정·삭제와 비공개 기본 공유가 지속 사용을 위한 핵심 기능입니다. 계정 없이 오프라인으로 이용합니다.
- 사주 분석도 SwiftUI 입력·원국·오행·주간 비교·번호·계산 근거 화면으로 구성했습니다. 웹뷰를 사용하지 않으며 번들에 포함된 검증된 천문 데이터와 순수 계산식을 JavaScriptCore로 실행합니다(4.2).
- 운세는 포화 범주(4.3(b))입니다. 회고와 도감이라는 실제 기능을 설명하되 차별성의 최종 인정은 Apple 심사에 달려 있습니다. UI 전환이나 면책문구만으로 통과를 보장하지 않습니다.
- 번호는 사주 입력과 독립적인 기기 난수입니다. 당첨 확률 향상·수익 예측·구매 유도 표현을 네이티브 화면에 사용하지 않습니다(1.1.6, 2.3).
- 복권 판매·베팅·현금·경품·유료 크레딧 기능이 없습니다. 실제 복권을 운영하는 앱으로 설명하지 않습니다(5.3).
- 회고 제목은 한 줄의 동적 글꼴로 표시하고 중복 장식과 상단 여백을 줄였습니다. 화면 배경·강조색·보조 글자색을 공통 테마로 맞추고 기본 화면 제목은 인라인으로 통일했습니다. AI 동의는 제공업체 정책 링크·명시적 취소·승인 버튼이 있는 독립 화면입니다.
- 앱 내 개인정보 처리방침 및 개발자 문의, 저장 기록·회고 삭제, AI 요청 취소와 메모리 결과 삭제 기능을 제공합니다(1.5, 5.1.1).
- AI 요청 직전 Cloudflare·DeepSeek와 전송 항목을 알리고 명시적 동의를 받습니다. 원문 이름·생년월일·정확한 시각·지역·경도값·회고는 전송하지 않습니다. 파생 사주 값은 생년 정보와 관련될 수 있으므로 익명 데이터라고 단정하지 않습니다(5.1.2).

## Review Notes 초안
This app combines private weekly reflection cards and a collection with an optional traditional Korean Four Pillars reference. Reflection text and previously saved drawings remain on device. Card sharing hides the reflection body by default. The Analysis tab is native SwiftUI and calculates offline using bundled solar-term data; no website is loaded. Enter a Gregorian birth date (1900–2027, Korean time), optionally select an exact birth time and region, and tap “분석 및 번호 생성”. Results include pillars, visible element counts, an explicitly recreational weekly comparison, independently randomized number sets, and calculation sources/limitations. No login is required. There is no lottery sale, wagering, paid credit, prize or real-money gaming. Numbers do not improve winning odds. Optional AI commentary requires explicit consent naming Cloudflare and DeepSeek before transmitting approved derived chart data. Declining consent keeps all local functions available. Privacy policy and developer support are in the Info tab (“안내”).

## App Store Connect 제출 전 필수 확인
- 앱 개인정보 URL은 공개 접근 가능한 실제 개인정보 페이지로 설정해야 합니다. 저장소의 privacy.html은 파일이며 웹 게시를 대신하지 않습니다. 이번 작업에서는 공개 정책 사이트 배포나 App Store 심사 제출을 수행하지 않습니다.
- 지원 URL https://github.com/outinletter/sajulotto/issues 의 공개 접근·문의 수신 가능 여부를 운영자가 확인해야 합니다.
- App Privacy 답변은 Cloudflare/DeepSeek의 실제 IP 로그·보관·학습 설정까지 확인하여 작성해야 합니다. 앱의 개인정보 매니페스트만으로 App Store 답변이 대체되지 않습니다. 제공업체의 동등한 정보 보호(5.1.1(i)) 및 삭제 요청 처리 경로를 확인해야 합니다.
- 실제 기능에 맞게 연령 등급의 운세·모의 도박 관련 질문에 정확히 답하고, 메타데이터·스크린샷에 당첨 예측·확률 향상 표현을 사용하지 마세요.
- 연결된 개발용 아이폰 설치와 App Store 배포용 Archive/업로드·심사는 별도입니다. Archive 서명과 App Store Connect 검증 후 제출해야 합니다.
