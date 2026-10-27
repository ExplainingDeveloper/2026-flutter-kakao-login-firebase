# 4단계: 로그인 로직 (카카오 로그인 → 서버 함수 → Firebase 로그인)

## 목적

로그인 버튼 하나로 아래 흐름을 실행한다.

1. **카카오 로그인**: 카카오톡이 있으면 카카오톡으로, 없거나 실패하면 카카오계정(브라우저)으로 로그인한다.
2. **서버 함수 호출**: 받은 카카오 액세스 토큰을 3단계의 `kakaoLogin` 함수에 보낸다.
3. **Firebase 로그인**: 함수가 돌려준 커스텀 토큰으로 `signInWithCustomToken`을 호출한다.

로그인에 성공하면 Firebase가 로그인 상태를 기기에 저장한다. 6단계 자동 로그인은 이 상태를 쓴다.

## 사전 확인

- `pubspec.yaml`에 `kakao_flutter_sdk_user`, `firebase_auth`, `cloud_functions`가 있고, `main.dart`에 `Firebase.initializeApp(`과 `KakaoSdk.init(`이 있는지 확인한다. 없으면 2단계가 먼저다.
- 3단계 함수가 배포됐는지 확인한다 (`firebase functions:list`에 `kakaoLogin`). 배포 전이어도 코드는 만들 수 있지만, 로그인 테스트는 배포 뒤에 된다고 알린다.

## A. 인증 서비스 파일

`lib/services/auth_service.dart`를 만든다. 프로젝트에 정해진 폴더 구조가 있으면 따른다. 같은 역할의 파일이 있으면 새로 만들지 않고 내용을 확인한다.

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;

/// 카카오 로그인 + Firebase 로그인
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;

  /// 카카오로 로그인한 뒤, 그 결과로 Firebase에 로그인한다.
  ///
  /// 사용자가 카카오 로그인을 취소하면 null을 반환한다.
  /// 그 밖의 오류는 호출한 쪽에서 처리할 수 있도록 그대로 던진다.
  Future<User?> signInWithKakao() async {
    final kakaoToken = await _loginWithKakao();
    if (kakaoToken == null) return null;

    // 서버(kakaoLogin 함수)가 카카오 토큰을 확인하고 Firebase 커스텀 토큰을 준다.
    final result = await _functions
        .httpsCallable('kakaoLogin')
        .call({'accessToken': kakaoToken.accessToken});
    final data = Map<String, dynamic>.from(result.data as Map);

    final credential = await _auth.signInWithCustomToken(data['customToken'] as String);
    return credential.user;
  }

  /// 카카오톡이 설치되어 있으면 카카오톡으로, 아니면 카카오계정으로 로그인한다.
  Future<OAuthToken?> _loginWithKakao() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (error) {
        debugPrint('카카오톡으로 로그인 실패: $error');

        // 사용자가 카카오톡 동의 화면에서 취소한 경우에는 의도적인 취소로 보고
        // 카카오계정 로그인을 시도하지 않는다.
        if (_isCanceled(error)) return null;

        // 카카오톡에 연결된 카카오계정이 없는 경우 등은 카카오계정으로 로그인한다.
        return _loginWithKakaoAccount();
      }
    }
    return _loginWithKakaoAccount();
  }

  Future<OAuthToken?> _loginWithKakaoAccount() async {
    try {
      return await UserApi.instance.loginWithKakaoAccount();
    } catch (error) {
      debugPrint('카카오계정으로 로그인 실패: $error');
      if (_isCanceled(error)) return null;
      rethrow;
    }
  }

  bool _isCanceled(Object error) =>
      error is PlatformException && error.code == 'CANCELED';
}
```

이 구조를 쓰는 이유:
- **카카오 쪽 `User`를 숨긴다(`hide User`).** 카카오 SDK와 `firebase_auth`가 둘 다 `User`를 내보낸다. 이 파일에서 `User`는 Firebase 사용자다.
- **취소는 null로 반환한다.** 취소는 오류가 아니다. 화면에서 "로그인 실패"를 띄우지 않게 구분한다.
- **카카오톡에서 취소했으면 카카오계정 로그인을 시도하지 않는다.** 취소했는데 브라우저가 또 열리면 사용자가 당황한다. 카카오 공식 샘플과 같은 처리다.
- **서버 응답은 `Map`으로 바꿔서 읽는다.** 플랫폼 채널을 거친 결과는 `Map<Object?, Object?>`로 올 수 있어서, 바로 `Map<String, dynamic>`으로 캐스팅하면 실행 중에 에러가 날 수 있다.
- **로그는 `debugPrint`를 쓴다.** `flutter_lints`의 `avoid_print` 경고를 피한다.

## B. 로그인 버튼

0단계에서 받은 공식 버튼 이미지가 `assets/images/kakao/`에 있는지 확인한다.
- **PNG가 있으면** 이미지 버튼을 만든다 (B-1).
- **없으면** 동작 확인용 임시 텍스트 버튼을 만든다 (B-2). 완료 보고에 0단계 D의 이미지 받는 방법을 다시 안내한다.

이미 `KakaoLoginButton`이 있으면 새 파일을 만들지 않는다. 버튼 모양(`build`)과 클래스 주석만 상황에 맞게 바꾼다.

### B-1. 이미지 버튼

1. **이미지 고르기**
   - PNG가 하나면 그것을 쓴다.
   - 여러 개면 파일 목록과 각 이미지의 픽셀 크기를 보여주고 사용자에게 고르게 한다.
     - 크기 확인: macOS는 `sips -g pixelWidth -g pixelHeight <파일>`. 다른 OS는 PNG 파일 헤더에서 읽는다(17~20번째 바이트가 가로, 21~24번째 바이트가 세로, 빅엔디언). 구할 수 없으면 파일 이름만 보여준다.
     - 공식 파일 이름의 `large`/`medium`/`small`은 버튼 크기 종류다. 이름만으로는 화면에 맞을지 판단하기 어렵다.
     - 물어볼 수 없으면 가로 픽셀이 가장 큰 파일을 고르고, 그렇게 골랐다고 알린다.
   - 가로가 100픽셀보다 작은 이미지는 전체 버튼이 아니라 심볼 아이콘일 가능성이 높다고 경고한다. 그래도 진행은 한다.

2. **pubspec.yaml에 에셋 등록** (`flutter:` 섹션, 들여쓰기 공백 2칸)
   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - assets/images/kakao/
   ```
   `assets:` 목록이 이미 있으면 항목만 추가한다. 다른 설정은 그대로 둔다.

3. **버튼 위젯** – `lib/widgets/kakao_login_button.dart`

```dart
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// 카카오 로그인 버튼 (공식 버튼 이미지)
class KakaoLoginButton extends StatelessWidget {
  const KakaoLoginButton({super.key, this.onSuccess});

  /// 로그인에 성공했을 때 호출된다. 없으면 "로그인 성공" 메시지만 띄운다.
  final VoidCallback? onSuccess;

  Future<void> _onPressed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = await AuthService().signInWithKakao();
      if (user == null) {
        messenger.showSnackBar(const SnackBar(content: Text('로그인을 취소했어요')));
        return;
      }
      if (!context.mounted) return;
      if (onSuccess != null) {
        onSuccess!();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('로그인 성공!')));
      }
    } catch (error) {
      debugPrint('카카오 로그인 실패: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onPressed(context),
      child: Image.asset(
        'assets/images/kakao/<파일명>.png',
        height: 48,
        semanticLabel: '카카오 로그인',
      ),
    );
  }
}
```

- `<파일명>`은 실제 파일 이름으로 바꾸고, 파일이 실제로 있는지 확인한다.
- `height`만 지정한다. 너비를 정하지 않아야 원본 비율이 유지된다. 카카오 디자인 가이드는 버튼을 늘리거나 찌그러뜨리는 것을 금지한다.
- 사용자에게는 쉬운 말로 알리고, 자세한 오류는 `debugPrint`로만 남긴다.

### B-2. 임시 텍스트 버튼 (이미지가 없을 때)

B-1과 같은 파일을 만들되, 클래스 주석은 `/// 카카오 로그인 버튼 (임시 디자인)`으로 하고 `build`만 아래로 바꾼다. `pubspec.yaml`에 에셋은 등록하지 않는다.

```dart
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _onPressed(context),
      child: const Text('카카오 로그인'),
    );
  }
```

## C. 화면에 연결

SKILL.md "화면 연결 기준"에 따른다.

### 스타터 프로젝트

`lib/screens/login_screen.dart`의 `// TODO(카카오 4단계): 카카오 로그인 버튼` 줄을 버튼으로 바꾸고 import를 추가한다. `TODO(카카오 5단계)` 줄은 남겨 둔다. 이 단계에서는 로그인에 성공하면 "로그인 성공!" 메시지만 뜬다.

```dart
import '../widgets/kakao_login_button.dart';
```

```dart
              const KakaoLoginButton(),
              // TODO(카카오 5단계): 로그인 성공 시 홈 화면으로 이동
              const SizedBox(height: 48),
```

### 그 외 프로젝트

- `main.dart`가 기본 템플릿 그대로면 그 자리에 `KakaoLoginButton()`을 넣는다. `Scaffold`가 있어야 SnackBar가 뜬다.
- 실제 화면이 있는 앱이면 화면 코드를 바꾸지 않고, 아래 사용 예시를 완료 보고에 적는다.

```dart
KakaoLoginButton(
  onSuccess: () {
    // 로그인 성공 후 이동할 화면
  },
)
```

## 검증

- 이미지 버튼이면 `Image.asset` 경로의 파일이 실제로 있는지, `pubspec.yaml`에 에셋 폴더가 등록됐는지 확인한다.
- `flutter analyze`를 실행한다. 에러와 경고가 없어야 한다.
- 앱 실행은 하지 않는다. 실제 로그인은 기기와 콘솔 설정, 배포된 함수가 필요해서 사용자가 직접 확인한다.

## 완료 보고에 포함할 내용

- 만든 파일과 버튼을 넣은 위치, 사용한 이미지 파일 이름 (또는 임시 버튼)
- 흐름 한 줄: "카카오 로그인 → kakaoLogin 함수 → 커스텀 토큰 → Firebase 로그인"
- 로그인이 실패할 때 확인할 곳
  - 카카오 쪽: 콘솔의 카카오 로그인 ON, 플랫폼 등록(패키지명·키 해시·번들 ID), 네이티브 앱 키가 세 곳에서 같은지
  - 서버 쪽: `firebase functions:log`. `signBlob` 권한 에러면 3단계 C, `permission-denied`면 `functions/.env`의 `KAKAO_APP_ID`가 이 앱의 ID인지 확인
  - Firebase 쪽: 0단계 F-3(Authentication 시작하기)을 했는지
- 테스트 방법: 기기나 에뮬레이터에서 `flutter run` 후 버튼을 누르고, Firebase 콘솔 **Authentication > 사용자** 목록에 `kakao:<회원번호>` 사용자가 생겼는지 본다.
