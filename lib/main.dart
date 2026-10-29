import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await KakaoSdk.init(nativeAppKey: '61a82db8b67292beb70f42a6a31ecefb');

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
