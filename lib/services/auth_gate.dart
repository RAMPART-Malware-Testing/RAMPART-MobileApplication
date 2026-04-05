import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/screens/login_screen.dart';
import 'package:rampart/screens/main_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  final _storage = const FlutterSecureStorage();

  Future<String?> _checkLoginStatus() async {
    return await _storage.read(key: 'token');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final String? token = snapshot.data;
        
        if (token != null && token.isNotEmpty) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}