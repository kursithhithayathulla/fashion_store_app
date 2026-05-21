import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'main_layout.dart';

/// AuthWrapper handles navigation based on authentication state
/// Shows Login screen if user is not authenticated
/// Shows Main layout if user is authenticated
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, show main layout
        if (snapshot.hasData && snapshot.data != null) {
          return const MainLayout();
        }

        // If user is not logged in, show login screen
        return const LoginScreen();
      },
    );
  }
}
