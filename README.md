# UsCut

두 사람이 각자 찍은 짧은 영상 클립을 하나의 세션에 모으면 자동으로 인스타그램용 세로 영상을 생성해주는 2인 협업 카메라 앱.

현재 코드는 **Stage 1 프로토타입**이다. Firebase·세션·카메라 캡처는 포함되지 않는다. Stage 1의 유일한 목표는 **로컬 비디오 6개 → 9:16 mp4** 파이프라인을 Flutter + iOS AVFoundation으로 검증하는 것이다.

자세한 설계는 [`docs/stage1-plan.md`](docs/stage1-plan.md) 참고.

---

## 툴체인 요구

Stage 1을 빌드·실행하려면 다음이 필요하다.

1. **Flutter SDK** 3.27+ (Dart 3.5+)
2. **Xcode** 15+ (Command Line Tools만으로는 부족, 풀 Xcode 필요)
3. **CocoaPods** 1.14+
4. **iOS 16.0 이상의 실기기** (시뮬레이터에는 H.264 하드웨어 인코더가 없어 Stage 1 성능/품질 검증 불가. iPhone 12 이상 권장)

### 설치

```bash
# Xcode: App Store에서 설치 후
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept

# CocoaPods (Homebrew 사용 시)
brew install cocoapods

# Flutter (권장: Homebrew Cask 또는 공식 zip)
brew install --cask flutter
flutter doctor
```

---

## 최초 부트스트랩

현재 저장소에는 Dart 코드·Swift 렌더 모듈·pubspec·Podfile·Info.plist 등 **모든 앱 코드**가 들어 있다. 단, Xcode 프로젝트 파일(`ios/Runner.xcodeproj/`)은 `flutter create`가 생성해야 한다.

```bash
cd /Users/ninezero/Documents/workwpaces/UsCut

# Xcode 프로젝트 아티팩트 생성 (기존 파일은 보존됨)
flutter create --org com.uscut --project-name uscut --platforms=ios --ios-language swift .

# 주의: flutter create가 아래 파일을 덮어쓸 수 있다. 덮어쓴 경우 본 저장소의 커밋된 버전으로 복구:
#   - ios/Runner/AppDelegate.swift   (RenderChannel 등록 포함)
#   - ios/Runner/Info.plist          (권한 문자열 포함)
#   - ios/Podfile                    (platform :ios, '15.0')
#   - ios/Flutter/AppFrameworkInfo.plist (MinimumOSVersion 15.0)
#   - pubspec.yaml
#   - lib/main.dart
git status
git diff
# 필요한 경우 git restore <path> 로 되돌리기

flutter pub get
cd ios && pod install && cd ..
```

### Render 모듈을 Xcode 프로젝트에 추가

`ios/Runner/Render/` 하위 9개 Swift 파일은 `flutter create`가 자동으로 Xcode 프로젝트에 포함시키지 않는다. 수동으로 추가:

1. `open ios/Runner.xcworkspace`
2. Project navigator에서 `Runner` 그룹을 우클릭 → **Add Files to "Runner"…**
3. `ios/Runner/Render` 폴더 선택
4. Options:
   - **Copy items if needed**: OFF (파일은 이미 올바른 위치에 있음)
   - **Create groups**: ON
   - **Add to targets**: `Runner` 체크
5. Add

추가 후 `⌘+B`로 빌드해 모든 Swift 파일이 컴파일되는지 확인.

---

## 실행

```bash
# 실기기 연결 후
flutter devices           # 디바이스 ID 확인
flutter run -d <device-id>
```

**시뮬레이터 주의**: UI 레이아웃 확인 용도로만. 실제 렌더 품질/속도 판단은 실기기에서만 수행.

---

## 테스트

순수 Dart 편집 규칙 단위 테스트:

```bash
flutter test
```

5개 케이스가 `test/edit/alternating_rule_test.dart`에 들어있다.

---

## Stage 1 Acceptance

다음이 모두 실기기에서 통과하면 Stage 1 완료.

1. 홈 → Pick Clips → 6개 선택(A 3개, B 3개)
2. Continue 탭 후 3초 이내 프리뷰 전환
3. 프리뷰가 9:16 루프 재생, **레터박스 없이 꽉 차게**, 세로 소스도 누움 없이
4. 메타: 1080×1920, 6초 전후
5. Save to Photos → "UsCut" 앨범에 저장
6. 인스타그램 스토리 업로드 시 꽉 차게 표시

상세한 Go/No-Go 체크리스트는 [`docs/stage1-plan.md` §4 시각 검증 게이트](docs/stage1-plan.md#시각-검증-게이트-step-15) 참고.

---

## 디렉토리 구조

```
lib/
├── main.dart, app.dart
├── models/         (ClipRef, EditPlan, RenderResult)
├── edit/           (buildAlternatingPlan — 순수 함수)
├── services/       (RenderService — MethodChannel 래퍼)
└── screens/        (Home, ClipPicker, Preview)

ios/Runner/
├── AppDelegate.swift
├── Info.plist
└── Render/
    ├── RenderChannel.swift         (MethodChannel handler)
    ├── RenderRequest.swift, RenderClip.swift, RenderResult.swift
    ├── RenderError.swift           (FlutterError 매핑)
    ├── RenderEngine.swift          (오케스트레이션)
    ├── CompositionBuilder.swift    (AVMutableComposition)
    ├── VideoInstructionBuilder.swift  (aspect-fill transform)
    └── ExportCoordinator.swift     (AVAssetExportSession)

test/edit/alternating_rule_test.dart

docs/stage1-plan.md                 (상세 설계 문서)
```

---

## 다음 단계

Stage 1이 실기기에서 3회 연속 성공하면 Stage 2 (앱 내 카메라 캡처) → Stage 3 (Firebase 세션) → … 로 진행한다. Stage 계획은 `docs/stage1-plan.md`의 §6 및 향후 `docs/roadmap.md`(예정) 참고.
