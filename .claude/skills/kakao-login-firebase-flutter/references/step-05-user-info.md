# 5단계: Firebase 사용자 정보 (홈 화면)

## 목적

로그인한 Firebase 사용자의 정보를 보여준다.

| 값 | 코드 | 어디서 오나 |
|---|---|---|
| UID | `user.uid` | 3단계 서버가 정한 `kakao:<카카오 회원번호>` |
| 이름 | `user.displayName` | 서버가 카카오 프로필 닉네임으로 넣은 값 |
| 사진 | `user.photoURL` | 서버가 카카오 프로필 사진으로 넣은 값 |

카카오 API를 앱에서 다시 부르지 않는다. 서버가 로그인할 때 카카오 프로필을 Firebase 사용자에 넣어 두었기 때문이다. 앱의 다른 곳(Firestore 규칙, 다른 함수)에서도 같은 Firebase 사용자 정보를 쓰게 된다.

동의항목을 켜지 않았거나 사용자가 동의하지 않으면 이름과 사진은 `null`이다.

## 사전 확인

`lib/services/auth_service.dart`(4단계)가 있어야 한다.

## A. 서비스에 getter 추가

`AuthService`에 아래를 추가한다. 이미 있으면 건너뛴다.

```dart
  /// 지금 로그인한 Firebase 사용자. 로그인 전이면 null.
  User? get currentUser => _auth.currentUser;
```

## B. 화면에 연결

### 스타터 프로젝트: 홈 화면

`lib/screens/home_screen.dart`를 수정한다.

1. import를 추가한다.
   ```dart
   import 'package:firebase_auth/firebase_auth.dart';

   import '../services/auth_service.dart';
   ```
2. `// TODO(카카오 5단계): Firebase 사용자 정보 불러오기` 줄을 아래로 바꾼다.
   ```dart
   final User? _user = AuthService().currentUser;
   ```
3. `build`의 `body:`를 아래로 바꾼다. `_buildProfile`은 스타터에 이미 있다.
   ```dart
         body: _buildProfile(
           context,
           nickname: _user?.displayName ?? '닉네임 없음',
           userId: _user?.uid ?? '-',
           imageUrl: _user?.photoURL,
         ),
   ```

로그인 화면에서 홈으로 이동하게 연결한다. `lib/screens/login_screen.dart`에서 `const KakaoLoginButton(),`과 `// TODO(카카오 5단계)` 줄을 아래로 바꾸고, `import 'home_screen.dart';`를 추가한다.

```dart
              KakaoLoginButton(
                onSuccess: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
              ),
```

`pushReplacement`를 쓰면 홈 화면에서 뒤로 가기를 눌러도 로그인 화면으로 돌아가지 않는다.

### 그 외 프로젝트

화면 파일을 고치지 않는다. 사용 예시를 완료 보고에 적는다.

```dart
final user = AuthService().currentUser;
final name = user?.displayName;
final photo = user?.photoURL;
final uid = user?.uid; // kakao:<회원번호>
```

## 검증

- `flutter analyze`를 실행한다. 에러와 경고가 없어야 한다.
- 스타터 프로젝트에서는 7단계 이후 `login_screen.dart`와 `home_screen.dart`가 서로를 import하게 된다. Dart에서는 정상이다.

## 완료 보고에 포함할 내용

- 추가한 getter와 연결한 화면
- 화면 흐름: "로그인 화면 → (로그인 성공) → 홈 화면(사진, 이름, Firebase UID)"
- 이름이나 사진이 안 나오면 카카오 콘솔 **[카카오 로그인] > [동의항목]**을 확인하라는 안내. 동의항목을 나중에 켰다면, 다시 로그인해야 서버가 새 정보를 Firebase 사용자에 넣는다.
- Firebase 콘솔 **Authentication > 사용자**에서도 같은 사용자를 볼 수 있다는 안내
