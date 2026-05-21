import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'orders_screen.dart';
import 'wishlist_screen.dart';
import 'shipping_addresses_screen.dart';
import 'payment_methods_screen.dart';
import 'promo_codes_screen.dart';
import 'settings_screen.dart';
import '../utils/image_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingProfileImage = false;

  ImageProvider? _getProfileImageProvider(String path) {
    if (path.isEmpty) return null;
    if (!kIsWeb) {
      if (!path.startsWith('http://') && !path.startsWith('https://')) {
        final file = File(path);
        if (file.existsSync()) {
          return FileImage(file);
        } else {
          return null;
        }
      }
    }
    return NetworkImage(ImageHelper.convertDriveUrl(path));
  }

  bool _shouldShowPlaceholder(Uint8List? pickedBytes, String path) {
    if (pickedBytes != null) return false;
    if (path.isEmpty) return true;
    if (!kIsWeb && !path.startsWith('http://') && !path.startsWith('https://')) {
      return !File(path).existsSync();
    }
    return false;
  }

  Future<String> _uploadImageToStorage(String userId, dynamic fileOrBytes) async {
    final defaultBucket = FirebaseStorage.instance.app.options.storageBucket ?? '';
    final isDefaultAppspot = defaultBucket.contains('.appspot.com');
    final fallbackBucket = isDefaultAppspot 
        ? defaultBucket.replaceAll('.appspot.com', '.firebasestorage.app')
        : defaultBucket.replaceAll('.firebasestorage.app', '.appspot.com');

    // Try primary bucket
    try {
      return await _performUpload(FirebaseStorage.instance, userId, fileOrBytes);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' && fallbackBucket.isNotEmpty && fallbackBucket != defaultBucket) {
        debugPrint('Upload failed with object-not-found. Retrying with fallback bucket: $fallbackBucket');
        try {
          final fallbackStorage = FirebaseStorage.instanceFor(
            app: FirebaseStorage.instance.app,
            bucket: fallbackBucket,
          );
          return await _performUpload(fallbackStorage, userId, fileOrBytes);
        } on FirebaseException catch (fallbackErr) {
          if (fallbackErr.code == 'object-not-found') {
            throw FirebaseException(
              plugin: 'firebase_storage',
              code: 'object-not-found',
              message: 'Storage bucket not found. Please ensure Firebase Storage is enabled in your Firebase Console and the bucket name in firebase_options.dart is correct.',
            );
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<String> _performUpload(FirebaseStorage storage, String userId, dynamic fileOrBytes) async {
    final ref = storage.ref().child('profile_images').child('$userId.jpg');
    TaskSnapshot snapshot;
    if (fileOrBytes is Uint8List) {
      snapshot = await ref.putData(
        fileOrBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else if (fileOrBytes is File) {
      snapshot = await ref.putFile(fileOrBytes);
    } else {
      throw ArgumentError('Unsupported file type');
    }
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _uploadProfileImage(BuildContext context, String userId) async {
    if (userId.isEmpty) return;

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return; // User cancelled

      setState(() {
        _isUploadingProfileImage = true;
      });

      final String downloadUrl;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        downloadUrl = await _uploadImageToStorage(userId, bytes);
      } else {
        final file = File(pickedFile.path);
        downloadUrl = await _uploadImageToStorage(userId, file);
      }

      debugPrint('Uploaded to Firebase Storage, URL: $downloadUrl');

      await FirestoreService().updateUserProfileImage(userId, downloadUrl);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Update failed: $e');
      if (!context.mounted) return;
      
      String message = e.toString();
      if (e is FirebaseException && e.message != null) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update image: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfileImage = false;
        });
      }
    }
  }

  void _showEditProfileDialog(BuildContext context, String currentName, String currentProfileType, String currentPhotoUrl) {
    final nameController = TextEditingController(text: currentName);
    final photoUrlController = TextEditingController(text: currentPhotoUrl);
    String selectedType = currentProfileType;
    final userId = AuthService.currentUser?.uid;
    bool isUploading = false;
    Uint8List? pickedImageBytes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: pickedImageBytes != null
                              ? MemoryImage(pickedImageBytes!) as ImageProvider
                              : _getProfileImageProvider(photoUrlController.text),
                          onBackgroundImageError: (pickedImageBytes != null || photoUrlController.text.isNotEmpty)
                              ? (e, s) {}
                              : null,
                          child: _shouldShowPlaceholder(pickedImageBytes, photoUrlController.text)
                              ? const Icon(Icons.person, size: 40, color: Colors.grey)
                              : null,
                        ),
                        if (isUploading) const CircularProgressIndicator(),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: isUploading ? null : () async {
                              final picker = ImagePicker();
                              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                              if (pickedFile != null) {
                                final bytes = await pickedFile.readAsBytes();
                                setState(() {
                                  pickedImageBytes = bytes;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      enabled: !isUploading,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: ['Men Profile', 'Women Profile', 'Unisex Profile'].contains(selectedType) ? selectedType : 'Men Profile',
                      decoration: const InputDecoration(labelText: 'Profile Type'),
                      items: ['Men Profile', 'Women Profile', 'Unisex Profile'].map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: isUploading ? null : (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (userId != null) {
                      setState(() {
                        isUploading = true;
                      });
                      
                      String finalPhotoUrl = photoUrlController.text.trim();
                      try {
                        if (pickedImageBytes != null) {
                          // Upload to Firebase Storage using bytes (works on both web and mobile)
                          finalPhotoUrl = await _uploadImageToStorage(userId, pickedImageBytes!);
                          debugPrint('Uploaded to Firebase Storage, URL: $finalPhotoUrl');
                        }

                        await FirestoreService().updateUserProfile(userId, {
                          'name': nameController.text.trim(),
                          'profileType': selectedType,
                          'photoUrl': finalPhotoUrl,
                          'profileImage': finalPhotoUrl, // Keeps both synchronized in Firestore
                        });
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        setState(() {
                          isUploading = false;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating profile: $e')),
                          );
                        }
                      }
                    } else {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return _buildGuestView(context);
    }
    return _buildProfileView(context);
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 52,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You\'re not logged in',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to view your profile, orders and wishlist.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                    setState(() {});
                  },
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryText,
                    side: BorderSide(color: AppTheme.primaryText),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView(BuildContext context) {
    final userId = AuthService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FirestoreService().getUserProfileStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading profile: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final userData = snapshot.data ?? {};
          final name = userData['name'] ?? AuthService.currentUser?.displayName ?? 'User';
          final email = userData['email'] ?? AuthService.currentUser?.email ?? 'user@example.com';
          final profileType = userData['profileType'] ?? 'Men Profile';
          final photoUrl = userData['photoUrl'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _getProfileImageProvider(photoUrl),
                      onBackgroundImageError: photoUrl.isNotEmpty ? (e, s) {} : null,
                      child: _shouldShowPlaceholder(null, photoUrl)
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    if (_isUploadingProfileImage)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingProfileImage ? null : () => _uploadProfileImage(context, userId),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: () => _showEditProfileDialog(context, name, profileType, photoUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryText.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    profileType,
                    style: TextStyle(
                      color: AppTheme.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildProfileOption(
                  context,
                  Icons.shopping_bag_outlined,
                  'My Orders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrdersScreen(userId: userId),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context,
                  Icons.favorite_border,
                  'Wishlist',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WishlistScreen(),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context,
                  Icons.location_on_outlined,
                  'Shipping Addresses',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShippingAddressesScreen(),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context,
                  Icons.payment_outlined,
                  'Payment Methods',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentMethodsScreen(),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context,
                  Icons.local_offer_outlined,
                  'Promo Codes',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PromoCodesScreen(),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      AuthService.logout();
                      setState(() {});
                    },
                    icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(color: AppTheme.errorColor, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    IconData icon,
    String title,
    {VoidCallback? onTap}
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDarkMode ? 0.2 : 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryText),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 16),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppTheme.secondaryText,
        ),
        onTap: onTap ?? () {},
      ),
    );
  }
}
