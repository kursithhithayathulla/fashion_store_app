import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'models/user_settings.dart';
import 'services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize auth listener
  AuthService.initializeAuthListener();

  runApp(const FashionStoreApp());
}

class FashionStoreApp extends StatelessWidget {
  const FashionStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          AppTheme.isDarkMode = false;
          return MaterialApp(
            title: 'Fashion Store - Aromas',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: const AuthWrapper(),
          );
        }

        return StreamBuilder<UserSettings>(
          stream: FirestoreService().getUserSettingsStream(user.uid),
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data ?? const UserSettings();
            AppTheme.isDarkMode = settings.darkMode;
            return MaterialApp(
              title: 'Fashion Store - Aromas',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
              home: const AuthWrapper(),
            );
          },
        );
      },
    );
  }
}
