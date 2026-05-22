import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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

/// ============================================================
/// ProfileScreen — Base64 Profile Image System (No Firebase Storage)
/// ============================================================
///
/// HOW IT WORKS:
///   1. User taps camera icon → image_picker opens the gallery
///   2. Selected image is read as bytes (Uint8List)
///   3. Bytes are encoded to a Base64 string via base64Encode()
///   4. The Base64 string is stored in Firestore as a data URI:
///      `data:image/jpeg;base64,<base64_string>`
///   5. StreamBuilder listens to Firestore for real-time updates
///   6. On display, the data URI is decoded back into bytes
///   7. MemoryImage renders the bytes inside CircleAvatar
///
/// FIRESTORE STRUCTURE:
///   users (collection)
///     └── {uid} (document)
///           ├── name: "John Doe"
///           ├── email: "john@example.com"
///           ├── profileType: "Men Profile"
///           ├── photoUrl: "data:image/jpeg;base64,..."
///           ├── profileImage: "data:image/jpeg;base64,..."
///           └── createdAt: Timestamp
///
/// IMPORTANT NOTES:
///   • Firestore document limit is 1 MB — images are compressed
///     to 512x512 with 75% quality to stay well under this limit
///   • Both photoUrl and profileImage fields are kept in sync
///   • No Firebase Storage dependency required
/// ============================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── State Variables ──────────────────────────────────────────
  bool _isUploadingProfileImage = false;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
  }

  // ── STEP 1: Decode Base64 string back into an ImageProvider ──
  /// Takes a stored path/URL and returns an ImageProvider.
  /// Handles three cases:
  ///   • data:image URI → decode Base64 → MemoryImage
  ///   • Local file path  → FileImage (mobile only)
  ///   • HTTP(S) URL      → NetworkImage
  ImageProvider? _getProfileImageProvider(String path) {
    if (path.isEmpty) return null;

    // CASE 1: Base64 data URI (our primary method)
    if (path.startsWith('data:image/')) {
      try {
        // Split "data:image/jpeg;base64,<actual_base64>" to get the data part
        final base64String = path.split(',').last;
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('❌ Error decoding base64 image: $e');
        return null;
      }
    }

    // CASE 2: Local file path (fallback for older data)
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

    // CASE 3: Network URL (fallback for older data)
    return NetworkImage(ImageHelper.convertDriveUrl(path));
  }

  // ── Helper: Should show placeholder icon? ────────────────────
  bool _shouldShowPlaceholder(Uint8List? pickedBytes, String path) {
    if (pickedBytes != null) return false;
    if (path.isEmpty) return true;
    if (path.startsWith('data:image/')) return false;
    if (!kIsWeb &&
        !path.startsWith('http://') &&
        !path.startsWith('https://')) {
      return !File(path).existsSync();
    }
    return false;
  }

  // ── STEP 2: Pick image, encode to Base64, store in Firestore ──
  /// This is the main upload flow:
  ///   1. Open gallery with image_picker
  ///   2. Read image bytes
  ///   3. Encode to Base64 string
  ///   4. Save to Firestore (no Firebase Storage needed!)
  Future<void> _uploadProfileImage(BuildContext context, String userId) async {
    if (userId.isEmpty) return;

    final picker = ImagePicker();
    try {
      // ── Pick image from gallery ──
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,       // Compress width to reduce Base64 size
        maxHeight: 512,      // Compress height to reduce Base64 size
        imageQuality: 75,    // 75% quality keeps good visuals, small size
      );

      if (pickedFile == null) return; // User cancelled the picker

      // ── Show loading indicator ──
      setState(() {
        _isUploadingProfileImage = true;
      });

      // ── Read image as bytes (Uint8List) ──
      final rawBytes = await pickedFile.readAsBytes();

      // ── Compress and resize image bytes to keep them under Firestore limit ──
      final bytes = await ImageHelper.resizeAndCompressImage(rawBytes, maxDimension: 256);

      // ── Encode bytes to Base64 string ──
      final base64String = base64Encode(bytes);

      // ── Create data URI (stores MIME type + Base64 together) ──
      final dataUri = 'data:image/jpeg;base64,$base64String';

      // ── Save to Firestore ──
      // This stores the entire image as a string in the user's document
      await FirestoreService().updateUserProfileImage(userId, dataUri);

      // ── Show success message ──
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Profile image updated successfully!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      // ── Error handling ──
      debugPrint('❌ Profile image upload failed: $e');
      if (!context.mounted) return;

      String errorMessage = 'Failed to update image.';
      if (e.toString().contains('permission')) {
        errorMessage = 'Gallery permission denied. Please allow access.';
      } else if (e.toString().contains('too-large') ||
          e.toString().contains('RESOURCE_EXHAUSTED')) {
        errorMessage = 'Image is too large. Try a smaller image.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      // ── Always hide loading indicator ──
      if (mounted) {
        setState(() {
          _isUploadingProfileImage = false;
        });
      }
    }
  }

  // ── Edit Profile Dialog ──────────────────────────────────────
  void _showEditProfileDialog(
    BuildContext context,
    String currentName,
    String currentProfileType,
    String currentPhotoUrl,
  ) {
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
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.edit, color: AppTheme.accentColor, size: 22),
                const SizedBox(width: 8),
                const Text('Edit Profile'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Profile image picker inside dialog ──
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: pickedImageBytes != null
                              ? MemoryImage(pickedImageBytes!) as ImageProvider
                              : _getProfileImageProvider(
                                  photoUrlController.text),
                          onBackgroundImageError: (pickedImageBytes != null ||
                                  photoUrlController.text.isNotEmpty)
                              ? (e, s) {}
                              : null,
                          child: _shouldShowPlaceholder(
                                  pickedImageBytes, photoUrlController.text)
                              ? const Icon(Icons.person,
                                  size: 45, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (isUploading)
                        const CircularProgressIndicator(
                            color: AppTheme.accentColor),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: isUploading
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 512,
                                    maxHeight: 512,
                                    imageQuality: 75,
                                  );
                                  if (pickedFile != null) {
                                    final rawBytes = await pickedFile.readAsBytes();
                                    final bytes = await ImageHelper.resizeAndCompressImage(rawBytes, maxDimension: 256);
                                    setState(() {
                                      pickedImageBytes = bytes;
                                    });
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    enabled: !isUploading,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: [
                      'Men Profile',
                      'Women Profile',
                      'Unisex Profile'
                    ].contains(selectedType)
                        ? selectedType
                        : 'Men Profile',
                    decoration: InputDecoration(
                      labelText: 'Profile Type',
                      prefixIcon: const Icon(Icons.style_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Men Profile', 'Women Profile', 'Unisex Profile']
                        .map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: isUploading
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => selectedType = val);
                            }
                          },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context),
                child:
                    Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (userId != null) {
                          setState(() {
                            isUploading = true;
                          });

                          String finalPhotoUrl =
                              photoUrlController.text.trim();
                          try {
                            // Encode picked image bytes to Base64
                            if (pickedImageBytes != null) {
                              final base64String =
                                  base64Encode(pickedImageBytes!);
                              finalPhotoUrl =
                                  'data:image/jpeg;base64,$base64String';
                            }

                            final bool isBase64 = finalPhotoUrl.startsWith('data:image/');
                            await FirestoreService()
                                .updateUserProfile(userId, {
                              'name': nameController.text.trim(),
                              'profileType': selectedType,
                              'photoUrl': isBase64 ? '' : finalPhotoUrl,
                              'profileImage': finalPhotoUrl,
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
                                SnackBar(
                                  content:
                                      Text('Error updating profile: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return _buildGuestView(context);
    }
    return _buildProfileView(context);
  }

  // ── Guest View (Not Logged In) ──────────────────────────────

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
                  border: Border.all(
                      color: Theme.of(context).dividerColor, width: 2),
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

  // ── Logged In Profile View ──────────────────────────────────

  Widget _buildProfileView(BuildContext context) {
    final userId = AuthService.currentUser?.uid ?? '';

    return Scaffold(
      body: StreamBuilder<Map<String, dynamic>>(
        // STEP 5: Real-time Firestore stream — any change to the user
        // document (including profileImage) triggers a rebuild instantly
        stream: FirestoreService().getUserProfileStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading profile',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final userData = snapshot.data ?? {};
          final name = userData['name'] ?? 'User';
          final email = userData['email'] ?? AuthService.currentUser?.email ?? 'user@example.com';
          final profileType = userData['profileType'] ?? 'Standard Member';
          final String photoUrl = userData['profileImage'] ?? userData['photoUrl'] ?? '';

          return CustomScrollView(
            slivers: [
              // ── Modern Solid Header (No Gradient) ──
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        children: [
                          // ── Top bar ──
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'My Profile',
                                style: TextStyle(
                                  color: AppTheme.primaryText,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: AppTheme.secondaryText),
                                    onPressed: () =>
                                        _showEditProfileDialog(
                                      context,
                                      name,
                                      profileType,
                                      photoUrl,
                                    ),
                                    tooltip: 'Edit Profile',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                        Icons.settings_outlined,
                                        color: AppTheme.secondaryText),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsScreen(),
                                        ),
                                      );
                                    },
                                    tooltip: 'Settings',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Display Base64 image in CircleAvatar ──
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow ring
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.6),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentColor
                                          .withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: AppTheme.backgroundColor,
                                  backgroundImage:
                                      _getProfileImageProvider(photoUrl),
                                  onBackgroundImageError:
                                      photoUrl.isNotEmpty
                                          ? (e, s) {}
                                          : null,
                                  child: _shouldShowPlaceholder(
                                          null, photoUrl)
                                      ? Icon(Icons.person,
                                          size: 60, color: AppTheme.secondaryText)
                                      : null,
                                ),
                              ),

                              // ── Loading overlay while uploading ──
                              if (_isUploadingProfileImage)
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accentColor,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),

                              // ── Camera button ──
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploadingProfileImage
                                      ? null
                                      : () => _uploadProfileImage(
                                          context, userId),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppTheme.cardColor, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── User name ──
                          Text(
                            name,
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // ── User email ──
                          Text(
                            email,
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Profile type badge ──
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.accentColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              profileType,
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Menu Items ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Section label
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'MY ACCOUNT',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _buildProfileOption(
                      context,
                      Icons.shopping_bag_outlined,
                      'My Orders',
                      subtitle: 'Track & manage your orders',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrdersScreen(userId: userId),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      context,
                      Icons.favorite_border,
                      'Wishlist',
                      subtitle: 'Items you love',
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
                      subtitle: 'Manage delivery addresses',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ShippingAddressesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      context,
                      Icons.payment_outlined,
                      'Payment Methods',
                      subtitle: 'Saved cards & payment options',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PaymentMethodsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      context,
                      Icons.local_offer_outlined,
                      'Promo Codes',
                      subtitle: 'Available discounts & coupons',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PromoCodesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      subtitle: 'App preferences & theme',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // ── Logout Button ──
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Log Out'),
                              content: const Text(
                                  'Are you sure you want to log out?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    AuthService.logout();
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout,
                            color: AppTheme.errorColor),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                              color: AppTheme.errorColor, fontSize: 16),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side:
                                const BorderSide(color: AppTheme.errorColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Profile Menu Option Widget ──────────────────────────────

  Widget _buildProfileOption(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: AppTheme.isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 15),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.secondaryText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
