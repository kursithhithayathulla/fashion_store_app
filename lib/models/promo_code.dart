import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCode {
  final String id;
  final String code;
  final double discountPercentage;
  final String description;
  final DateTime expiryDate;
  final bool isActive;

  PromoCode({
    required this.id,
    required this.code,
    required this.discountPercentage,
    required this.description,
    required this.expiryDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase(),
      'discountPercentage': discountPercentage,
      'description': description,
      'expiryDate': expiryDate,
      'isActive': isActive,
    };
  }

  factory PromoCode.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final expiry = map['expiryDate'];
    if (expiry is Timestamp) {
      parsedDate = expiry.toDate();
    } else if (expiry is String) {
      parsedDate = DateTime.parse(expiry);
    } else {
      parsedDate = DateTime.now();
    }

    return PromoCode(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      expiryDate: parsedDate,
      isActive: map['isActive'] ?? true,
    );
  }
}
