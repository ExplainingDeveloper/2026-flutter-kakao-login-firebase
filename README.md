# 2026 Flutter 카카오 로그인 + Firebase

Flutter 앱에 **카카오 로그인**을 붙이고, 로그인한 사용자를 **Firebase Authentication** 사용자로 연결하는 프로젝트예요.
AI 코딩 에이전트용 **스킬**(`kakao-login-firebase-flutter`)이 함께 들어 있어서, 에이전트에게 단계 번호만 말하면 설정과 코드를 대신 작성해 줘요.

Firebase 없이 카카오 로그인만 붙이려면 [2026-flutter-kakao-login](https://github.com/ExplainingDeveloper/2026-flutter-kakao-login)을 보세요.

## 어떻게 연결되나요

카카오는 Firebase가 기본으로 지원하는 로그인이 아니에요. 그래서 서버(Firebase Cloud Functions)가 중간에서 카카오 토큰을 확인하고 Firebase 로그인용 토큰(커스텀 토큰)을 만들어 줘요.

```
앱: 카카오 로그인 → 카카오 액세스 토큰
앱 → Cloud Functions(kakaoLogin): 카카오 토큰 전달
함수: 카카오 서버에 토큰 확인 (우리 앱에서 발급된 토큰인지까지) → Firebase 커스텀 토큰 발급
앱: signInWithCustomToken → Firebase 로그인 완료
```

## 브랜치

| 브랜치 | 내용 | 언제 |
|---|---|---|
| `main` | **시작 상태.** 카카오·Firebase 기능 없이 기본 화면만 있어요. | 영상을 따라 처음부터 해볼 때 |
| `completed` | **완성본.** 0~7단계를 모두 적용한 코드예요. | 막혔을 때 내 코드와 비교할 때 |

## 준비물

- Flutter 3.38.0 이상 (카카오 Flutter SDK v2 최소 버전)
- Node.js 22 이상 (Firebase CLI, Cloud Functions 배포)
- 카카오 계정, Google 계정
- Firebase **Blaze 요금제** (Cloud Functions에 필요해요. 무료 사용량 안에서는 비용이 나오지 않아요. [요금표](https://firebase.google.com/pricing))

## 시작하기

```bash
git clone https://github.com/ExplainingDeveloper/2026-flutter-kakao-login-firebase.git
cd 2026-flutter-kakao-login-firebase
flutter pub get
```

`main` 브랜치는 로그인 화면과 홈 화면의 기본 UI만 있어요. 기능이 들어갈 자리에는 `// TODO(카카오 N단계)` 표시가 있고, 스킬이 단계마다 이 자리를 채워요.

```
lib/
├── main.dart                 # TODO 2단계(SDK·Firebase 초기화), 6단계(자동 로그인)
└── screens/
    ├── login_screen.dart     # TODO 4단계(로그인 버튼), 5단계(홈으로 이동)
    └── home_screen.dart      # TODO 5단계(사용자 정보), 7단계(로그아웃·탈퇴)
```

### 완성본을 실행해 보려면

```bash
git switch completed
flutter pub get
```

완성본에는 각자의 값이 들어가야 하는 곳이 비어 있어요. 스킬로 해당 단계만 다시 실행하거나 직접 채워 주세요.

| 채울 것 | 위치 | 스킬 단계 |
|---|---|---|
| 카카오 네이티브 앱 키 | `AndroidManifest.xml`, `Info.plist`, `lib/main.dart`의 `YOUR_NATIVE_APP_KEY` (세 곳 모두 같게) | 1, 2 |
| Firebase 연결 | `flutterfire configure` 실행 → `lib/firebase_options.dart` 등 생성 | 2 |
| 함수 설정 | `.firebaserc`, `functions/.env`(`KAKAO_APP_ID`) 만들고 `firebase deploy --only functions` | 3 |

카카오 디벨로퍼스 콘솔 설정과 Firebase 프로젝트 준비(0단계)도 내 계정으로 해 둬야 해요.

## 단계

| 단계 | 내용 | 누가 |
|---|---|---|
| 0 | 카카오 디벨로퍼스(앱, 키, 플랫폼 등록, 로그인 켜기, 동의항목), 버튼 이미지, Firebase 프로젝트·Blaze·CLI | 직접 (스킬이 값 계산·안내) |
| 1 | 커스텀 URL 스킴 (AndroidManifest.xml, Info.plist), 인터넷 권한 | 스킬 |
| 2 | 카카오 SDK·Firebase 설치, `flutterfire configure`, 초기화 | 스킬 |
| 3 | Cloud Functions: 카카오 토큰 확인 → 커스텀 토큰 발급, 회원 삭제 함수, 배포 | 스킬 (권한 설정은 직접) |
| 4 | 로그인 로직 (카카오 → 함수 → Firebase), 로그인 버튼 | 스킬 |
| 5 | Firebase 사용자 정보 (이름, 사진, UID) | 스킬 |
| 6 | 자동 로그인 (Firebase 로그인 상태 확인) | 스킬 |
| 7 | 로그아웃 / 회원 탈퇴 (Firebase 계정 삭제 + 카카오 연결 끊기) | 스킬 |

로그인 버튼 이미지는 [카카오 로그인 리소스 페이지](https://developers.kakao.com/tool/resource/login)에서 받아요.

## 스킬 사용법

같은 스킬이 두 곳에 들어 있어요. 내용은 똑같아요.

- [`.claude/skills/kakao-login-firebase-flutter/`](.claude/skills/kakao-login-firebase-flutter/): Claude Code용
- [`.github/skills/kakao-login-firebase-flutter/`](.github/skills/kakao-login-firebase-flutter/): GitHub Copilot용

스킬을 고칠 때는 두 폴더를 같이 고쳐 주세요.

### Claude Code

```
/kakao-login-firebase-flutter          # 단계 선택 메뉴
/kakao-login-firebase-flutter 3        # 3단계만
/kakao-login-firebase-flutter 전체      # 0~7단계 전부
```

"카카오 Firebase 로그인 3단계 해줘"처럼 말로 해도 돼요.

### GitHub Copilot (VS Code)

채팅창에 `/`를 입력하고 목록에서 `kakao-login-firebase-flutter`를 고르거나, 말로 요청하면 돼요.

## 스킬만 내 프로젝트에 넣기

`kakao-login-firebase-flutter` 폴더 하나만 받으면 돼요.

**어디에 넣나요**
- Claude Code: `.claude/skills/` (이 프로젝트만) · `~/.claude/skills/` (내 컴퓨터 전체)
- GitHub Copilot (VS Code): `.github/skills/` · `.claude/skills/` · `.agents/skills/` (프로젝트) · `~/.copilot/skills/` (내 컴퓨터 전체)

두 도구를 다 쓴다면 `.claude/skills/`에 넣으세요. 둘 다 읽어요.

**터미널 (macOS · Linux)**: 내 Flutter 프로젝트 폴더에서 실행하세요.

```bash
# Claude Code (또는 둘 다 쓸 때)
mkdir -p .claude/skills && curl -sL https://github.com/ExplainingDeveloper/2026-flutter-kakao-login-firebase/archive/refs/heads/main.tar.gz | tar -xz -C .claude/skills --strip-components=3 "2026-flutter-kakao-login-firebase-main/.claude/skills/kakao-login-firebase-flutter"

# GitHub Copilot
mkdir -p .github/skills && curl -sL https://github.com/ExplainingDeveloper/2026-flutter-kakao-login-firebase/archive/refs/heads/main.tar.gz | tar -xz -C .github/skills --strip-components=3 "2026-flutter-kakao-login-firebase-main/.claude/skills/kakao-login-firebase-flutter"
```

**ZIP (Windows 포함 모든 OS)**: [ZIP 다운로드](https://github.com/ExplainingDeveloper/2026-flutter-kakao-login-firebase/archive/refs/heads/main.zip) → 압축 풀기 → `.claude/skills/kakao-login-firebase-flutter` 폴더를 위 위치에 복사. macOS Finder에서는 `Cmd + Shift + .`를 누르면 점으로 시작하는 폴더가 보여요.

내 프로젝트에서 돌리면 스킬은 내 화면 파일을 건드리지 않아요. 로그인 기능(서비스)과 버튼, 서버 함수만 만들고, 화면에 붙이는 예시는 완료 보고에 적어 줘요.

## 공개 저장소에 올릴 때

아래 파일에는 내 Firebase 프로젝트와 카카오 앱 정보가 들어가요. 이 레포의 `.gitignore`에 이미 들어 있어요.

- `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- `.firebaserc`, `functions/.env`

## 참고 문서

- [카카오 로그인 Flutter 가이드](https://developers.kakao.com/docs/ko/kakaologin/flutter)
- [카카오 로그인 REST API (토큰 정보 확인)](https://developers.kakao.com/docs/ko/kakaologin/rest-api)
- [Firebase Flutter 시작하기](https://firebase.google.com/docs/flutter/setup)
- [Firebase 커스텀 토큰 만들기](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
- [Cloud Functions 호출 가능 함수](https://firebase.google.com/docs/functions/callable)
- [Firebase 요금표](https://firebase.google.com/pricing)
