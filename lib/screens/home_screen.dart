import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

/// 홈 화면: 로그인한 사용자 정보를 보여준다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _user = AuthService().currentUser;

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

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: _buildProfile(
        context,
        nickname: _user?.displayName ?? '닉네임 없음',
        userId: _user?.uid ?? '-',
        imageUrl: _user?.photoURL,
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context, {
    required String nickname,
    required String userId,
    String? imageUrl,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(nickname, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Firebase UID $userId',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _logout,
                child: const Text('로그아웃'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _unlink,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('회원 탈퇴'),
            ),
          ],
        ),
      ),
    );
  }
}
