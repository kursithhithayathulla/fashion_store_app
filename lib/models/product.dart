import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> sizes;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.sizes = const ['S', 'M', 'L', 'XL'],
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'sizes': sizes,
      'category': category,
    };
  }

  static String normalizeImageUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    
    // Convert Windows backslashes to forward slashes
    String normalized = url.replaceAll('\\', '/');
    
    // Remove duplicate assets/ prefix if present
    if (normalized.startsWith('assets/assets/')) {
      normalized = normalized.replaceFirst('assets/assets/', 'assets/');
    }
    
    // Fix .webp to .png for shopping
    if (normalized.contains('shopping.webp')) {
      normalized = normalized.replaceAll('shopping.webp', 'shopping.png');
    }
    
    // Ensure it starts with assets/
    if (!normalized.startsWith('assets/')) {
      if (normalized.startsWith('images/')) {
        normalized = 'assets/$normalized';
      } else {
        normalized = 'assets/images/$normalized';
      }
    }
    
    return normalized;
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: normalizeImageUrl(data['imageUrl'] ?? ''),
      sizes: List<String>.from(data['sizes'] ?? ['S', 'M', 'L', 'XL']),
      category: data['category'] ?? '',
    );
  }

  factory Product.fromMap(Map<String, dynamic> data) {
    return Product(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: normalizeImageUrl(data['imageUrl'] ?? ''),
      sizes: List<String>.from(data['sizes'] ?? ['S', 'M', 'L', 'XL']),
      category: data['category'] ?? '',
    );
  }
}
