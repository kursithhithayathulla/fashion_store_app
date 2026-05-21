import 'package:flutter/material.dart';
import '../models/shipping_address.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import 'add_edit_address_screen.dart';

class ShippingAddressesScreen extends StatefulWidget {
  final bool isSelectionMode;

  const ShippingAddressesScreen({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<ShippingAddressesScreen> createState() => _ShippingAddressesScreenState();
}

class _ShippingAddressesScreenState extends State<ShippingAddressesScreen> {
  final _firestoreService = FirestoreService();
  final _userId = AuthService.currentUser?.uid ?? '';

  Future<void> _deleteAddress(ShippingAddress address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete the address for "${address.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteAddress(_userId, address.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete address: $e')),
          );
        }
      }
    }
  }

  Future<void> _makeDefault(ShippingAddress address) async {
    try {
      await _firestoreService.setDefaultAddress(_userId, address.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Default address updated to "${address.fullName}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set default: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shipping Addresses')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 80, color: AppTheme.secondaryText),
              const SizedBox(height: 16),
              Text(
                'Log in to manage shipping addresses',
                style: TextStyle(fontSize: 18, color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CustomButton(
                  text: 'Return to Login',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select Address' : 'Shipping Addresses'),
      ),
      body: StreamBuilder<List<ShippingAddress>>(
        stream: _firestoreService.getAddressesStream(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off_outlined, size: 80, color: AppTheme.secondaryText),
                    const SizedBox(height: 16),
                    Text(
                      'No Shipping Addresses Saved',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your shipping details to quickly check out next time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Add New Address',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditAddressScreen(userId: _userId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24.0),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: InkWell(
                  onTap: () {
                    if (widget.isSelectionMode) {
                      Navigator.pop(context, addr);
                    } else {
                      _makeDefault(addr);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: addr.isDefault
                            ? AppTheme.accentColor
                            : Theme.of(context).dividerColor,
                        width: addr.isDefault ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                addr.fullName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                if (addr.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryText,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: TextStyle(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, size: 20, color: AppTheme.secondaryText),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEditAddressScreen(
                                          userId: _userId,
                                          address: addr,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                                  onPressed: () => _deleteAddress(addr),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${addr.addressLine1}${addr.addressLine2.isNotEmpty ? ', ${addr.addressLine2}' : ''}',
                          style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                        ),
                        Text(
                          '${addr.city}, ${addr.state} ${addr.zipCode}',
                          style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                        ),
                        Text(
                          addr.country,
                          style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          addr.phoneNumber,
                          style: TextStyle(
                            color: AppTheme.primaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<List<ShippingAddress>>(
        stream: _firestoreService.getAddressesStream(_userId),
        builder: (context, snapshot) {
          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: CustomButton(
              text: 'Add New Address',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditAddressScreen(userId: _userId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
