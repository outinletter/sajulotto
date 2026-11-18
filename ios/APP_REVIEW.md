# 주간픽(WeekPick) 1.0.0 심사 준비

새 번들 ID `com.addvalue.weekpick`로 새 앱 레코드를 만들어 제출한다. 이전 앱 레코드(`com.addvalue.sajulotto`)는 삭제됐다.
계정·로그인·결제·광고·서버 통신이 없다. 모든 데이터는 기기 안에만 저장된다.

## 메타데이터 초안

- 이름: WeekPick (한국어 표시 이름: 주간픽)
- 부제(30자 이내): 오늘의 기운으로 고르는 이번 주의 선택
- 카테고리: 라이프스타일
- 키워드(100자 이내): 선택,결정,메뉴,점심,룰렛,모임,회고,습관,주간,기록,오행
- 이름·부제·키워드에 운세, 점, 로또, 사주 풀이는 쓰지 않는다.
- 개인정보 처리방침·지원 URL: https://outinletter.github.io/privacy-policy/weekpick.html (앱 설정 화면이 같은 주소를 연결)
- 앱 프라이버시(영양 성분): 수집하는 데이터 없음 (서버 전송·SDK·광고·분석 없음)
- 심사 연락처: 공통 `APP_SUBMISSION_INFO.md`의 값을 사용한다.

## 앱 설명(요약)

주간픽은 일상의 작은 선택(점심 메뉴, 음료, 운동, 주말 계획, 모임 장소)을 도와주는 선택 도구다. 선택지 2~3개를 넣으면 앱이 각 선택지가 오늘의 기운과 얼마나 맞는지 점수(오행 일치도)로 보여 주고 하나를 골라 준다. 선택에 대한 만족도와 한 줄 회고를 남겨 이번 주의 선택을 돌아볼 수 있다. 부가 기능으로 한 주의 좋은 날 안내와 오락용 번호 한 세트(5줄)를 만들 수 있다. 번호는 오락용이며 당첨을 예측하거나 확률을 높이지 않는다.

## Notes for Review (영문 초안)

```
WeekPick is a personal decision helper for small everyday choices. There is no account, login, payment, advertising, analytics, or server communication; everything is stored on the device.

How to try it (no setup needed):
1. Open the app. On first launch you can skip the profile ("나중에 입력할게요"). Enter 19950512 as the solar birth date and tap "저장" to try the full experience.
2. "선택" tab (first tab): tap a preset chip such as "점심 메뉴" to fill two choices, then tap "오행 일치도 보기". The app animates a short reading and shows a match score for each option and the picked option. Rate the result afterwards, and use "함께" (decide together with 2-4 people; people's birth dates are not saved) or "순서" (random order for who pays).
3. "이번 주" tab: shows this week's best day with a short explanation. As a small extra, the user can generate one set of five entertainment number lines per week. It is not a core feature, involves no wagering, purchase, prizes, or links to any lottery operator, and states that it does not predict results or improve odds.
4. "기록" tab: one-line reflection per theme (Focus/Relationships/Rest), saved to a personal archive ("도감").
5. "설정": optional weekly local reminders (permission requested only when turned on), profile deletion, "앱 데이터 초기화", and the privacy policy.

Differences from other astrology/horoscope apps (Guideline 4.3(b)): the app does not publish horoscopes or fortune articles. Its purpose is to help users make and review everyday decisions: option-by-option match scores, a group decision flow for friends, post-choice feedback, weekly summary and reflection. The calculation uses an on-device birth-chart engine with published solar-term data; the astrology-style score is only one input to a lightweight decision tool.

Age rating: no gambling, no wagering, no real or simulated casino play, no user-generated content, no web access.
Regions: all features are the same in every region. The app works fully offline.
```

## 연령 등급 답변 (2.3.6)

- 도박: 도박·내기 요소 없음. 오락용 번호는 구매·배팅·상금과 무관 → "없음".
- 시뮬레이션 도박, 의료·치료 정보, 성적·폭력 콘텐츠, 욕설, 약물, 공포: 모두 없음.
- 사용자 생성 콘텐츠·공개 채팅·웹 접근·광고·인앱 구입: 없음.
- 결과를 사실대로 확인한 뒤 App Store Connect에 입력한다(이전 앱의 18+ 설정을 이어받지 않는다).

## 스크린샷 권장

선택 화면(측정 결과), 함께 정하기, 이번 주 화면(좋은 날 + 덤 번호), 기록 화면, 내 사주 자세히 보기. 번호 화면만 단독으로 쓰지 않는다.
