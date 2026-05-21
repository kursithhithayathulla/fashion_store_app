import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AuthUser {
  final String uid;
  final String email;
  final String displayName;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  factory AuthUser.fromFirebaseUser(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'User',
    );
  }
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static AuthUser? currentUser;
  static bool isLoggedIn = false;

  /// Initialize auth state listener
  static void initializeAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        isLoggedIn = true;
        currentUser = AuthUser.fromFirebaseUser(user);
      } else {
        isLoggedIn = false;
        currentUser = null;
      }
    });
  }

  /// Get current Firebase user
  static User? getCurrentFirebaseUser() {
    return _auth.currentUser;
  }

  /// Check if user is logged in
  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Register with email and password
  static Future<bool> register(String email, String password, String displayName) async {
    final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await userCredential.user?.updateDisplayName(displayName);
    await userCredential.user?.reload();

    await FirestoreService().createUserProfile(
      userCredential.user!.uid,
      displayName,
      email,
    );

    // Immediately sign out so the user is not automatically logged in
    await _auth.signOut();
    isLoggedIn = false;
    currentUser = null;

    return true;
  }

  /// Login with email and password
  static Future<bool> login(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      isLoggedIn = true;
      currentUser = AuthUser.fromFirebaseUser(userCredential.user!);
      return true;
    } on FirebaseAuthException catch (_) {
      // Handle specific Firebase auth exceptions
      return false;
    } catch (_) {
      // Handle general errors
      return false;
    }
  }

  /// Logout
  static Future<void> logout() async {
    try {
      await _auth.signOut();
      isLoggedIn = false;
      currentUser = null;
    } catch (_) {
      // Handle logout errors silently
    }
  }

  /// Send password reset email
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (_) {
      // Handle Firebase auth exception
      return false;
    }
  }

  /// Get error message from Firebase exception
  static String getErrorMessage(FirebaseAuthException e) {
    if (e.code == 'user-not-found') {
      return 'No user found with this email address.';
    } else if (e.code == 'wrong-password') {
      return 'Wrong password. Please try again.';
    } else if (e.code == 'email-already-in-use') {
      return 'An account already exists with this email.';
    } else if (e.code == 'weak-password') {
      return 'The password is too weak. Use at least 6 characters.';
    } else if (e.code == 'invalid-email') {
      return 'The email address is invalid.';
    }
    return e.message ?? 'An error occurred. Please try again.';
  }
}
