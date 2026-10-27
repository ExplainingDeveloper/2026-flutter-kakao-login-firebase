# 2단계: 카카오 SDK·Firebase 설치와 초기화

## 목적

1. 카카오 Flutter SDK와 Firebase 패키지를 설치한다.
2. `flutterfire configure`로 앱을 Firebase 프로젝트에 연결한다.
3. 앱이 시작될 때 Firebase와 카카오 SDK를 초기화한다.

초기화를 하지 않으면 로그인 API나 Firebase API를 호출할 때 에러가 난다.

## 필요한 정보

- `NATIVE_APP_KEY`: SKILL.md "공통 정보 모으기"의 네이티브 앱 키. 1단계 스킴에 넣은 키와 **정확히 같아야** 한다.
- `PROJECT_ID`: SKILL.md "공통 정보 모으기"의 Firebase 프로젝트 ID.

## 사전 확인

- 0단계 F(Firebase 준비)가 끝났는지 확인한다. `firebase projects:list` 결과에 `PROJECT_ID`가 있어야 한다.
  - 명령이 로그인 에러를 내면 사용자에게 `firebase login`을 실행해 달라고 한다. 에이전트가 실행하지 않는다.
- FlutterFire CLI가 실행되는지 확인한다. 0단계에서 `flutter pub global run flutterfire_cli:flutterfire` 방식을 썼다면 이 단계에서도 그 방식으로 실행한다.

## A. 패키지 설치

`pubspec.yaml`의 `dependencies`에 이미 있는 패키지는 빼고 설치한다.

```bash
flutter pub add kakao_flutter_sdk_user firebase_core firebase_auth cloud_functions
```

| 패키지 | 용도 |
|---|---|
| `kakao_flutter_sdk_user` | 카카오 로그인 API |
| `firebase_core` | Firebase 연결 (모든 Firebase 패키지의 기본) |
| `firebase_auth` | Firebase 로그인 (`signInWithCustomToken`) |
| `cloud_functions` | 3단계 서버 함수 호출 |

`flutter pub add`가 현재 Flutter 버전과 맞는 버전을 고르고 `flutter pub get`까지 실행한다. 버전 번호를 직접 추측해서 적지 않는다.

버전 충돌로 실패하면 출력의 원인(예: Dart SDK 버전 제약)을 한국어로 풀어서 설명하고 멈춘다.
카카오 Flutter SDK v2는 Flutter 3.38.0 이상이 필요하다.

## B. 최소 플랫폼 버전 맞추기

Firebase는 iOS 15 이상, Android API 24 이상이 필요하다. (근거: https://firebase.google.com/docs/flutter/setup)

**iOS**
- `ios/Runner.xcodeproj/project.pbxproj`의 `IPHONEOS_DEPLOYMENT_TARGET` 값이 15.0보다 낮으면 모두 `15.0`으로 바꾼다. 15.0 이상이면 그대로 둔다.
- `ios/Podfile`이 있으면 `platform :ios, '...'` 줄도 `15.0`으로 맞춘다. 주석(`#`)으로 막혀 있으면 주석을 풀고 `15.0`으로 쓴다. Podfile이 없으면 건너뛴다.
- 이 값을 맞추지 않으면 iOS 빌드가 "minimum deployment target" 관련 에러로 실패한다.

**Android**
- `android/app/build.gradle(.kts)`의 `minSdk`가 `flutter.minSdkVersion`이면 그대로 둔다. 최신 Flutter의 기본값은 24 이상이다.
- 숫자로 직접 적혀 있고 24보다 작으면 `24`로 바꾼다.

## C. Firebase 프로젝트 연결 (flutterfire configure)

프로젝트 루트에서 실행한다. `--platforms`에는 프로젝트에 있는 플랫폼만 넣는다.

```bash
flutterfire configure --project=<PROJECT_ID> --platforms=android,ios --yes
```

- `--yes`는 확인 질문을 건너뛴다. 이미 설정 파일이 있으면 덮어쓴다. 같은 프로젝트로 다시 실행하는 것이라 안전하다.
- 실행이 끝나면 `git status`로 새로 생기거나 바뀐 파일을 확인해서 완료 보고에 적는다. 보통 `lib/firebase_options.dart`가 생기고, Android·iOS 설정 파일과 `firebase.json`도 생긴다.
- 에러 대처
  - 로그인 관련 에러: 사용자에게 `firebase login`을 실행해 달라고 한다.
  - 프로젝트를 찾을 수 없다는 에러: 프로젝트 ID가 틀렸거나 다른 Google 계정으로 로그인한 것이다. `firebase projects:list`로 확인한다.
  - `doesn't support Dart x.y.z` 에러: 0단계 F-4의 함정이다. `flutter pub global run flutterfire_cli:flutterfire configure ...`로 다시 실행한다.

## D. 초기화 (main.dart)

대상 파일: `lib/main.dart` (`runApp()`이 있는 파일이 다르면 그 파일)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 연결 (flutterfire configure가 만든 설정 사용)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 카카오 SDK 초기화
  await KakaoSdk.init(nativeAppKey: '${NATIVE_APP_KEY}');

  runApp(const MainApp());
}
```

- `${NATIVE_APP_KEY}` 자리에는 실제 키를 넣는다.
- `runApp()` 전에 둘 다 초기화해야 한다. `await`를 쓰려면 `main()`이 `async`여야 하고, 그 앞에 `WidgetsFlutterBinding.ensureInitialized()`가 있어야 한다.
- 이미 있는 초기화 코드는 다시 넣지 않는다. `Firebase.initializeApp(`이나 `KakaoSdk.init(`이 있으면 값만 확인하고, 다르면 바꾼다.
- 기존 `main()`의 다른 코드와 `runApp(...)`의 인자는 그대로 둔다.
- 스타터 프로젝트면 `// TODO(카카오 2단계)` 주석 자리에 넣고 그 주석은 지운다. `// TODO(카카오 6단계)` 주석은 남겨 둔다.

## 검증

- `flutter analyze`를 실행한다. 에러와 경고가 없어야 한다.
  - **함정**: Firebase 패키지를 설치하면 iOS용 패키지 소스가 `build/ios/SourcePackages`에 내려받아진다. `flutter analyze`가 이 폴더까지 검사해서 우리 코드와 상관없는 이슈가 수백 개 나올 수 있다.
  - 이슈 경로가 전부 `build/`로 시작하면, `analysis_options.yaml`에 아래를 추가하고 다시 실행한다. 이미 있으면 건너뛴다.
    ```yaml
    analyzer:
      exclude:
        - build/**
    ```
- Android 빌드에서 `Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): cloud_functions, firebase_auth, firebase_core` 경고가 나올 수 있다. 앞으로 나올 Flutter 버전에 대한 예고이고, 지금 빌드에는 영향이 없다. 사용자에게 무시해도 된다고 알린다.
- `lib/firebase_options.dart`가 있는지, 그 안의 `projectId`가 `PROJECT_ID`와 같은지 확인한다.
- 네이티브 앱 키가 1단계 스킴의 키와 같은지 확인한다. 1단계를 아직 하지 않았으면 비교는 건너뛰고 1단계도 필요하다고 안내한다.

## 완료 보고에 포함할 내용

- 설치한 패키지와 버전 (`pubspec.yaml`에 들어간 값 그대로)
- `flutterfire configure`로 생기거나 바뀐 파일 목록
- 최소 플랫폼 버전을 바꿨는지 (iOS 15.0, Android 24)
- `main.dart`에서 바뀐 부분
- 키가 1단계 스킴과 일치하는지 확인한 결과
- Firebase 설정 파일(`firebase_options.dart` 등)이 `.gitignore`에 들어 있는지 한 줄 안내 (SKILL.md 작업 원칙 참고)
