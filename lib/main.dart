import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 연결 (flutterfire configure가 만든 설정 사용)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 카카오 SDK 초기화
  await KakaoSdk.init(nativeAppKey: 'YOUR_NATIVE_APP_KEY');

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
      title: '카카오 로그인 + Firebase',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFFEE500)),
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
