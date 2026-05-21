import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';
import 'shipping_address.dart';

class OrderModel {
  final String id;
  final String userId;
  final List<CartItem> items;
  final double totalAmount;
  final DateTime orderDate;
  final String status;
  final ShippingAddress? shippingAddress;
  final String? promoCode;
  final double? discountAmount;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    this.status = 'Pending',
    this.shippingAddress,
    this.promoCode,
    this.discountAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'orderDate': Timestamp.fromDate(orderDate),
      'status': status,
      if (shippingAddress != null) 'shippingAddress': shippingAddress!.toMap(),
      if (promoCode != null) 'promoCode': promoCode,
      if (discountAmount != null) 'discountAmount': discountAmount,
    };
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // We assume items will contain simple maps that CartItem can parse
    List<dynamic> itemsList = data['items'] ?? [];
    List<CartItem> parsedItems = itemsList.map((itemData) => CartItem.fromMap(itemData)).toList();

    ShippingAddress? parsedAddress;
    if (data['shippingAddress'] != null) {
      parsedAddress = ShippingAddress.fromMap(data['shippingAddress'] as Map<String, dynamic>);
    }

    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      items: parsedItems,
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'Pending',
      shippingAddress: parsedAddress,
      promoCode: data['promoCode'],
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
    );
  }
}
