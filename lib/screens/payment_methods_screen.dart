import 'package:flutter/material.dart';
import '../models/payment_method.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import 'add_edit_payment_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final bool isSelectionMode;

  const PaymentMethodsScreen({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _firestoreService = FirestoreService();
  final _userId = AuthService.currentUser?.uid ?? '';

  Future<void> _deletePaymentMethod(PaymentMethod method) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Card'),
        content: Text('Are you sure you want to remove the card ending in ${method.cardNumber.substring(method.cardNumber.length - 4)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deletePaymentMethod(_userId, method.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card removed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove card: $e')),
          );
        }
      }
    }
  }

  Future<void> _makeDefault(PaymentMethod method) async {
    try {
      await _firestoreService.setDefaultPaymentMethod(_userId, method.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Default payment updated to card ending in ${method.cardNumber.substring(method.cardNumber.length - 4)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set default card: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Methods')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payment, size: 80, color: AppTheme.secondaryText),
              const SizedBox(height: 16),
              Text(
                'Log in to manage payment methods',
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
        title: Text(widget.isSelectionMode ? 'Select Payment Method' : 'Payment Methods'),
      ),
      body: StreamBuilder<List<PaymentMethod>>(
        stream: _firestoreService.getPaymentMethodsStream(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cards = snapshot.data ?? [];

          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.credit_card_off_outlined, size: 80, color: AppTheme.secondaryText),
                    const SizedBox(height: 16),
                    Text(
                      'No Payment Cards Saved',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a credit or debit card to complete purchases smoothly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Add New Card',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditPaymentScreen(userId: _userId),
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
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: InkWell(
                  onTap: () {
                    if (widget.isSelectionMode) {
                      Navigator.pop(context, card);
                    } else {
                      _makeDefault(card);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: _buildCreditCardItem(card),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<List<PaymentMethod>>(
        stream: _firestoreService.getPaymentMethodsStream(_userId),
        builder: (context, snapshot) {
          final cards = snapshot.data ?? [];
          if (cards.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: CustomButton(
              text: 'Add New Card',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditPaymentScreen(userId: _userId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreditCardItem(PaymentMethod card) {
    final gradient = card.isDefault
        ? LinearGradient(
            colors: AppTheme.isDarkMode
                ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                : [AppTheme.primaryText, const Color(0xFF333333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: AppTheme.isDarkMode
                ? [Theme.of(context).colorScheme.surface, const Color(0xFF252525)]
                : [const Color(0xFFF5F5F5), const Color(0xFFEBEBEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final textColor = card.isDefault ? Colors.white : AppTheme.primaryText;
    final secondaryTextColor = card.isDefault ? Colors.white70 : AppTheme.secondaryText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.isDefault ? Colors.transparent : Theme.of(context).dividerColor,
        ),
        boxShadow: card.isDefault
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card, color: textColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    card.cardType,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (card.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 20, color: secondaryTextColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditPaymentScreen(
                            userId: _userId,
                            paymentMethod: card,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                    onPressed: () => _deletePaymentMethod(card),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            card.cardNumber,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARDHOLDER',
                    style: TextStyle(color: secondaryTextColor, fontSize: 9, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.cardHolderName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EXPIRES',
                    style: TextStyle(color: secondaryTextColor, fontSize: 9, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.expiryDate,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
