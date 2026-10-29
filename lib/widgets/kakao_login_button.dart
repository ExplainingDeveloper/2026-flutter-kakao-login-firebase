import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class KakaoLoginButton extends StatelessWidget {
  const KakaoLoginButton({super.key, this.onSuccess});

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
      onSuccess?.call();
    } catch (error) {
      debugPrint('카카오 로그인 실패: $error');
      if (!context.mounted) return;
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
        'assets/images/kakao/kakao_login_kr_large.png',
        height: 48,
        semanticLabel: '카카오 로그인',
      ),
    );
  }
}
