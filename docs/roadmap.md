# UsCut — Stage Roadmap

각 Stage의 경계·의존·대외 노출 수준 요약. 상세 설계는 착수 시점에 `docs/stageN-plan.md`로 분리 작성한다.

## Stage 포맷

각 Stage 섹션은 다음 5줄로 통일.

- **목표**: 이 Stage가 무엇을 되게 하는가 (한 문장)
- **동결 인터페이스**: 이 Stage 종료 후 다음 Stage가 의존하기 시작하는 계약
- **외부 의존**: Apple / Firebase / 서드파티 등 리드타임이 붙는 시스템
- **완료 판정**: 무엇을 관찰하면 끝난 것으로 간주하는가
- **대외 노출 수준**: 이 Stage 산출물을 외부에 보여줘도 되는가

## Stage 1 — 로컬 1인 렌더 검증

- 목표: 로컬 6개 클립을 받아 9:16 1080×1920 mp4를 만든다.
- 동결 인터페이스: `services/render_service.dart` public API, MethodChannel `com.uscut/render` payload 스키마.
- 외부 의존: 없음 (로컬 AVFoundation만).
- 완료 판정: `docs/stage1-remaining.md`의 Exit Criteria.
- 대외 노출 수준: **내부 검증 전용, 대외 노출 금지** — 협업 가치 미실증 상태.

## Stage 2 — 앱 내 카메라 캡처

- 목표: 앨범 대신 앱 내에서 0.5/1/2초 클립을 찍어 세션에 붙인다.
- 동결 인터페이스: `CaptureService` (카메라 출력 파일 경로 + 길이) → `ClipRef` 변환 계약.
- 외부 의존: iOS Camera 권한 (`NSCameraUsageDescription`).
- 완료 판정: 앱 내 촬영 3+3 → Stage 1 렌더 파이프라인 통과, 결과물 품질이 앨범 소스 대비 동등.
- 대외 노출 수준: 내부 검증 전용. 포지셔닝 축은 아직 "혼자 촬영"이라 미실증.

## Stage 3 — Firebase Auth + 세션 생성/참여

- 목표: 익명 로그인 기반으로 세션 생성·코드 참여를 구현한다.
- 동결 인터페이스: `SessionRepository` (create/join/fetch), Firestore `sessions/{id}` 문서 스키마.
- 외부 의존: Firebase Auth (익명), Firestore. **Firebase 프로젝트 프로비저닝 리드타임 존재**.
- 완료 판정: 기기 A가 생성한 세션 코드로 기기 B가 참여, 양쪽이 세션 상세 화면에서 동일 `participantIds`를 본다.
- 대외 노출 수준: 내부 검증 전용. 세션은 있으나 핵심 가치(자동 편집 결과물) 시연 불가.

## Stage 4 — 클립 업로드/동기화

- 목표: 두 사람의 클립이 Firebase Storage로 업로드되고 Firestore에 공개되어 양쪽 세션 화면에 보인다.
- 동결 인터페이스: `ClipRepository` (upload/list/watch), Storage 경로 규약 `sessions/{sid}/clips/{cid}.mp4`.
- 외부 의존: Firebase Storage + Firestore + 네트워크 대역.
- 완료 판정: 기기 A/B 각각 3개 클립 업로드 → 양쪽 세션 화면에서 6개가 실시간 반영.
- 대외 노출 수준: 내부 데모 가능 (비공개 시연 한정). 협업 동작은 보이나 결과물은 아직 없음.

## Stage 5 — 협업 렌더 완성

- 목표: 두 사람 클립을 Stage 1 렌더 파이프라인에 연결해 협업 결과물을 만든다.
- 동결 인터페이스: 렌더 트리거 규칙 (세션 총 6개 이상 + 각자 1개 이상 + `ownerId`만 트리거), 로컬 캐시 fallback.
- 외부 의존: Stage 4 Storage 다운로드 + Stage 1 렌더 엔진 + 로컬 temp 스토리지.
- 완료 판정: 기기 A/B 각 3개 클립으로 세션에서 Render 실행 → A/B/A/B/A/B 인터리브 9:16 mp4 1개 생성. **포지셔닝 축 실증용 친구 2인 실촬영 세션 1회 수행**.
- 대외 노출 수준: **포지셔닝 축("2인 비대칭 편집 해방") 실증 가능 → 랜딩 페이지 카피 확정 가능**.

## Stage 6 — 저장/공유 + 안정화 → TestFlight

- 목표: 카메라롤 저장 + 시스템 공유 시트 연결 + 전체 에러/빈상태/오프라인 처리 안정화 후 TestFlight 배포.
- 동결 인터페이스: TestFlight 빌드 아티팩트(signed ipa), 인스타 스토리/릴스 공유 파라미터.
- 외부 의존: **Apple Developer 계정, 코드서명 프로비저닝, TestFlight 심사 리드타임**.
- 완료 판정: TestFlight 내부 테스터 초대 → 1시드 세션 결과물 릴스 업로드 1건 성공. **30초 시연 영상 1개 + 스크린샷 3장 + 1문장 카피 확보**.
- 대외 노출 수준: 대외 TestFlight 클로즈드 베타 + 시연 영상·스크린샷 공개. **이 Stage에서 대외 메시징이 확정된다**.

## Stage 간 의존 요약

```
Stage 1 ─── render_service API ──→ Stage 2, Stage 5
Stage 2 ─── CaptureService ──→ Stage 5 (협업 렌더의 클립 입력원)
Stage 3 ─── SessionRepository ──→ Stage 4
Stage 4 ─── ClipRepository ──→ Stage 5
Stage 5 ─── 협업 렌더 산출물 ──→ Stage 6 (대외 메시징의 근거 산출물)
```

## 외부 리드타임 주의

- **Firebase 프로젝트 생성**: Stage 3 착수 전 필요. 처음 연결 시 계정·결제 확인에 반나절 소요 가능.
- **Apple Developer Program 등록**: Stage 6 전 완료되어야 TestFlight 가능. 승인 대기 최대 2주.
- **TestFlight 심사**: 빌드 제출 후 24~48시간 일반적.
