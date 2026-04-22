# UsCut — Stage 1 구현 계획

Stage 1의 유일한 목표: **로컬 비디오 6개 → 9:16 세로 mp4 한 개** 파이프라인을 Flutter + iOS AVFoundation으로 end-to-end 검증한다. Firebase, 세션, 실시간 동기화, 카메라 캡처는 Stage 2 이후로 미룬다.

---

## 1. 프로젝트 부트스트랩

### 1.1 `flutter create`

```bash
cd /Users/ninezero/Documents/workwpaces/UsCut
flutter create --org com.uscut --project-name uscut --platforms=ios --ios-language swift .
```

점(`.`)으로 현재 디렉토리를 프로젝트 루트로 고정. 기존 `.git` 및 스캐폴딩된 파일들은 보존된다. `Runner.xcodeproj` 등 Flutter가 생성해야 하는 아티팩트만 추가된다.

### 1.2 iOS 배포 타겟

**iOS 16.0** 고정.

- `AVAsset.load(_:)` / `AVAssetTrack.load(_:)` 의 `AVAsyncProperty` 기반 async API가 iOS 16+ 전용. iOS 15에서는 `loadValuesAsynchronously(forKeys:completionHandler:)` 래핑이 필요하지만 2026년 기준 iOS 16 커버리지가 충분해 최소 타겟을 올려 코드를 단순화.
- `AVAssetExportSession` 안정성, `PHPickerViewController` 기반 최신 권한 흐름 모두 유지.

수정 위치:
- `ios/Podfile` — `platform :ios, '16.0'` (이미 반영)
- `ios/Runner.xcodeproj/project.pbxproj` — `IPHONEOS_DEPLOYMENT_TARGET = 16.0;` (Debug/Release/Profile 모두)
- `ios/Flutter/AppFrameworkInfo.plist` — `MinimumOSVersion = 16.0` (이미 반영)

### 1.3 의존성

`pubspec.yaml`에 고정:
- `photo_manager ^3.2.0`
- `video_player ^2.9.2`
- `gal ^2.3.0`
- `path_provider ^2.1.4`

Riverpod/Isar/Drift/share_plus는 Stage 1에서 사용하지 않는다.

### 1.4 `Info.plist` 권한

이미 추가됨:
- `NSPhotoLibraryUsageDescription` — 읽기 접근
- `NSPhotoLibraryAddUsageDescription` — 카메라롤 저장
- `NSCameraUsageDescription` — Stage 3 대비 placeholder

---

## 2. 파일 구조

### Dart

```
lib/
├── main.dart
├── app.dart
├── models/
│   ├── clip_ref.dart
│   ├── edit_plan.dart
│   └── render_result.dart
├── edit/
│   └── alternating_rule.dart
├── services/
│   └── render_service.dart
└── screens/
    ├── home_screen.dart
    ├── clip_picker_screen.dart
    └── preview_screen.dart

test/
└── edit/
    └── alternating_rule_test.dart
```

### iOS Swift

```
ios/Runner/
├── AppDelegate.swift              (RenderChannel 등록)
├── Info.plist                     (권한 + orientation)
└── Render/
    ├── RenderChannel.swift        (MethodChannel 핸들러)
    ├── RenderRequest.swift        (JSON → 구조체 + validate)
    ├── RenderClip.swift           (clip 값 타입)
    ├── RenderResult.swift         (성공 응답 인코딩)
    ├── RenderError.swift          (에러 → FlutterError 매핑)
    ├── RenderEngine.swift         (오케스트레이션)
    ├── CompositionBuilder.swift   (AVMutableComposition 구성)
    ├── VideoInstructionBuilder.swift (aspect-fill transform)
    └── ExportCoordinator.swift    (AVAssetExportSession 래퍼)
```

---

## 3. MethodChannel 계약

- Channel: `com.uscut/render`
- Method: `renderAlternating`

### Request schema

```jsonc
{
  "requestId": "stage1-<epochMs>",
  "outputDir": "/abs/path/to/tmp/",
  "outputFilename": "uscut_<epochMs>.mp4",
  "renderSize": { "width": 1080, "height": 1920 },
  "frameRate": 30,
  "clips": [
    {
      "index": 0,
      "sourcePath": "/abs/path/to/IMG_1234.MOV",
      "startMs": 0,
      "durationMs": 1000,
      "userTag": "A"
    }
  ]
}
```

- 모든 시간은 **milliseconds**. 네이티브는 `CMTime(value: ms * 600 / 1000, timescale: 600)` 변환.
- 모든 경로는 **절대 경로**.
- `renderSize.width`와 `height`는 **짝수** (H.264 인코더 요구).

### Success response

```jsonc
{
  "requestId": "stage1-1714000000000",
  "outputPath": "/abs/path/to/tmp/uscut_1714000000000.mp4",
  "durationMs": 6000,
  "width": 1080,
  "height": 1920,
  "fileSizeBytes": 3245678
}
```

### Error codes

| code | 언제 | details |
|---|---|---|
| `INVALID_REQUEST` | JSON 디코딩 실패 / 필수 필드 누락 | `field` |
| `CLIP_COUNT_INVALID` | clips 수가 1..8 범위 밖 | `count` |
| `SOURCE_NOT_FOUND` | 파일이 존재하지 않음 | `index`, `path` |
| `SOURCE_UNREADABLE` | AVAsset 트랙 로드 실패 | `index` |
| `TRIM_OUT_OF_RANGE` | startMs+durationMs가 소스보다 김 | `index`, `sourceDurationMs`, `requestedEndMs` |
| `COMPOSITION_BUILD_FAILED` | insertTimeRange 실패 | `index` |
| `EXPORT_FAILED` | AVAssetExportSession 실패 | `underlyingError` |
| `EXPORT_CANCELLED` | 익스포트 취소 (Stage 1 미발생) | — |
| `OUTPUT_WRITE_FAILED` | outputDir 접근 불가 | `outputDir` |

### 진행률 보고

**Stage 1에서 구현하지 않음.** 6초 출력물은 iPhone 12+에서 2–4초 안에 끝난다. 단순 스피너 + "Rendering..." 텍스트로 충분. Stage 5에서 EventChannel 추가.

### 파일 수명 규칙

- **입력 파일**: `photo_manager`가 반환하는 경로를 Flutter가 그대로 전달. iOS는 복사하지 않음.
- **출력 파일**: Flutter가 `path_provider.getTemporaryDirectory()` 경로를 넘기고, iOS는 그 디렉토리에 쓴다.
- **클린업**: Flutter 소유. `RenderService`가 렌더 시작 시 이전 `uscut_*.mp4`를 삭제.
- **카메라롤 저장**: 프리뷰 화면에서 사용자가 명시적으로 Save 버튼을 눌렀을 때만 `gal.putVideo(path, album: 'UsCut')` 호출.

---

## 4. iOS 렌더 엔진

### AVFoundation 호출 시퀀스

1. **Request 파싱** (`RenderRequest.decode(from:)`)
   - `JSONSerialization` → `JSONDecoder` 두 단계. KeyNotFound/TypeMismatch를 `INVALID_REQUEST`로 매핑.
2. **검증** (`RenderRequest.validate()`)
   - `FileManager.fileExists` 체크, 트림 양수, renderSize 짝수.
3. **Composition 구성** (`CompositionBuilder.build`)
   - 단일 `AVMutableCompositionTrack` (video) 생성.
   - 각 클립: `AVURLAsset` → `loadTracks(withMediaType: .video)` → `insertTimeRange` at cursor.
   - 시간값은 timescale 600으로 고정 (30/24/25fps 모두 정수 표현 가능).
4. **VideoComposition 구성**
   - `renderSize = (1080, 1920)`, `frameDuration = CMTime(1, 30)`.
   - 클립별 `AVMutableVideoCompositionInstruction` (각각 자기 timeRange).
   - 각 instruction 내 단일 `AVMutableVideoCompositionLayerInstruction`에 `setTransform(aspectFillTransform, at: start)`.
5. **Export** (`ExportCoordinator.export`)
   - Preset: `AVAssetExportPresetHighestQuality` (1080p 해상도는 preset 이름이 아니라 `videoComposition.renderSize`로 지정).
   - `outputFileType = .mp4`, `shouldOptimizeForNetworkUse = true`, 오디오 트랙 없음 → 자동 무음.
6. **결과 회신** — `MainActor.run` 으로 메인 스레드 복귀 후 `FlutterResult` 호출.

### Aspect-fill transform (`VideoInstructionBuilder.aspectFillTransform`)

Stage 1에서 가장 틀리기 쉬운 부분. 순서:

1. `preferredTransform`을 natural size 사각형에 적용해 "화면에 보이는" 방향의 rect 계산.
2. 그 rect의 min 좌표가 (0,0)이 되도록 평행이동 합성.
3. `max(targetW/orientedW, targetH/orientedH)` 로 스케일 (fill, **not fit**).
4. 스케일된 컨텐츠를 캔버스 중앙에 배치하는 평행이동.

모든 단계를 `CGAffineTransform.concatenating(_:)` 으로 명시적으로 연결한다. `scaledBy` / `translatedBy`는 로컬 좌표계 기준이라 디버깅이 어렵다 — 사용 금지.

### 시각 검증 게이트 (Step 1.5)

**이 게이트 전에 Stage 1 진행 금지.**

테스트 조합:
- A = iPhone 세로 촬영 영상 (`preferredTransform` 90° 회전 포함)
- B = 랜드스케이프 영상 (`preferredTransform` identity)

검증 항목:
1. 두 클립 모두 **꽉 찬 9:16** (레터박스 없음)
2. 세로 영상이 **옆으로 눕지 않음**
3. 가로 영상이 **중앙 크롭**되어 좌우가 잘림, 좌우반전/상하반전 없음
4. 출력 mp4 메타의 해상도가 **정확히 1080×1920**

하나라도 실패하면 `aspectFillTransform` 수식 재검토. 특히 step 2의 min 좌표 보정이 빠지면 회전된 컨텐츠가 음수 영역에 남아 검은 화면이 나온다.

---

## 5. Dart 편집 규칙

순수 함수. `dart:io` 의존 없음. `test/edit/alternating_rule_test.dart`로 전량 커버.

```dart
EditPlan buildAlternatingPlan({
  required List<ClipRef> clipsA,
  required List<ClipRef> clipsB,
  int defaultClipDurationMs = 1000,
})
```

규칙:
- 두 리스트 중 **짧은 쪽 길이**까지만 인터리브 (3+3이 기본, 2+3이면 2+2만 사용).
- 각 클립은 `startMs = 0`, `durationMs = min(default, clip.durationMs)`.
- 최종 순서는 `A0, B0, A1, B1, ...`.

---

## 6. 구현 순서 (Stage 1 내부)

각 단계 끝은 사람이 실기기/시뮬에서 확인 가능한 아티팩트.

| Step | 산출물 | Acceptance |
|---|---|---|
| 1.1 | Flutter 프로젝트 부트스트랩 + iOS 15 타겟 | `flutter run`으로 "UsCut" 홈 화면 표시 |
| 1.2 | photo_manager 피커, 6개 선택 → 경로 출력 | 선택 후 다음 화면에 6개 절대경로 표시 |
| 1.3 | Hardcoded 2-clip concat (트림/변환 없이) | tmp에 2-clip 이어붙인 mp4 생성, QuickTime 재생 가능 |
| 1.4 | 트림 `startMs`/`durationMs` 존중 | `(500, 1000)` 전달 시 정확히 0.5–1.5초 구간만 나옴, 잘못된 값은 `TRIM_OUT_OF_RANGE` |
| 1.5 | **9:16 scale/crop transform** | 세로+가로 혼합 2클립이 Stage 1 시각 검증 4항목 모두 통과 |
| 1.6 | Dart edit rule + 6 클립 실제 렌더 | 6개 선택 후 A/B 인터리브된 6초 mp4 생성 |
| 1.7 | video_player 프리뷰 | 렌더 완료 즉시 9:16 루프 재생 |
| 1.8 | 카메라롤 저장 | "UsCut" 앨범에 mp4 저장, 인스타 스토리 업로드에서 꽉 차게 표시 |

---

## 7. 리스크 & 완화

| 리스크 | 완화 |
|---|---|
| `preferredTransform` 회전 처리 실패 — 세로 영상이 눕거나 offset 음수로 검은 화면 | Step 1.5 시각 검증 전 다음 단계 금지. 디버그 로그로 매 클립 `(naturalSize, preferredTransform, orientedRect, scale, tx, ty, final)` 한 줄 출력 |
| 가로 소스의 좌우 크롭으로 피사체 유실 | 단순 center-crop 고정 (Stage 1 scope). README에 테스트 클립 촬영 가이드 1줄: "피사체 중앙" |
| 시뮬 vs 실기기 AVFoundation 차이 — 시뮬에 하드웨어 인코더 없음 | Step 1.3부터 실기기 테스트 필수. 완료 기준: "iPhone 12 이상에서 6클립 6초 mp4 3초 이내 export" |
| `photo_manager` 경로의 수명 — OS가 임시 캐시 삭제 가능 | Continue 직후 `File.existsSync()` 검사, 실패 시 재해석. Stage 6에서 Isar 캐시로 해결 |
| preset + `videoComposition.renderSize` 충돌 | `AVAssetExportPresetHighestQuality` + 커스텀 renderSize 조합 사용. 1080p/4K/HEVC/H.264 섞어 Step 1.5에서 최소 3조합 테스트. 실패 시 `AVAssetWriter` 경로로 선회 (Stage 1 백로그) |
| 출력 길이·메모리 (Stage 1 scope 내 해당 없음) | `RenderEngine.render`의 API를 `async throws -> RenderSuccess`로 고정 — Stage 6에서 세그먼트 export + concat으로 리팩토링 가능 |

---

## 요약

Stage 1의 모든 의사결정은 **"9:16 mp4가 실기기에서 제대로 나오는가"** 한 질문에 서빙한다. Step 1.5 (aspect-fill transform 시각 검증)가 이 Stage의 단일 go/no-go 게이트다.
