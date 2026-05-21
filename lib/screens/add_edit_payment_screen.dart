import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_method.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class AddEditPaymentScreen extends StatefulWidget {
  final String userId;
  final PaymentMethod? paymentMethod;

  const AddEditPaymentScreen({
    super.key,
    required this.userId,
    this.paymentMethod,
  });

  @override
  State<AddEditPaymentScreen> createState() => _AddEditPaymentScreenState();
}

class _AddEditPaymentScreenState extends State<AddEditPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  late TextEditingController _cardNumberController;
  late TextEditingController _cardHolderController;
  late TextEditingController _expiryController;
  late TextEditingController _cvvController;

  bool _isDefault = false;
  bool _isLoading = false;
  String _cardType = 'Visa';

  @override
  void initState() {
    super.initState();
    final payment = widget.paymentMethod;
    _cardNumberController = TextEditingController(text: payment?.cardNumber ?? '');
    _cardHolderController = TextEditingController(text: payment?.cardHolderName ?? '');
    _expiryController = TextEditingController(text: payment?.expiryDate ?? '');
    _cvvController = TextEditingController();
    _isDefault = payment?.isDefault ?? false;
    _cardType = payment?.cardType ?? 'Visa';

    _cardNumberController.addListener(_detectCardType);
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_detectCardType);
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _detectCardType() {
    final text = _cardNumberController.text.replaceAll(' ', '');
    String detectedType = 'Visa';
    if (text.startsWith('5')) {
      detectedType = 'Mastercard';
    } else if (text.startsWith('3')) {
      detectedType = 'Amex';
    }
    if (detectedType != _cardType) {
      setState(() {
        _cardType = detectedType;
      });
    }
  }

  Future<void> _savePaymentMethod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final maskedCardNumber = _maskCardNumber(_cardNumberController.text);

    final paymentMethod = PaymentMethod(
      id: widget.paymentMethod?.id ?? '',
      cardHolderName: _cardHolderController.text.trim(),
      cardNumber: maskedCardNumber,
      expiryDate: _expiryController.text.trim(),
      cardType: _cardType,
      isDefault: _isDefault,
    );

    try {
      if (widget.paymentMethod == null) {
        await _firestoreService.addPaymentMethod(widget.userId, paymentMethod);
      } else {
        await _firestoreService.updatePaymentMethod(widget.userId, paymentMethod);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.paymentMethod == null ? 'Card added successfully' : 'Card updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save card: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _maskCardNumber(String rawNumber) {
    final clean = rawNumber.replaceAll(' ', '');
    if (clean.length < 4) return clean;
    final lastFour = clean.substring(clean.length - 4);
    return '**** **** **** $lastFour';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.paymentMethod != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Card' : 'Add New Card'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Card Preview Widget
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _cardNumberController,
                        _cardHolderController,
                        _expiryController,
                      ]),
                      builder: (context, child) {
                        return _buildCardPreview();
                      },
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _cardHolderController,
                      decoration: InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Doe',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the cardholder name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 1234 5678',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card number';
                        }
                        final clean = value.replaceAll(' ', '');
                        if (clean.length < 15) {
                          return 'Card number must be 15 or 16 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            decoration: InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _CardExpiryFormatter(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (value.length < 5) {
                                return 'Invalid format';
                              }
                              final parts = value.split('/');
                              final month = int.tryParse(parts[0]) ?? 0;
                              if (month < 1 || month > 12) {
                                return 'Invalid month';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                            ),
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (value) {
                              if (widget.paymentMethod == null && (value == null || value.isEmpty)) {
                                return 'Required';
                              }
                              if (value != null && value.isNotEmpty && value.length < 3) {
                                return 'Invalid CVV';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: Text(
                        'Set as Default Payment Method',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      activeThumbColor: AppTheme.accentColor,
                      onChanged: (val) {
                        setState(() {
                          _isDefault = val;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: isEditing ? 'Save Changes' : 'Save Card',
                      onPressed: _savePaymentMethod,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCardPreview() {
    final numText = _cardNumberController.text.isEmpty
        ? '•••• •••• •••• ••••'
        : _cardNumberController.text;
    final nameText = _cardHolderController.text.isEmpty
        ? 'CARDHOLDER NAME'
        : _cardHolderController.text.toUpperCase();
    final expText = _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;

    // Elegant gradient matching the card type
    final gradient = _cardType == 'Mastercard'
        ? const LinearGradient(
            colors: [Color(0xFFE94E1B), Color(0xFFF79E1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : _cardType == 'Amex'
            ? const LinearGradient(
                colors: [Color(0xFF0070CD), Color(0xFF00A2E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.credit_card_outlined, color: Colors.white, size: 36),
              Text(
                _cardType,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          Text(
            numText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARD HOLDER',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nameText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
