# Stage 1 — 남은 작업 (Remaining)

이 문서는 Stage 1 **완료 판정**(스캐폴드 완료 → 실기기 검증 게이트 통과)까지 남은 작업만 추적한다. Stage 1 종료 시 이 파일은 삭제되고, 판정 결과는 git history + `roadmap.md`로 흡수된다.

## 현재 상태 (2026-04-23)

**Stage 1 스캐폴드 완료, 검증 게이트 미통과.**

완료된 것:
- Flutter 3.41.7 + Dart 3.11.5 + iOS 16 타겟 프로젝트 부트스트랩
- `lib/` 전체: models, edit/alternating_rule, services/render_service, screens 3개
- `ios/Runner/Render/` 9개 Swift 파일 (AVFoundation 렌더 모듈)
- MethodChannel `com.uscut/render` (renderAlternating)
- 편집 규칙 단위 테스트 7/7 통과
- `flutter analyze` 0 issues
- `pod install` (Flutter, gal, photo_manager, video_player_avfoundation)
- Render/*.swift 9개 Xcode 프로젝트 Runner 타겟 등록
- SceneDelegate 라이프사이클 반영 (Info.plist scene manifest + SceneDelegate에 RenderChannel 등록)
- `flutter build ios --debug --no-codesign` 성공
- `flutter build ios --simulator` 성공 + 시뮬에서 앱 실행 확인

## 다음 1개 작업

**실기기 연결 + 검증용 샘플 6개 준비.**

완료 판정:
- `flutter devices` 출력에 물리 iPhone(iOS 16+) 1대 노출
- 샘플 6개: 9:16 수직 숏 클립, 각 3~7초, 합 24~42초
  - **제약**: 1차 타깃(20대 친구 2인 릴스 맥락)에서 뽑은 실제 콘텐츠여야 함. 일반 풍경·테스트 패턴은 Stage 1 검증만 되고 Stage 6 시연 소재로 재활용 불가.
  - 3개는 landscape(가로) 원본, 3개는 portrait(세로) 원본으로 구성해 aspect-fill transform의 양 극단을 커버할 것.

## Stage 1 Exit Criteria (포기 불가)

**Step 1.5 시각 게이트 4조건 (전부 실기기에서 확인)**
- (a) 레터박스 없음 — 9:16 캔버스를 꽉 채움
- (b) 회전 눕음 없음 — portrait 소스가 가로로 눕지 않음
- (c) 중앙 크롭 — landscape 소스가 좌우 잘리고 중앙이 보임
- (d) 해상도 1080×1920 — 출력 mp4 메타가 정확히 일치

**추가 완료 조건**
- `gal.putVideo` 실기기 호출 성공 1회 (카메라롤 "UsCut" 앨범에 저장)
- `services/render_service.dart` public API 동결 선언 (Stage 2 의존 시작점). 인터페이스 변경이 필요해지면 Stage 1으로 복귀.

## 포기 가능 (Stage 1 블로킹 아님)

- 실기기 퍼포먼스 수치 (6초 mp4 3초 이내 export): "관찰 지표"로만 두고 Stage 6 최적화로 이관.
- iPhone 모델 하한 (iPhone 12+): Stage 1 블로킹 기준 아님.
- 커플 2차 타깃 검증: Stage 6 이후 재검토 (`deferred-issues.md` 참조).
- 피어 리뷰 Important 이슈 중 Stage 1 산출물에 직접 영향 없는 것: `deferred-issues.md`에 이관.

## 롤백 트리거

시각 게이트 실패 시의 이관 경로.

- **Observable**: Step 1.5 시각 게이트 재시도 횟수
- **Threshold**: 2회 연속 실패 (같은 입력 소재 기준)
- **Next action**: AVFoundation 자체 구현 포기, 대체재 조사 task 생성
  - 후보: ffmpeg_kit, video_editor, 서버 사이드 렌더
  - PO 직접 승인 필요 (Stage 1 매몰 비용 포기 결정)

## 에스컬레이션 기준

실패가 아닌 블로킹 상황.

- **Observable**: 빌드 또는 실기기 연결 블로킹 시간
- **Threshold**: 1일 이상
- **Next action**: 일정 재조정 에스컬레이션. 원인 구분: 툴체인 / 디바이스 / Apple ID / 코드서명

## 남은 체크포인트 (시각 게이트 이후)

1. `gal.putVideo` 저장 테스트
2. "UsCut" 앨범의 출력 mp4를 인스타그램 스토리 업로드해서 꽉 차게 표시되는지 육안 확인
3. `render_service.dart` public API 동결 주석 추가 (Stage 2 진입 직전)
