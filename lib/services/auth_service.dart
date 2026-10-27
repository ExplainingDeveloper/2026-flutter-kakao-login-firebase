import 'dart:async';

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

  /// 지금 로그인한 Firebase 사용자. 로그인 전이면 null.
  User? get currentUser => _auth.currentUser;

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
