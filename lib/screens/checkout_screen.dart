import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../models/shipping_address.dart';
import '../models/payment_method.dart';
import '../models/promo_code.dart';
import '../models/cart_item.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'shipping_addresses_screen.dart';
import 'add_edit_address_screen.dart';
import 'payment_methods_screen.dart';
import 'add_edit_payment_screen.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double subtotal;
  final double shipping;
  final double total;
  final List<CartItem> items;

  const CheckoutScreen({
    super.key,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.items,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  ShippingAddress? _selectedAddress;
  bool _hasLoadedDefault = false;
  bool _isPlacingOrder = false;

  PaymentMethod? _selectedPayment;
  bool _hasLoadedDefaultPayment = false;

  // Promo code variables
  final _promoController = TextEditingController();
  PromoCode? _appliedPromo;
  double _discountAmount = 0.0;

  final _firestoreService = FirestoreService();
  final _userId = AuthService.currentUser?.uid ?? '';

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    final rawTotal = widget.subtotal + widget.shipping;
    final discounted = rawTotal - _discountAmount;
    return discounted < 0 ? 0.0 : discounted;
  }

  Future<void> _applyPromoCode() async {
    final codeText = _promoController.text.trim();
    if (codeText.isEmpty) return;

    try {
      final promo = await _firestoreService.getPromoCode(codeText);
      if (promo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or expired promo code.')),
          );
        }
        return;
      }

      setState(() {
        _appliedPromo = promo;
        _discountAmount = (widget.subtotal + widget.shipping) * promo.discountPercentage / 100;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promo code applied! You saved \$${_discountAmount.toStringAsFixed(2)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying code: $e')),
        );
      }
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromo = null;
      _discountAmount = 0.0;
      _promoController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: _isPlacingOrder
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shipping Address', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  StreamBuilder<List<ShippingAddress>>(
                    stream: _firestoreService.getAddressesStream(_userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !_hasLoadedDefault) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final addresses = snapshot.data ?? [];
                      
                      if (addresses.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'No shipping address saved yet.',
                                style: TextStyle(color: AppTheme.secondaryText),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddEditAddressScreen(userId: _userId),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.add, color: AppTheme.accentColor),
                                label: Text(
                                  'Add Address',
                                  style: TextStyle(color: AppTheme.accentColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!_hasLoadedDefault) {
                        final defaultAddr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
                        _selectedAddress = defaultAddr;
                        _hasLoadedDefault = true;
                      } else {
                        final exists = addresses.any((a) => a.id == _selectedAddress?.id);
                        if (!exists) {
                          final defaultAddr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
                          _selectedAddress = defaultAddr;
                        } else {
                          _selectedAddress = addresses.firstWhere((a) => a.id == _selectedAddress?.id);
                        }
                      }

                      final addr = _selectedAddress;
                      if (addr == null) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final selected = await Navigator.push<ShippingAddress>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ShippingAddressesScreen(isSelectionMode: true),
                                      ),
                                    );
                                    if (selected != null) {
                                      setState(() {
                                        _selectedAddress = selected;
                                      });
                                    }
                                  },
                                  child: Text('Edit', style: TextStyle(color: AppTheme.accentColor)),
                                ),
                              ],
                            ),
                            Text(
                              '${addr.addressLine1}${addr.addressLine2.isNotEmpty ? ', ${addr.addressLine2}' : ''}\n${addr.city}, ${addr.state} ${addr.zipCode}\n${addr.country}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),
                            const SizedBox(height: 8),
                            Text(addr.phoneNumber, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text('Payment Method', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  StreamBuilder<List<PaymentMethod>>(
                    stream: _firestoreService.getPaymentMethodsStream(_userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !_hasLoadedDefaultPayment) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final cards = snapshot.data ?? [];
                      if (cards.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'No payment cards saved yet.',
                                style: TextStyle(color: AppTheme.secondaryText),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddEditPaymentScreen(userId: _userId),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.add, color: AppTheme.accentColor),
                                label: Text(
                                  'Add Card',
                                  style: TextStyle(color: AppTheme.accentColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!_hasLoadedDefaultPayment) {
                        final defaultCard = cards.firstWhere((c) => c.isDefault, orElse: () => cards.first);
                        _selectedPayment = defaultCard;
                        _hasLoadedDefaultPayment = true;
                      } else {
                        final exists = cards.any((c) => c.id == _selectedPayment?.id);
                        if (!exists) {
                          final defaultCard = cards.firstWhere((c) => c.isDefault, orElse: () => cards.first);
                          _selectedPayment = defaultCard;
                        } else {
                          _selectedPayment = cards.firstWhere((c) => c.id == _selectedPayment?.id);
                        }
                      }

                      final p = _selectedPayment;
                      if (p == null) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.credit_card, size: 32, color: AppTheme.primaryText),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.cardType,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(p.cardNumber, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final selected = await Navigator.push<PaymentMethod>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PaymentMethodsScreen(isSelectionMode: true),
                                  ),
                                );
                                if (selected != null) {
                                  setState(() {
                                    _selectedPayment = selected;
                                  });
                                }
                              },
                              child: Text('Edit', style: TextStyle(color: AppTheme.accentColor)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text('Promo Code', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          decoration: InputDecoration(
                            hintText: 'Enter Promo Code (e.g. WELCOME10)',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _applyPromoCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryText,
                          foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  if (_appliedPromo != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Code "${_appliedPromo!.code}" Applied (${_appliedPromo!.discountPercentage.toInt()}% Off)',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _removePromoCode,
                          child: const Text('Remove', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text('Order Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: Theme.of(context).textTheme.bodyLarge),
                      Text('\$${widget.subtotal.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shipping', style: Theme.of(context).textTheme.bodyLarge),
                      Text('\$${widget.shipping.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                  if (_appliedPromo != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discount (${_appliedPromo!.code})', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.green)),
                        Text('-\$${_discountAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.green)),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '\$${_calculatedTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accentColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  CustomButton(
                    text: 'Place Order',
                    onPressed: () async {
                      if (_selectedAddress == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or add a shipping address.')),
                        );
                        return;
                      }

                      if (_selectedPayment == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or add a payment method.')),
                        );
                        return;
                      }

                      setState(() {
                        _isPlacingOrder = true;
                      });

                      try {
                        await _firestoreService.placeOrder(
                          userId: _userId,
                          items: widget.items,
                          totalAmount: _calculatedTotal,
                          shippingAddress: _selectedAddress!,
                          promoCode: _appliedPromo?.code,
                          discountAmount: _discountAmount,
                        );

                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderSuccessScreen()),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to place order: $e')),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isPlacingOrder = false;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
