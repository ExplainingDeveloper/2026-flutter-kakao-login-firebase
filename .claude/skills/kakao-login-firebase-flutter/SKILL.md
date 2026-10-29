---
name: kakao-login-firebase-flutter
description: Flutter 앱에 카카오 로그인을 붙이고, 로그인한 사용자를 Firebase Authentication 사용자로 연결하는 스킬. Firebase Cloud Functions가 카카오 액세스 토큰을 확인한 뒤 Firebase 커스텀 토큰을 발급하는 방식이다. 사용자가 실행할 단계를 고르면 그 단계만, "전체"를 고르면 모든 단계를 순서대로 진행한다. 단계 - 0) 준비(카카오 디벨로퍼스 콘솔, 키 해시, 로그인 버튼 이미지, Firebase 프로젝트, Blaze 요금제, Firebase CLI·FlutterFire CLI), 1) 커스텀 URL 스킴(AndroidManifest.xml / Info.plist), 2) 카카오 SDK·Firebase 설치와 초기화(flutterfire configure, Firebase.initializeApp, KakaoSdk.init), 3) Cloud Functions(카카오 토큰 확인 → createCustomToken, 회원 삭제 함수, 배포, 서비스 계정 권한), 4) 로그인 로직(카카오 로그인 → 함수 호출 → signInWithCustomToken, 로그인 버튼), 5) Firebase 사용자 정보(홈 화면), 6) 자동 로그인(authStateChanges), 7) 로그아웃/회원 탈퇴(Firebase 계정 삭제 + 카카오 연결 끊기). Flutter에서 카카오 로그인과 Firebase를 함께 언급하면(카카오 Firebase 연동, 카카오 커스텀 토큰, signInWithCustomToken, Cloud Functions 카카오, firebase_auth 카카오) 명시적으로 부르지 않아도 이 스킬을 사용할 것. Firebase 없이 카카오 로그인만 붙일 때는 이 스킬이 아니라 kakao-login-flutter 스킬을 쓴다.
---

# Flutter 카카오 로그인 + Firebase 적용

이 스킬은 Flutter 앱에 카카오 로그인을 붙이고, 로그인한 사용자를 Firebase Authentication 사용자로 만드는 작업을 여러 단계로 나눠 진행한다.
사용자는 한국인이다. 질문, 진행 안내, 완료 보고는 모두 자연스러운 한국어로 작성한다.
이 스킬은 Claude Code 외의 에이전트(GitHub Copilot 등)에서도 쓰일 수 있다. 지침에 나오는 질문 도구(AskUserQuestion)가 없으면 같은 내용을 채팅으로 묻는다.
코드, 파일 경로, XML/plist 키, 명령어는 원문 그대로 둔다.

## 왜 이런 구조인가

카카오는 Firebase Authentication이 기본으로 지원하는 로그인 제공업체가 아니다. 연결 방법은 두 가지다.

- **OIDC 제공업체로 등록**: Identity Platform 업그레이드가 필요하고, SAML/OIDC 로그인은 무료 사용량이 아주 작다.
- **커스텀 토큰 (이 스킬의 방식)**: 서버가 카카오 토큰을 확인하고 Firebase 커스텀 토큰을 발급한다. 서버는 Firebase Cloud Functions를 쓴다. Cloud Functions는 Blaze(종량제) 요금제가 필요하지만 무료 사용량 안에서는 비용이 나오지 않는다.

흐름:

```
앱: 카카오 로그인 → 카카오 액세스 토큰
앱 → Cloud Functions(kakaoLogin): 카카오 액세스 토큰 전달
함수: 카카오 서버에 토큰 확인(우리 앱에서 발급된 토큰인지까지) → Firebase 커스텀 토큰 발급
앱: signInWithCustomToken(커스텀 토큰) → Firebase 로그인 완료
```

커스텀 토큰은 반드시 서버에서 만든다. 앱에서 만들면 서비스 계정 비밀키가 앱에 들어가서 누구나 아무 사용자로 로그인할 수 있게 된다.

## 단계 목록

| 번호 | 단계                                                                                                     | 지침 파일                                 |
| ---- | -------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| 0    | 준비 – 카카오 디벨로퍼스 콘솔, 로그인 버튼 이미지, Firebase 프로젝트·Blaze·CLI (사용자 직접 + 스킬 안내) | `references/step-00-prepare.md`           |
| 1    | 프로젝트 설정 – 커스텀 URL 스킴 (Android / iOS)                                                          | `references/step-01-custom-url-scheme.md` |
| 2    | 카카오 SDK·Firebase 설치와 초기화 (pubspec.yaml, flutterfire configure, main.dart)                       | `references/step-02-install-and-init.md`  |
| 3    | Cloud Functions – 카카오 토큰 확인 → 커스텀 토큰 발급, 회원 삭제, 배포                                   | `references/step-03-cloud-functions.md`   |
| 4    | 로그인 로직 (카카오 로그인 → 함수 → Firebase 로그인, 로그인 버튼)                                        | `references/step-04-login.md`             |
| 5    | Firebase 사용자 정보 (홈 화면)                                                                           | `references/step-05-user-info.md`         |
| 6    | 자동 로그인 (Firebase 로그인 상태 확인)                                                                  | `references/step-06-auto-login.md`        |
| 7    | 로그아웃 / 회원 탈퇴 (Firebase 계정 삭제 + 카카오 연결 끊기)                                             | `references/step-07-logout-delete.md`     |

표의 순서가 곧 "전체" 실행 순서다.
새 단계를 추가할 때는 `references/step-NN-<이름>.md`를 만들고 이 표에 한 줄을 추가한다.

## 진행 순서

### 1. 프로젝트 확인

- 현재 디렉터리(또는 사용자가 알려준 경로)에 `pubspec.yaml`이 있고 `flutter:` SDK 의존성이 있는지 확인한다.
  Flutter 프로젝트가 아니면 이유를 알려주고 멈춘다.
- `android/`, `ios/` 폴더가 있는지 확인한다. 한쪽이 없으면 해당 플랫폼 작업은 건너뛰고, 건너뛴다는 사실을 사용자에게 알린다.

### 2. 실행할 단계 고르기

- 스킬 인자나 사용자 메시지에 단계 번호(예: `1`, `3단계`)나 `전체`/`all`이 있으면 그대로 따른다.
- 없으면 물어본다. 선택지 질문 도구가 있으면 그것을 쓰고, 없으면 채팅으로 번호를 물어본다.
  - 질문 예: "어떤 단계를 진행할까요?"
  - 질문 본문에 위 단계 목록을 번호와 함께 적는다.
  - 선택지 (AskUserQuestion은 최대 4개라서 단계별 선택지를 모두 넣을 수 없다):
    - `전체 진행 (0→7단계)`: 처음 시작하는 경우
    - `0단계만: 준비`: 카카오 콘솔, Firebase 프로젝트, CLI 준비를 한 단계씩 안내
    - `코드 작업만 (1→7단계)`: 콘솔과 Firebase 준비를 이미 마친 경우
  - 특정 단계 하나만 하려면 "Other"에 번호를 입력하라고 질문 본문에 적는다.
- `1-3`, `1~3`처럼 범위를 받으면 그 범위의 단계를 순서대로 진행한다.

### 3. 공통 정보 모으기

여러 단계에서 같은 값을 쓴다. 필요한 단계를 시작하기 직전에 한 번만 받아서 이후 모든 단계에 다시 쓴다. 같은 질문을 두 번 하면 사용자가 번거롭다.

| 값                        | 쓰는 단계 | 받는 시점                                    |
| ------------------------- | --------- | -------------------------------------------- |
| 카카오 **네이티브 앱 키** | 1, 2      | "전체"면 0단계 C-2. 아니면 1 또는 2단계 직전 |
| 카카오 **앱 ID** (숫자)   | 3         | "전체"면 0단계 C-2. 아니면 3단계 직전        |
| Firebase **프로젝트 ID**  | 2, 3      | "전체"면 0단계 F-1. 아니면 2 또는 3단계 직전 |

**네이티브 앱 키**

1. 먼저 프로젝트에 이미 키가 있는지 찾는다.
   - `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`에서 `kakao[0-9a-f]{32}` 패턴을 찾는다.
   - `lib/` 아래에서 `nativeAppKey`를 찾는다.
   - 찾았으면 "기존에 설정된 키 `xxxx…`를 사용할까요?"라고 확인한다.
2. 없으면 사용자에게 받는다. 위치: **카카오 디벨로퍼스 > 앱 > [앱] > 플랫폼 키 > 네이티브 앱 키**
3. 형식을 검증한다.
   - 앞뒤 공백을 지운다. `kakao1234…`처럼 접두어를 붙여 입력했으면 `kakao`를 뗀다.
   - 남은 값은 32자리 16진수여야 한다. 대문자가 섞여 있으면 소문자로 바꾸고 바꿨다고 알린다.
   - 길이가 다르거나 16진수가 아닌 문자가 있으면 다시 받는다. 틀린 키로 파일을 고치면 나중에 원인을 찾기 어렵다.
   - REST API 키, JavaScript 키도 겉모습이 같다. 잘못된 키를 넣으면 로그인 후 앱으로 돌아오지 못하므로 "네이티브 앱 키가 맞는지" 한 번 짚어준다.

**카카오 앱 ID**

- 먼저 `functions/.env`에 `KAKAO_APP_ID=`가 있는지 찾는다. 있으면 그 값을 쓸지 확인한다.
- 없으면 받는다. 위치: 카카오 디벨로퍼스 **앱 관리 페이지 상단** 또는 **앱 목록**에 보이는 앱 ID.
- 숫자로만 되어 있어야 한다. 앞뒤 공백을 지우고, 숫자가 아닌 문자가 있으면 다시 받는다.
- 네이티브 앱 키와 다른 값이다. 32자리 16진수를 입력했으면 앱 키를 잘못 넣은 것이므로 다시 받는다.

**Firebase 프로젝트 ID**

- 먼저 `.firebaserc`의 `projects.default`, `lib/firebase_options.dart`의 `projectId`를 찾는다. 있으면 그 값을 쓸지 확인한다.
- 없으면 `firebase projects:list`로 목록을 보여주고 고르게 한다. CLI를 쓸 수 없으면 직접 받는다. 위치: **Firebase 콘솔 > 프로젝트 설정 > 일반 > 프로젝트 ID**
- 프로젝트 "이름"이 아니라 "ID"다. ID는 소문자, 숫자, 하이픈으로 되어 있다.

### 4. 단계 실행

- 선택한 단계의 지침 파일을 읽고 그대로 따른다. 지침 파일은 필요할 때만 읽는다.
- **전체**를 골랐으면 표 순서대로 진행한다.
  - 각 단계가 끝날 때마다 한두 줄로 진행 상황을 알린다. 예: "✅ 1단계 완료 – 다음은 2단계입니다."
  - 어떤 단계가 실패하면 그 자리에서 멈추고, 원인과 해결 방법을 알린다. 다음 단계가 앞 단계 결과에 의존하기 때문이다.

### 5. 완료 보고

모든 실행이 끝나면 한국어로 짧게 정리한다.

- 진행한 단계
- 변경한 파일과 변경 내용 요약 (이미 설정되어 있어 건너뛴 항목도 표시)
- 사용자가 직접 해야 할 일 (예: 콘솔 설정, `firebase login`)
- 다음에 진행할 수 있는 단계. 마지막 단계까지 끝났으면 기기에서 `flutter run`으로 로그인을 테스트해 보라고 안내한다.

## 화면 연결 기준

이 스킬은 화면을 새로 만들지 않는다. 로그인 기능(서비스, 버튼)을 만들고, 이미 있는 화면에 연결한다. 처음 판단한 결과를 이후 단계에도 그대로 쓴다.

- **스타터 프로젝트** (GitHub `ExplainingDeveloper/2026-flutter-kakao-login-firebase`의 main 브랜치)
  - 판단 기준: `lib/` 안에 `// TODO(카카오 N단계)` 표시가 있다.
  - 할 일: 각 단계의 지침대로, 해당 단계 번호가 적힌 TODO 자리에 코드를 연결한다. 연결이 끝난 TODO 주석은 지운다.
  - 단계 번호가 다른 TODO는 건드리지 않는다. 나중 단계에서 쓴다.
  - 화면 흐름: 로그인 화면 → 홈 화면(사용자 정보, 로그아웃, 회원 탈퇴)
- **그 외 프로젝트** (사용자 자신의 앱)
  - 화면 파일을 만들거나 고치지 않는다. 사용자가 만든 화면, 라우터, 상태 관리를 망가뜨릴 수 있다.
  - 서비스 메서드와 버튼 위젯만 만들고, 기존 화면에 붙이는 사용 예시를 완료 보고에 적는다.
  - 예외: `main.dart`가 Flutter 기본 템플릿(`Hello World`나 카운터 예제) 그대로라면, 4단계에서 그 자리에 버튼만 넣어 동작을 확인할 수 있게 한다.
  - 사용자가 화면도 만들어 달라고 하면 그 요청을 따른다.

## 작업 원칙

- **다시 실행해도 안전하게**: 이 스킬은 여러 번 실행될 수 있다. 이미 있는 설정은 중복으로 추가하지 않는다. 값만 다르면 값만 바꾼다.
- **기존 설정 보존**: 파일 전체를 새로 쓰지 않는다. 필요한 부분만 Edit로 고친다. 사용자 프로젝트에는 다른 SDK 설정이 있을 수 있다. 예외는 이 스킬이 새로 만드는 파일(`functions/index.js` 등)이 아직 없을 때뿐이다.
- **수정 전 확인**: 파일을 먼저 읽고 현재 상태를 파악한 뒤 수정한다.
- **카카오 패키지 import는 설치된 패키지에 맞춘다**: 코드 예시는 `package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart`를 쓴다. 프로젝트에 전체 패키지(`kakao_flutter_sdk`)만 있으면 `package:kakao_flutter_sdk/kakao_flutter_sdk.dart`로 바꾼다.
- **`User` 이름 충돌**: 카카오 SDK와 `firebase_auth`가 둘 다 `User` 클래스를 내보낸다. 두 패키지를 같은 파일에서 import하면 카카오 쪽에 `hide User`를 붙인다. 카카오 `User`가 필요한 파일은 Firebase 쪽을 `as fb`로 가져온다.
- **대화형 명령은 사용자에게 맡긴다**: `firebase login`처럼 브라우저 로그인이나 선택 입력이 필요한 명령은 에이전트가 실행하지 않는다. 사용자에게 터미널에서 실행해 달라고 하고, 끝났다고 하면 결과를 확인한다.
- **Firebase 설정 파일과 공개 저장소**: `lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`, `.firebaserc`, `functions/.env`에는 내 Firebase 프로젝트와 카카오 앱 정보가 들어간다. 비밀번호 같은 비밀 값은 아니지만, 공개 저장소에 올리면 다른 사람이 내 프로젝트로 앱을 실행하게 된다. 프로젝트의 `.gitignore`에 이미 들어 있는지 완료 보고에서 한 줄로 알려준다. `.gitignore`를 고칠지는 사용자가 정한다.
