# 이관 부채 / 반복 점검 항목 (Deferred Issues)

Stage 1 완료 판정에 직접 영향 없는 항목들의 보관소. 각 Stage 종료 시점에 이 파일 전체를 훑고, 해당 Stage에서 해결된 것은 제거하고, 재평가 시점이 도래한 것은 결정 기록 후 이관/해결/연기한다.

## 제품 방향

### 커플 2차 타깃 검증
- 맥락: 스펙 원문의 2차 타깃(커플, "한 명이 늘 편집 맡는 문제"). 1차 타깃(친구 2인) 플로우가 안 돌면 2차도 안 돌기 때문에 Stage 6 이전 검증은 자원 분산.
- 재평가 시점: Stage 6 TestFlight 베타 1회차 피드백 수집 이후.
- 결과 후보: (a) 1차 플로우 그대로 진행 (b) 커플 맥락 전용 추가 기능 설계 (c) 타깃 전환.

### 포지셔닝 축 유효성 ("편집 귀찮음")
- 맥락: 스펙 원문 주장만 있고 사용자 인터뷰 근거 없음.
- 관찰: Stage 3(세션 생성 UI 완성) 시점에 친구 2인 비공식 질적 인터뷰 1~2회. 결과물 없이 흐름만 설명, NDA 불필요.
- 롤백 기준: "왜 필요한지 모르겠다"가 2/2면 Stage 5 진입 전 포지셔닝 카피 재검토 → PO 에스컬레이션.

## 시장 모니터링 (반복)

### 경쟁사(CapCut / VLLO) 2인 공동 편집 기능 점검
- 맥락: 경쟁사가 "공동 편집"을 Stage 5 도달 전 출시하면 UsCut 포지셔닝 축 희석 위험.
- 점검 주기: Stage 2 / Stage 4 완료 시점에 릴리스 노트 각 10분 점검.
- 트리거: 공동 편집 기능 출시 확인 시 "2인 비대칭 편집 해방" → "친구 2인 1탭 릴스 자동 생성" 자동화 축 이동 검토. PO 에스컬레이션.

## 기술 부채

### 피어 리뷰 Important 이슈 목록 보강
- 맥락: 2026-04-22 Stage 1 스캐폴드 피어 리뷰에서 Important 레벨 이슈들이 제기되고 일부만 반영. 보류된 구체 목록이 현재 문서에 명시되지 않음.
- 재평가 시점: Stage 6 안정화 구간.
- 액션: 원 리뷰 산출물을 다시 읽고 Stage 1 영향 없는 Important 이슈를 이 파일 아래 절에 수록.

### 1회성 스크립트 `ios/add_render_module.rb` 정리
- 맥락: `flutter create`가 `ios/Runner/Render/*.swift` 9개를 Xcode 프로젝트에 자동 등록하지 않아 Ruby 스크립트로 추가했음. 재사용성 불확실.
- 재평가 시점: Stage 2 착수 시점. Stage 2에서 새 Swift 파일이 추가된다면 재사용 가능성이 증명됨.
- 현재 상태: untracked, 커밋 범위 제외.
- 액션 후보:
  - (a) `dev-tools/` 디렉토리로 이동 + README 추가 후 커밋
  - (b) `.gitignore`에 추가 (개인 환경 산출물로 간주)
  - (c) 삭제

### AVAssetExportSession 오디오 트랙 부재 export 실패 가능성 (Stage 1 피어 리뷰 #3)
- 맥락: 오디오 트랙 없는 composition을 export할 때 일부 디바이스/iOS 빌드에서 `AVFoundationErrorDomain -11800` 보고 사례.
- 재평가 시점: Stage 1 시각 게이트 실기기 검증 중. 게이트 통과 시 자동 해소로 간주, 실패 시 원인 후보 1번으로 조사.
- 롤백: 재현 시 무음 오디오 트랙 1줄 추가.

### `_runRender` IO + 비즈니스 로직 혼재 (Stage 1 피어 리뷰 #5)
- 맥락: `lib/screens/preview_screen.dart`의 `_runRender`가 tmp 디렉토리 조회·MethodChannel 호출·비디오 컨트롤러 초기화를 한 함수에 혼재. 글로벌 엔지니어링 룰("IO와 비즈니스 로직 분리") 위반.
- 재평가 시점: Stage 5 협업 렌더 진입 전. 렌더 경로가 로컬 파일/원격 다운로드 두 갈래로 분기하므로 그때 분리가 자연스러움.
- 액션: `RenderController` 또는 Riverpod provider로 분리.

### `_cleanupOldOutputs` 동기 IO (Stage 1 피어 리뷰 #6)
- 맥락: `lib/services/render_service.dart`의 `_cleanupOldOutputs`가 `listSync`/동기 IO. 렌더 시작 경로에서 메인 isolate 순간 블록.
- 재평가 시점: Stage 6 안정화 구간.
- 액션: `Directory.list()` async 전환.

### `AVAssetExportSession` Profile build configuration 경고
- 맥락: `pod install` 후 "CocoaPods did not set the base configuration of your project because your project already has a custom config set" 경고. Runner Profile 빌드 config가 `Pods-Runner.profile.xcconfig`를 참조하지 않음.
- 재평가 시점: Stage 6 TestFlight 빌드 준비 시점. Profile 구성이 Release/Debug와 다른 플래그를 가져야 하는지 그때 판단.
- 액션: pbxproj에서 Runner Profile config의 `baseConfigurationReference`를 새 `Profile.xcconfig`로 변경.

## 회고 시 확인할 것

각 Stage 종료 시 이 파일 전체를 훑고:
- 해당 Stage에서 해결된 것 → 제거
- 재평가 시점이 도래한 것 → 결정 기록 후 이관/해결/연기
- 새로 발견된 부채 → 같은 포맷으로 추가
