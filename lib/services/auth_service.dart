import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithKakao() async {
    final kakaoToken = await _loginWithKakao();
    if (kakaoToken == null) return null;

    final result = await _functions.httpsCallable('kakaoLogin').call({
      'accessToken': kakaoToken.accessToken,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final credential = await _auth.signInWithCustomToken(
      data['customToken'] as String,
    );
    return credential.user;
  }

  Future<bool> isSignedIn() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return false;
    try {
      await user.reload().timeout(const Duration(seconds: 5));
      return true;
    } on FirebaseAuthException catch (error) {
      if (const [
        'user-not-found',
        'user-disabled',
        'user-token-expired',
      ].contains(error.code)) {
        await _auth.signOut();
        return false;
      }
      debugPrint('Firebase 사용자 확인 실패: $error');
      return true;
    } on TimeoutException {
      return true;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await UserApi.instance.logout();
    } catch (error) {
      debugPrint('카카오 로그아웃 요청 실패: $error');
    }
  }

  Future<bool> deleteAccount() async {
    if (!await _hasValidKakaoToken()) {
      if (await _loginWithKakao() == null) return false;
    }

    final kakaoInfo = await UserApi.instance.accessTokenInfo();
    if ('kakao:${kakaoInfo.id}' != _auth.currentUser?.uid) {
      throw StateError('지금 로그인한 계정과 다른 카카오 계정이에요.');
    }

    await _functions.httpsCallable('deleteAccount').call();
    try {
      await UserApi.instance.unlink();
    } catch (error) {
      debugPrint('카카오 연결 끊기 실패: $error');
    }
    await _auth.signOut();
    return true;
  }

  Future<OAuthToken?> _loginWithKakao() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (error) {
        debugPrint('카카오톡으로 로그인 실패: $error');
        if (_isCanceled(error)) return null;
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

  bool _isCanceled(Object error) =>
      error is PlatformException && error.code == 'CANCELED';
}
