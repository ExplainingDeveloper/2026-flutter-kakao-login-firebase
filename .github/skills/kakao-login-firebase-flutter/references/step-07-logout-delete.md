# 7단계: 로그아웃 / 회원 탈퇴

## 목적

| 기능 | 하는 일 |
|---|---|
| 로그아웃 | 기기의 Firebase 로그인 상태와 카카오 토큰을 지운다. Firebase 계정과 카카오 연결은 그대로 남는다. 다시 로그인하면 같은 Firebase 사용자로 들어온다. |
| 회원 탈퇴 | 서버에서 Firebase 계정을 삭제하고, 카카오와 앱의 연결을 끊는다. 다시 로그인하면 새 사용자로 시작한다. |

iOS App Store 심사 기준은 앱 안에서 회원가입을 받으면 앱 안에서 계정 삭제도 할 수 있어야 한다고 요구한다 (App Review Guidelines 5.1.1(v)).

## 사전 확인

- `lib/services/auth_service.dart`(4단계)가 있어야 한다.
- 3단계의 `deleteAccount` 함수가 배포돼 있어야 탈퇴가 동작한다.

## A. 서비스에 메서드 추가

`AuthService`에 아래를 추가한다. 이미 있으면 건너뛴다.

```dart
  /// 로그아웃: 기기의 Firebase 로그인 상태와 카카오 토큰을 지운다.
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      // 카카오 로그아웃은 서버 요청이 실패해도 기기의 카카오 토큰을 지운다.
      await UserApi.instance.logout();
    } catch (error) {
      debugPrint('카카오 로그아웃 요청 실패 (기기의 토큰은 삭제됨): $error');
    }
  }

  /// 회원 탈퇴: Firebase 계정 삭제 → 카카오 연결 끊기 → 로그아웃.
  ///
  /// 카카오 토큰이 만료돼 다시 로그인해야 하는데 사용자가 취소하면 false를 반환한다.
  /// Firebase 계정 삭제가 실패하면 오류를 그대로 던진다.
  Future<bool> deleteAccount() async {
    // 1. 카카오 연결을 끊으려면 유효한 카카오 토큰이 필요하다. 없으면 카카오 로그인을 다시 받는다.
    if (!await _hasValidKakaoToken()) {
      if (await _loginWithKakao() == null) return false;
    }

    // 다시 로그인할 때 다른 카카오 계정을 고를 수 있다. 지금 Firebase 사용자와 같은 사람인지 확인한다.
    final kakaoInfo = await UserApi.instance.accessTokenInfo();
    if ('kakao:${kakaoInfo.id}' != _auth.currentUser?.uid) {
      throw StateError('지금 로그인한 계정과 다른 카카오 계정이에요.');
    }

    // 2. 서버에서 Firebase 계정 삭제
    await _functions.httpsCallable('deleteAccount').call();

    // 3. 카카오 연결 끊기
    try {
      await UserApi.instance.unlink();
    } catch (error) {
      // Firebase 계정은 이미 지워졌다. 카카오 연결만 남았으므로 탈퇴는 계속 진행한다.
      debugPrint('카카오 연결 끊기 실패: $error');
    }

    // 4. 기기에 남은 로그인 상태 정리
    await _auth.signOut();
    return true;
  }

  Future<bool> _hasValidKakaoToken() async {
    if (!await AuthApi.instance.hasToken()) return false;
    try {
      await UserApi.instance.accessTokenInfo();
      return true;
    } catch (error) {
      debugPrint('카카오 토큰 확인 실패: $error');
      return false;
    }
  }
```

이 순서로 하는 이유:
- **카카오 토큰부터 확인한다.** Firebase 로그인은 오래 유지되지만 카카오 리프레시 토큰은 만료될 수 있다. 토큰 없이 진행하면 Firebase 계정만 지워지고 카카오 연결은 못 끊는다. 그래서 먼저 확인하고, 필요하면 카카오 로그인을 다시 받는다.
- **같은 사람인지 확인한다.** 다시 로그인할 때 사용자가 다른 카카오 계정을 고르면, 엉뚱한 카카오 연결을 끊게 된다. 카카오 회원번호로 만든 UID(`kakao:<회원번호>`)와 지금 Firebase 사용자의 UID를 비교한다.
- **Firebase 계정을 먼저 지운다.** 탈퇴에서 가장 중요한 것은 우리 서비스의 회원 데이터를 지우는 일이다. 반대로 카카오 연결을 먼저 끊었는데 서버 삭제가 실패하면, 카카오는 끊겼는데 Firebase 계정은 남는다.
- **카카오 연결 끊기가 실패해도 탈퇴는 끝낸다.** Firebase 계정은 이미 없다. 카카오 연결만 남아 있으면 다음 로그인 때 동의 화면 없이 새 Firebase 사용자가 만들어질 뿐이다.
- **계정 삭제는 서버 함수로 한다.** 앱에서 `user.delete()`를 부르면 로그인한 지 오래된 경우 `requires-recent-login` 에러가 나서 다시 로그인을 받아야 한다. 서버(Admin SDK)에서 지우면 이 문제가 없다.

## B. 화면 배치

### 스타터 프로젝트: 홈 화면 버튼 연결

로그아웃과 회원 탈퇴 버튼은 스타터의 `lib/screens/home_screen.dart`에 이미 있다. 빈 메서드만 채운다.

1. `import 'login_screen.dart';`를 추가한다.
2. `// TODO(카카오 7단계)` 주석과 빈 `_logout`, `_unlink` 메서드를 아래로 바꾼다.

```dart
  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    _goToLogin();
  }

  Future<void> _unlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('계정을 삭제하고 카카오 계정과의 연결을 끊을까요?\n되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await AuthService().deleteAccount();
      if (!deleted || !mounted) return;
      _goToLogin();
    } catch (error) {
      debugPrint('회원 탈퇴 실패: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탈퇴에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  /// 이전 화면 기록을 모두 지우고 로그인 화면으로 이동한다.
  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
```

- **탈퇴는 확인 창을 먼저 띄운다.** 되돌릴 수 없는 동작이라 실수로 누르는 것을 막는다.
- **이동할 때 `pushAndRemoveUntil`을 쓴다.** 로그아웃한 뒤 뒤로 가기로 홈 화면에 돌아오지 못하게 한다.

### 그 외 프로젝트

화면 파일을 만들지 않는다. 사용 예시를 완료 보고에 적는다.

```dart
await AuthService().signOut();                    // 로그아웃
final deleted = await AuthService().deleteAccount(); // 회원 탈퇴 (취소하면 false, 실패하면 예외)
```

## 검증

- `flutter analyze`를 실행한다. 에러와 경고가 없어야 한다.
- `await` 뒤에 `context`를 쓰기 전에 `mounted`를 확인했는지 본다.

## 완료 보고에 포함할 내용

- 추가한 메서드와 연결한 버튼
- 로그아웃과 탈퇴의 차이를 한 줄로
- Firestore 등 다른 Firebase 서비스에 회원 데이터를 저장한다면, `deleteAccount` 함수에서 그 데이터도 함께 지워야 한다는 안내
- 테스트 방법
  - 로그아웃 후 다시 로그인하면 Firebase 콘솔의 같은 사용자(`kakao:<회원번호>`)로 들어온다.
  - 탈퇴하면 Firebase 콘솔 **Authentication > 사용자** 목록에서 그 사용자가 사라진다.
