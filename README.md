# UsCut

> 두 사람이 각자 찍은 짧은 영상 클립을 하나의 세션에 모으면 자동 편집으로 인스타그램용 9:16 세로 영상을 만들어주는 2인 협업 카메라 앱.

| | |
|---|---|
| Status | Stage 1 스캐폴드 완료, 검증 게이트 미통과 |
| Target | iOS 16.0+ |
| Engine | Flutter 3.27+ · AVFoundation |
| License | Private |

---

## 무엇을 하는 앱인가

기존 릴스/스토리 편집 흐름은 대체로 **한 사람**이 여러 영상을 받아 편집한다. UsCut은 그 부담을 없앤다.

1. A가 세션을 만든다.
2. B가 세션 코드로 합류한다.
3. 각자 짧은 클립을 올린다.
4. 앱이 규칙 기반 자동 편집으로 **9:16 1080×1920 mp4**를 생성한다.
5. 저장/공유.

포지셔닝 축은 **"2인 비대칭 편집 해방"** — 편집 담당이 한 명에게 쏠리는 비대칭을 구조적으로 제거한다.

## 기술 스택

| Layer | Tech | 역할 |
|---|---|---|
| UI / 상태 / 라우팅 | Flutter 3.27+ (Dart 3.5+) | 화면·상태·앨범·프리뷰 |
| 앨범 접근 | `photo_manager` 3.x | iOS Photos 라이브러리 |
| 결과 프리뷰 | `video_player` 2.x | AVPlayer 기반 루프 재생 |
| 카메라롤 저장 | `gal` 2.x | iOS 권한 자동 처리 |
| 임시 파일 | `path_provider` 2.x | tmp 경로 |
| 네이티브 렌더 | Swift · AVFoundation | Composition · Export · 9:16 aspect-fill |
| 협업 (계획) | Firebase Auth · Firestore · Storage | Stage 3~4 |
| 배포 (계획) | TestFlight | Stage 6 |

## 구조 개요

```
lib/                            # Flutter 앱
├── main.dart, app.dart
├── models/                     # ClipRef, EditPlan, RenderResult
├── edit/
│   └── alternating_rule.dart   # 순수 함수 (A/B 인터리브)
├── services/
│   └── render_service.dart     # MethodChannel 래퍼
└── screens/                    # Home, ClipPicker, Preview

ios/Runner/
├── AppDelegate.swift           # 앱 라이프사이클
├── SceneDelegate.swift         # RenderChannel 등록 (Flutter 3.41 scene)
├── Info.plist                  # 권한 · scene manifest
└── Render/                     # AVFoundation 렌더 모듈
    ├── RenderChannel.swift     # MethodChannel 핸들러
    ├── RenderRequest/Clip/Result/Error.swift
    ├── RenderEngine.swift      # 오케스트레이션
    ├── CompositionBuilder.swift
    ├── VideoInstructionBuilder.swift   # aspect-fill transform
    └── ExportCoordinator.swift

test/edit/alternating_rule_test.dart   # 7 cases

docs/
├── stage1-plan.md              # Stage 1 상세 설계
├── stage1-remaining.md         # Stage 1 남은 작업 (휘발성)
├── roadmap.md                  # Stage 2~6 개요
└── deferred-issues.md          # 이관 부채 · 반복 점검
```

## 요구 사항

**개발 머신 (macOS 전용)**
- macOS 13+ (Ventura 이상 권장)
- **Xcode 15+** (Xcode Command Line Tools만으로는 부족, **풀 Xcode 필요**)
  - iOS 16.0 플랫폼 SDK 설치 (Xcode Settings → Platforms)
  - `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` 로 활성화
- **Flutter SDK 3.27+** (Dart 3.5+)
  - `brew install --cask flutter` 또는 공식 zip
- **CocoaPods 1.14+** (`brew install cocoapods` 또는 `gem install cocoapods`)
- **Homebrew** (선택: ffmpeg 등 설치용)

**실행 대상**
- iOS 16.0 이상 디바이스 (렌더 품질·성능 검증용)
- iOS 16.0 시뮬레이터 (UI 플로우 확인용, 렌더 성능은 비신뢰)

Flutter 환경을 점검하려면:
```bash
flutter doctor
```

## 설치 및 첫 실행 (clone 후)

```bash
# 1. 클론
git clone git@github.com:LightningGroup/UsCut.git
cd UsCut

# 2. Dart 의존성
flutter pub get

# 3. CocoaPods 의존성 (Flutter iOS 모듈 링크 포함)
cd ios && pod install && cd ..

# 4. (선택) 실기기 연결 확인
flutter devices
```

이 저장소에는 `ios/Runner.xcodeproj/` 가 커밋되어 있으므로 **`flutter create`를 다시 실행할 필요는 없다.** `ios/Runner/Render/*.swift` 9개 파일도 이미 Xcode 프로젝트의 Runner 타겟에 등록되어 있다.

### 실기기에서 실행

```bash
flutter devices            # 디바이스 ID 확인
flutter run -d <device-id>
```

무료 Apple ID로도 개발자 서명이 가능하다. Xcode의 Runner 타겟 설정에서 **Signing & Capabilities → Team** 을 본인 Apple ID로 지정한 뒤 첫 실행.

### 시뮬레이터에서 실행 (UI 확인용)

```bash
# 시뮬레이터 부팅
xcrun simctl list devices available | grep "iPhone 17 Pro"
xcrun simctl boot "<DEVICE-UUID>"
open -a Simulator

# 앱 빌드 + 설치 + 실행
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.uscut.uscut
```

또는 간단히:
```bash
flutter run -d <simulator-id>
```

### 시뮬레이터에 샘플 영상 주입 (테스트용)

시뮬레이터 Photos 앱에는 기본 영상이 없다. ffmpeg로 색상·해상도가 다른 샘플 6개를 만들어 주입할 수 있다.

```bash
brew install ffmpeg   # 아직 없다면

mkdir -p /tmp/uscut_samples && cd /tmp/uscut_samples
for spec in \
  "a1_red:red:1920x1080" "a2_orange:orange:1920x1080" "a3_yellow:yellow:1920x1080" \
  "b1_blue:blue:1080x1920" "b2_green:green:1080x1920" "b3_purple:purple:1080x1920"; do
  IFS=':' read -r name color size <<< "$spec"
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "color=c=${color}:s=${size}:d=3:r=30" \
    -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "${name}.mp4"
done

xcrun simctl addmedia booted /tmp/uscut_samples/*.mp4
```

이 샘플은 시뮬 UI 플로우 확인용일 뿐, Stage 1 완료 판정(실기기 시각 게이트)을 대체하지 못한다.

## 개발 워크플로우

### 테스트

순수 Dart 편집 규칙 단위 테스트:

```bash
flutter test
```

`test/edit/alternating_rule_test.dart` 에 7개 케이스 — 3+3 인터리브, 길이 불일치, 빈 입력, clamp, 커스텀 길이, zero-duration 스킵, 비대칭 clamp.

### 정적 분석

```bash
flutter analyze
```

`analysis_options.yaml` 에서 `flutter_lints` + trailing commas 강제. PR 전 `0 issues` 유지 필수.

### iOS 네이티브 컴파일만 빠르게 확인

```bash
flutter build ios --debug --no-codesign          # 디바이스 타겟
flutter build ios --simulator --debug            # 시뮬 타겟
```

Swift 타입 체크·링크 에러는 여기서 잡힌다. `Runner.app` 생성 성공 시 네이티브 계약 OK.

### 새 Swift 파일을 Xcode 프로젝트에 추가

`ios/Runner/Render/` 하위에 Swift 파일을 추가할 때, Xcode 프로젝트의 Runner 타겟에도 등록되어야 빌드에 포함된다. 두 가지 방법:

**A. Xcode GUI**
1. `open ios/Runner.xcworkspace`
2. Runner 그룹 우클릭 → **Add Files to "Runner"…**
3. **Copy items if needed**: OFF, **Create groups**: ON, **Add to targets**: Runner ✓

**B. 스크립트 (`ios/add_render_module.rb`)** — untracked, 1회성. 재사용 정책은 `docs/deferred-issues.md` 참조.

### MethodChannel 계약

- Channel: `com.uscut/render`
- Method: `renderAlternating`
- Request/Response 스키마: `docs/stage1-plan.md §3` 참고

Dart 측 래퍼: `lib/services/render_service.dart`
Swift 측 핸들러: `ios/Runner/Render/RenderChannel.swift`

인터페이스는 Stage 1 완료 시점에 **동결**되며, Stage 2 이후 변경은 Stage 1 복귀를 의미한다.

## 프로젝트 상태

| Stage | 목표 | 상태 |
|---|---|---|
| Stage 1 | 로컬 6개 클립 → 9:16 mp4 렌더 | 🟡 스캐폴드 완료, 검증 게이트 미통과 |
| Stage 2 | 앱 내 카메라 캡처 | ⚪ 미착수 |
| Stage 3 | Firebase Auth + 세션 생성/참여 | ⚪ 미착수 |
| Stage 4 | 클립 업로드/동기화 | ⚪ 미착수 |
| Stage 5 | 협업 렌더 완성 | ⚪ 미착수 |
| Stage 6 | 저장/공유 + 안정화 → TestFlight | ⚪ 미착수 |

- Stage 1 남은 작업: `docs/stage1-remaining.md`
- Stage 2~6 개요: `docs/roadmap.md`
- 이관 부채: `docs/deferred-issues.md`

### Stage 1 Acceptance 요약

다음을 실기기에서 모두 통과하면 Stage 1 완료로 판정.

1. 홈 → Pick Clips → 6개 선택 (A 3개, B 3개)
2. Continue 탭 후 프리뷰 전환
3. 프리뷰가 9:16 루프 재생 — **레터박스 없이 꽉 차게, 세로 소스 눕음 없이, 가로 소스 중앙 크롭**
4. 메타: 1080×1920, 6초 전후
5. Save to Photos → "UsCut" 앨범에 저장
6. 인스타그램 스토리 업로드 시 꽉 차게 표시

상세 게이트는 `docs/stage1-remaining.md` 참조.

## 트러블슈팅

### `xcode-select: error: tool 'xcodebuild' requires Xcode`
Command Line Tools로 되어 있다. 풀 Xcode 경로로 전환:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### `iOS 26.4 is not installed`
Xcode 26은 iOS 플랫폼 SDK를 별도 다운로드한다:
```bash
xcodebuild -downloadPlatform iOS
```
또는 Xcode → Settings → Platforms에서 GUI로 설치.

### `pod install` 시 `Generated.xcconfig must exist`
Flutter 설정이 아직 생성 안 된 상태. 먼저:
```bash
flutter pub get
flutter build ios --config-only --no-codesign
```

### 시뮬에서 렌더가 매우 느리거나 실패
시뮬에는 H.264 하드웨어 인코더가 없어 소프트웨어 fallback으로 돌아간다. 성능·품질 최종 검증은 실기기에서.

## 기여

현재 Private 저장소. 팀 내부 기여만 받는다.

- 브랜치: `main` 직접 커밋 지양. 기능별 브랜치에서 PR.
- 커밋 메시지: 첫 줄 타입(`feat`/`fix`/`chore`/`docs`/`style`/`refactor`) + 짧은 요약. 본문에 "왜" 기록.
- PR 전 체크: `flutter test` 통과 + `flutter analyze` 0 issues.
- Stage 경계를 넘는 변경은 `docs/roadmap.md` 해당 Stage의 "동결 인터페이스"를 먼저 읽고 영향도 평가.

## 라이선스

Private (내부 프로젝트). 외부 공개·재배포 금지.
