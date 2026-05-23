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
    if (url.isEmpty) return '';
    // Only allow Cloudinary images
    if (url.toLowerCase().contains('cloudinary.com')) {
      return url;
    }
    return '';
  }
  // Adds a unique timestamp to force the image to bypass cache when the document is re-fetched
  static String _bustCache(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('data:image/')) return url; // Don't bust base64
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (url.contains('?')) {
      return '$url&v=$timestamp';
    } else {
      return '$url?v=$timestamp';
    }
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: _bustCache(normalizeImageUrl(data['imageUrl'] ?? '')),
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
      imageUrl: _bustCache(normalizeImageUrl(data['imageUrl'] ?? '')),
      sizes: List<String>.from(data['sizes'] ?? ['S', 'M', 'L', 'XL']),
      category: data['category'] ?? '',
    );
  }
}
