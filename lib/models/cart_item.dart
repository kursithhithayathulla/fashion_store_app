import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  final String selectedSize;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedSize = 'M',
  });

  Map<String, dynamic> toMap() {
    return {
      'product': product.toMap(),
      'quantity': quantity,
      'selectedSize': selectedSize,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> data) {
    return CartItem(
      product: Product.fromMap(data['product'] as Map<String, dynamic>),
      quantity: data['quantity'] ?? 1,
      selectedSize: data['selectedSize'] ?? 'M',
    );
  }
}
