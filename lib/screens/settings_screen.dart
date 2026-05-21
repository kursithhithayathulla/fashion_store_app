import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_settings.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestoreService = FirestoreService();
  bool _isProcessing = false;

  void _showDeleteAccountDialog(String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Delete Account',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor),
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action is permanent and will delete all your profile details, orders, addresses, and payment methods.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAccount(userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(String userId) async {
    setState(() => _isProcessing = true);
    try {
      final user = AuthService.getCurrentFirebaseUser();
      if (user != null) {
        // First delete their collections in Firestore
        await _firestoreService.deleteUserAccountData(userId);
        
        // Then delete the Firebase Auth account
        await user.delete();
        
        // Log out locally
        await AuthService.logout();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account has been deleted successfully.')),
          );
          // Navigate back to the home/splash screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Re-authentication Required'),
              content: const Text(
                'For security reasons, this action requires a recent login. Please log out, log back in, and try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Failed to delete account.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.primaryText)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = AuthService.getCurrentFirebaseUser();
    if (firebaseUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryText,
        ),
        body: const Center(
          child: Text('Please log in to view settings.'),
        ),
      );
    }

    final userId = firebaseUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryText,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<UserSettings>(
              stream: _firestoreService.getUserSettingsStream(userId),
              builder: (context, snapshot) {
                final settings = snapshot.data ?? const UserSettings();

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Profile Overview Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.secondaryText.withValues(alpha: 0.1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppTheme.primaryText.withValues(alpha: 0.1),
                              child: Text(
                                (firebaseUser.displayName ?? 'U').substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    firebaseUser.displayName ?? 'User',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    firebaseUser.email ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Section: Notifications ---
                    _buildSectionHeader('Notifications'),
                    const SizedBox(height: 8),
                    _buildSwitchTile(
                      title: 'Push Notifications',
                      subtitle: 'Enable or disable all notifications',
                      value: settings.pushEnabled,
                      onChanged: (val) {
                        _firestoreService.updateUserSettings(
                          userId,
                          settings.copyWith(pushEnabled: val),
                        );
                      },
                    ),
                    _buildSwitchTile(
                      title: 'Sales & Offers',
                      subtitle: 'Discounts, coupons, and flash sales alerts',
                      value: settings.salesAlerts && settings.pushEnabled,
                      enabled: settings.pushEnabled,
                      onChanged: (val) {
                        _firestoreService.updateUserSettings(
                          userId,
                          settings.copyWith(salesAlerts: val),
                        );
                      },
                    ),
                    _buildSwitchTile(
                      title: 'New Collections',
                      subtitle: 'Get notified when new fashion products drop',
                      value: settings.newArrivals && settings.pushEnabled,
                      enabled: settings.pushEnabled,
                      onChanged: (val) {
                        _firestoreService.updateUserSettings(
                          userId,
                          settings.copyWith(newArrivals: val),
                        );
                      },
                    ),
                    _buildSwitchTile(
                      title: 'Delivery Updates',
                      subtitle: 'Notifications about order status & shipping info',
                      value: settings.deliveryUpdates && settings.pushEnabled,
                      enabled: settings.pushEnabled,
                      onChanged: (val) {
                        _firestoreService.updateUserSettings(
                          userId,
                          settings.copyWith(deliveryUpdates: val),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Section: App Preferences ---
                    _buildSectionHeader('Preferences'),
                    const SizedBox(height: 8),
                    _buildSwitchTile(
                      title: 'Dark Mode',
                      subtitle: 'Toggle dark interface styling',
                      value: settings.darkMode,
                      onChanged: (val) {
                        _firestoreService.updateUserSettings(
                          userId,
                          settings.copyWith(darkMode: val),
                        );
                      },
                    ),
                    _buildDropdownTile(
                      title: 'Language',
                      subtitle: 'Change app interface language',
                      value: settings.language,
                      items: const ['English', 'Spanish', 'French', 'German'],
                      onChanged: (val) {
                        if (val != null) {
                          _firestoreService.updateUserSettings(
                            userId,
                            settings.copyWith(language: val),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Section: Legals & Support ---
                    _buildSectionHeader('Privacy & Support'),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      title: 'Terms of Service',
                      icon: Icons.description_outlined,
                      onTap: () {
                        _showInfoDialog(
                          'Terms of Service',
                          'Welcome to Aromas Fashion Store. By accessing or using our application, you agree to comply with and be bound by these terms. We offer high-quality clothing, secure payments, and fast shipping. All content, images, and brand materials are intellectual property of Aromas Fashion Store.',
                        );
                      },
                    ),
                    _buildActionTile(
                      title: 'Privacy Policy',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {
                        _showInfoDialog(
                          'Privacy Policy',
                          'Your privacy is critical to us. We store your account details, addresses, and settings safely in Firestore. We do not sell or share your personal details with third-party networks. You retain the right to delete your account and all associated personal data permanently at any time.',
                        );
                      },
                    ),
                    _buildActionTile(
                      title: 'About App',
                      icon: Icons.info_outline,
                      onTap: () {
                        _showInfoDialog(
                          'About Aromas Fashion',
                          'Aromas Fashion Store App\nVersion: 1.0.0\nBuilt with Flutter & Firebase Firestore.\n\nEnjoy premium clothing and shopping experience.',
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Section: Danger Zone ---
                    _buildSectionHeader('Danger Zone', color: AppTheme.errorColor),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: AppTheme.errorColor.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.2)),
                      ),
                      child: ListTile(
                        onTap: () => _showDeleteAccountDialog(userId),
                        leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.errorColor),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                        subtitle: const Text(
                          'Permanently delete your profile and store details',
                          style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.errorColor),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color ?? AppTheme.primaryText,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SwitchListTile.adaptive(
        activeTrackColor: AppTheme.primaryText,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: Container(),
        icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryText),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(
              val,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primaryText),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      trailing: Icon(Icons.chevron_right, color: AppTheme.secondaryText),
    );
  }
}
