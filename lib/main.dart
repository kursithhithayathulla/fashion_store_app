import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'models/product.dart';
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

  // Run the Firestore image URL repair
  await repairFirestoreImageUrls();

  // Seed default promo codes if needed
  try {
    await FirestoreService().seedDefaultPromoCodes();
  } catch (e) {
    debugPrint('Error seeding promo codes: $e');
  }

  // Seed default categories if needed
  try {
    await FirestoreService().seedDefaultCategories();
  } catch (e) {
    debugPrint('Error seeding categories: $e');
  }

  // Seed default products if needed
  try {
    await FirestoreService().seedDefaultProducts();
  } catch (e) {
    debugPrint('Error seeding products: $e');
  }
  
  runApp(const FashionStoreApp());
}

Future<void> repairFirestoreImageUrls() async {
  try {
    final db = FirebaseFirestore.instance;
    final productsSnapshot = await db.collection('products').get();
    
    debugPrint('--- Starting Firestore Image URL Repair ---');
    for (var doc in productsSnapshot.docs) {
      final data = doc.data();
      final String originalUrl = data['imageUrl'] ?? '';
      
      if (originalUrl.isEmpty) continue;
      
      // Normalize using the Product model method
      final String newUrl = Product.normalizeImageUrl(originalUrl);
      
      if (originalUrl != newUrl) {
        debugPrint('Updating product ${doc.id} ("${data['name']}")');
        debugPrint('  Old: $originalUrl');
        debugPrint('  New: $newUrl');
        await db.collection('products').doc(doc.id).update({'imageUrl': newUrl});
      }
    }
    debugPrint('--- Firestore Image URL Repair Completed ---');
  } catch (e) {
    debugPrint('Error repairing product image URLs: $e');
  }
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
