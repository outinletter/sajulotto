# 아이콘 경로 수정 및 딥시크 AI 기반 사주 풀이 고도화

이 계획은 `sajulottoicon.png` 아이콘이 사용되지 않는 문제를 해결하고, 기존의 정적인 사주 풀이를 딥시크(DeepSeek) AI를 활용하여 더욱 상세하고 전문적인 분석으로 개선하는 것을 목표로 합니다.

## 제안된 변경 사항

### [Android App Assets]

#### [MODIFY] [index.html](file:///D:/Data/Project/SajuLotto/app/src/main/assets/index.html)
- `https://raw.githubusercontent.com/...`로 설정된 아이콘 경로를 로컬 에셋 경로인 `icons/sajulottoicon.png`로 수정합니다.
- `performAIAnalysis` 함수에서 사용하는 딥시크 AI 프롬프트를 보강하여 더욱 상세한 사주 분석(성격, 재물운, 직업운, 행운의 조언 등)을 요청하도록 수정합니다.
- UI 상에서 AI 분석 결과가 더 돋보이도록 디자인을 개선하고, 기존의 정적 분석 결과보다 상단에 배치하거나 "상세 분석" 섹션으로 강조합니다.

### [Android App Logic]

#### [MODIFY] [MainActivity.kt](file:///D:/Data/Project/SajuLotto/app/src/main/java/com/addvalue/sajulotto/MainActivity.kt)
- `SajuBridge`에서 AI 결과를 자바스크립트로 전달할 때 발생할 수 있는 이스케이프 문제를 방지하기 위해 처리를 강화합니다. (필요 시)

## 검증 계획

### 수동 검증
- 앱 실행 시 상단 로고 아이콘이 정상적으로 표시되는지 확인합니다.
- 사주 분석 결과 화면에서 딥시크 AI가 생성한 상세한 사주 풀이가 표시되는지 확인합니다.
- `local.properties`에 `WORKER_URL`과 `DEEPSEEK_API_KEY`가 올바르게 설정되어 있는지 확인합니다.
