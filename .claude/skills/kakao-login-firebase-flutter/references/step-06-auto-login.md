# 6단계: 자동 로그인 (Firebase 로그인 상태 확인)

## 목적

앱을 다시 켰을 때 Firebase 로그인 상태가 남아 있으면 로그인 화면을 건너뛰고 바로 홈 화면으로 보낸다.

Firebase는 로그인 상태를 기기에 저장한다. 하지만 **저장된 상태가 있다고 계정이 아직 살아 있는 것은 아니다.** 관리자가 Firebase 콘솔에서 사용자를 지웠거나 정지했을 수 있다. 그래서 두 단계로 확인한다.

1. `authStateChanges().first`: 저장된 로그인 상태가 있는지
2. `user.reload()`: 서버에 그 계정이 아직 있는지

카카오 토큰은 여기서 확인하지 않는다. 이 앱의 로그인 상태는 Firebase 로그인이다. 카카오 토큰은 7단계 연결 끊기 때만 필요하고, 그때 확인한다.

## 사전 확인

`lib/services/auth_service.dart`(4단계)가 있어야 한다. 스타터 프로젝트라면 5단계도 끝나 있어야 한다.

## A. 서비스에 메서드 추가

`AuthService`에 아래를 추가한다. 이미 있으면 건너뛴다. 파일 맨 위에 `import 'dart:async';`도 추가한다 (`TimeoutException`).

```dart
  /// 저장된 Firebase 로그인 상태가 있고 계정이 살아 있으면 true.
  Future<bool> isSignedIn() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return false;
    try {
      // 서버에 계정이 아직 있는지 확인한다. 느린 네트워크에서 시작 화면이 오래 멈추지 않도록 5초까지만 기다린다.
      await user.reload().timeout(const Duration(seconds: 5));
      return true;
    } on FirebaseAuthException catch (error) {
      if (const ['user-not-found', 'user-disabled', 'user-token-expired'].contains(error.code)) {
        debugPrint('Firebase 계정을 쓸 수 없어요: ${error.code}');
        await _auth.signOut();
        return false;
      }
      // 네트워크 문제 등은 저장된 로그인 상태를 믿는다.
      debugPrint('Firebase 사용자 확인 실패: $error');
      return true;
    } on TimeoutException {
      return true;
    }
  }
```

판단 기준:
- **계정이 없거나 정지됐으면** 기기의 로그인 상태도 지우고 로그인 화면으로 보낸다.
- **인터넷이 안 되거나 느리면** 저장된 로그인 상태를 믿고 홈으로 보낸다. Firebase는 오프라인에서도 로그인 상태를 유지하도록 만들어져 있어서, 오프라인이라는 이유로 로그아웃시키면 사용자만 불편하다.
- 5초는 이 스킬이 정한 값이다. 공식 권장값은 아니다.

## B. 시작 화면 결정

### 스타터 프로젝트: main.dart 수정

`// TODO(카카오 6단계)` 두 줄을 아래처럼 바꾼다. `Firebase.initializeApp`과 `KakaoSdk.init`은 2단계 그대로 두고, 그 **뒤에** 로그인 상태를 확인한다.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // 2단계 그대로
  await KakaoSdk.init(nativeAppKey: '...'); // 2단계 그대로

  // 저장된 Firebase 로그인 상태가 유효하면 바로 홈 화면으로 시작한다.
  final isLoggedIn = await AuthService().isSignedIn();

  runApp(MainApp(isLoggedIn: isLoggedIn));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title, theme 등 기존 설정은 그대로
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
```

- `Firebase.initializeApp`은 반드시 `isSignedIn()`보다 먼저다. 초기화 전에는 Firebase API를 쓸 수 없다.
- 2단계에서 넣은 키 값과 주석은 그대로 둔다. 예시의 `'...'`로 바꾸지 않는다.
- `services/auth_service.dart`, `screens/home_screen.dart` import를 추가한다.

### 그 외 프로젝트

`main.dart`나 라우팅 코드를 바꾸지 않는다. 사용 예시를 완료 보고에 적는다.

```dart
final isLoggedIn = await AuthService().isSignedIn();
// true → 메인 화면, false → 로그인 화면
```

로그인 상태 변화에 따라 화면이 바뀌어야 하는 앱이면 `FirebaseAuth.instance.authStateChanges()`를 `StreamBuilder`로 쓰는 방법도 함께 알려준다.

## 검증

- `flutter analyze`를 실행한다. 에러와 경고가 없어야 한다.
- `main()`에서 `Firebase.initializeApp` → `KakaoSdk.init` → `isSignedIn()` → `runApp()` 순서인지 확인한다.

## 완료 보고에 포함할 내용

- 추가한 메서드와 `main.dart` 변경 부분
- 동작 요약: "앱 시작 → Firebase 로그인 상태 있음 + 계정 살아 있음 → 홈 / 그 외 → 로그인 화면"
- 테스트 방법: 로그인한 뒤 앱을 완전히 종료하고 다시 실행하면 바로 홈 화면이 떠야 한다. Firebase 콘솔에서 그 사용자를 삭제한 뒤 앱을 다시 켜면 로그인 화면이 떠야 한다.
