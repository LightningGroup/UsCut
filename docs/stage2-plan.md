# Stage 2 Plan — 앱 내 카메라 캡처

작성일: 2026-04-23

## 목표

앨범 대신 앱 내에서 0.5/1/2초 클립을 찍어 Stage 1 렌더 파이프라인에 공급한다.

## 동결 인터페이스

`CaptureService` (`lib/services/capture_service.dart`)

```dart
Future<ClipRef> captureClip({
  required String userTag,  // 'A' | 'B'
  required int durationMs,  // 500 | 1000 | 2000
})
```

- 입력: 카메라 출력 파일 경로 + 요청 길이
- 출력: `ClipRef(sourcePath, userTag, durationMs)`
- Stage 5가 이 계약에 의존하기 시작함. 인터페이스 변경 시 Stage 2로 복귀.

## 구현 결정사항

| 항목 | 결정 | 근거 |
|---|---|---|
| 카메라 패키지 | `camera: ^0.12.0+1` | Flutter 공식 플러그인, AVFoundation 백엔드 |
| 해상도 | `ResolutionPreset.high` | 렌더 파이프라인 입력 품질 확보 |
| 오디오 | `enableAudio: false` | Stage 1 렌더 엔진이 오디오 트랙 미포함 |
| 방향 고정 | `portraitUp` lock | 9:16 캔버스와 정합 |
| 녹화 방식 | 탭 → 타이머 자동 종료 | 고정 길이 클립, UX 단순화 |
| 진행 표시 | 병렬 50ms 스텝 애니메이션 | captureClip 내부 timer와 병렬 실행 |
| buildAlternatingPlan | `defaultClipDurationMs: 2000` | min(2000, clip.durationMs)로 클램핑 없음 |

## 산출물

| 파일 | 역할 |
|---|---|
| `lib/services/capture_service.dart` | 동결 인터페이스 (CaptureService) |
| `lib/screens/capture_screen.dart` | 카메라 UI (촬영 → 렌더 진입) |
| `lib/screens/home_screen.dart` | "Record Clips" + "Pick from Gallery" 진입점 |
| `ios/Runner/Info.plist` | NSCameraUsageDescription 확정, NSMicrophoneUsageDescription 추가 |

## UX 플로우

```
HomeScreen
  ├─ "Record Clips" → CaptureScreen
  │     ├─ 카메라 초기화 (백카메라, portrait lock)
  │     ├─ 기간 선택: 0.5s / 1s / 2s
  │     ├─ 촬영 A×3 → 촬영 B×3 (순차)
  │     ├─ Undo: 마지막 클립 제거
  │     └─ Next → buildAlternatingPlan → PreviewScreen
  └─ "Pick from Gallery" → ClipPickerScreen (Stage 1 경로 유지)
```

## 완료 판정

roadmap.md 기준:

- 앱 내 촬영 3+3 클립이 Stage 1 렌더 파이프라인을 통과함
- 출력 결과물 품질이 앨범 소스 기준 대비 동등 (1080×1920, 레터박스 없음, 회전 없음)

## 포기 가능

- 카메라 플래시/전환 기능: Stage 6 이후 검토
- 촬영 중 타임코드 표시: 관찰 지표로만 유지
- 전면 카메라 전환: Stage 5 협업 렌더 검토 시 재평가
