import 'package:flutter/foundation.dart' hide Category;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/shipping_address.dart';
import '../models/payment_method.dart';
import '../models/promo_code.dart';
import '../models/category.dart';
import '../models/user_settings.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Products
  Stream<List<Product>> getProductsStream() {
    return _db.collection('products').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Cart
  Stream<List<CartItem>> getCartStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('cart')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CartItem.fromMap(data);
      }).toList();
    });
  }

  Future<void> addToCart(String userId, Product product, String selectedSize, int quantity) async {
    if (userId.isEmpty) return;
    final docId = '${product.id}_$selectedSize';
    final docRef = _db.collection('users').doc(userId).collection('cart').doc(docId);
    
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({
        'quantity': FieldValue.increment(quantity),
      });
    } else {
      await docRef.set({
        'product': product.toMap(),
        'quantity': quantity,
        'selectedSize': selectedSize,
      });
    }
  }

  Future<void> updateCartItemQuantity(String userId, String productId, String selectedSize, int newQuantity) async {
    if (userId.isEmpty) return;
    final docId = '${productId}_$selectedSize';
    final docRef = _db.collection('users').doc(userId).collection('cart').doc(docId);
    if (newQuantity <= 0) {
      await docRef.delete();
    } else {
      await docRef.update({'quantity': newQuantity});
    }
  }

  Future<void> removeFromCart(String userId, String productId, String selectedSize) async {
    if (userId.isEmpty) return;
    final docId = '${productId}_$selectedSize';
    await _db.collection('users').doc(userId).collection('cart').doc(docId).delete();
  }

  Future<void> clearCart(String userId) async {
    if (userId.isEmpty) return;
    final cartRef = _db.collection('users').doc(userId).collection('cart');
    final snapshots = await cartRef.get();
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Orders
  Stream<List<OrderModel>> getOrdersStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // User Profile
  Stream<Map<String, dynamic>> getUserProfileStream(String userId) {
    if (userId.isEmpty) return Stream.value({});
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      return doc.data() ?? {};
    });
  }

  Future<void> createUserProfile(String userId, String name, String email) async {
    final docRef = _db.collection('users').doc(userId);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'name': name,
        'email': email,
        'profileType': 'Men Profile',
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return;
    await _db.collection('users').doc(userId).set(data, SetOptions(merge: true));
  }

  Future<void> updateUserProfileImage(String userId, String imageUrl) async {
    if (userId.isEmpty) return;
    // IMPORTANT: Only store the Base64 string in ONE field to avoid
    // exceeding Firestore's 1 MB document size limit.
    // Previously this was stored in both profileImage AND photoUrl,
    // which doubled the size and caused RESOURCE_EXHAUSTED errors.
    await _db.collection('users').doc(userId).set({
      'profileImage': imageUrl,
      'photoUrl': '',  // Clear to save space — profileImage is the source of truth
    }, SetOptions(merge: true));
  }

  // Wishlist
  Stream<List<Product>> getWishlistStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromMap(doc.data());
      }).toList();
    });
  }

  Future<void> toggleWishlist(String userId, Product product) async {
    if (userId.isEmpty) return;
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(product.id);
    
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set(product.toMap());
    }
  }

  Stream<bool> isProductWishlisted(String userId, String productId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(productId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Shipping Addresses
  Stream<List<ShippingAddress>> getAddressesStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ShippingAddress.fromFirestore(doc);
      }).toList();
    });
  }

  Future<void> addAddress(String userId, ShippingAddress address) async {
    if (userId.isEmpty) return;
    final docRef = _db.collection('users').doc(userId).collection('addresses').doc();
    final newAddress = address.copyWith(id: docRef.id);
    await docRef.set(newAddress.toMap());
    if (newAddress.isDefault) {
      await setDefaultAddress(userId, newAddress.id);
    }
  }

  Future<void> updateAddress(String userId, ShippingAddress address) async {
    if (userId.isEmpty || address.id.isEmpty) return;
    final docRef = _db.collection('users').doc(userId).collection('addresses').doc(address.id);
    await docRef.set(address.toMap(), SetOptions(merge: true));
    if (address.isDefault) {
      await setDefaultAddress(userId, address.id);
    }
  }

  Future<void> deleteAddress(String userId, String addressId) async {
    if (userId.isEmpty || addressId.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  Future<void> setDefaultAddress(String userId, String addressId) async {
    if (userId.isEmpty || addressId.isEmpty) return;
    final batch = _db.batch();
    final addressesRef = _db.collection('users').doc(userId).collection('addresses');
    
    final snapshots = await addressesRef.get();
    for (var doc in snapshots.docs) {
      if (doc.id == addressId) {
        batch.update(doc.reference, {'isDefault': true});
      } else if (doc.data()['isDefault'] == true) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }
    await batch.commit();
  }

  Future<void> placeOrder({
    required String userId,
    required List<CartItem> items,
    required double totalAmount,
    required ShippingAddress shippingAddress,
    String? promoCode,
    double? discountAmount,
  }) async {
    if (userId.isEmpty) return;
    final orderRef = _db.collection('users').doc(userId).collection('orders').doc();
    final newOrder = OrderModel(
      id: orderRef.id,
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      orderDate: DateTime.now(),
      shippingAddress: shippingAddress,
      promoCode: promoCode,
      discountAmount: discountAmount,
    );
    await orderRef.set(newOrder.toMap());
    await clearCart(userId);
  }

  // Payment Methods
  Stream<List<PaymentMethod>> getPaymentMethodsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('payment_methods')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentMethod.fromMap(doc.data()))
            .toList());
  }

  Future<void> addPaymentMethod(String userId, PaymentMethod paymentMethod) async {
    if (userId.isEmpty) return;
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('payment_methods')
        .doc();
    
    final newMethod = paymentMethod.copyWith(id: docRef.id);
    await docRef.set(newMethod.toMap());

    if (newMethod.isDefault) {
      await setDefaultPaymentMethod(userId, docRef.id);
    }
  }

  Future<void> updatePaymentMethod(String userId, PaymentMethod paymentMethod) async {
    if (userId.isEmpty || paymentMethod.id.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('payment_methods')
        .doc(paymentMethod.id)
        .update(paymentMethod.toMap());

    if (paymentMethod.isDefault) {
      await setDefaultPaymentMethod(userId, paymentMethod.id);
    }
  }

  Future<void> deletePaymentMethod(String userId, String cardId) async {
    if (userId.isEmpty || cardId.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('payment_methods')
        .doc(cardId)
        .delete();
  }

  Future<void> setDefaultPaymentMethod(String userId, String cardId) async {
    if (userId.isEmpty || cardId.isEmpty) return;
    final batch = _db.batch();
    final cardsRef = _db.collection('users').doc(userId).collection('payment_methods');
    
    final snapshots = await cardsRef.get();
    for (var doc in snapshots.docs) {
      if (doc.id == cardId) {
        batch.update(doc.reference, {'isDefault': true});
      } else if (doc.data()['isDefault'] == true) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }
    await batch.commit();
  }

  // Promo Codes
  Stream<List<PromoCode>> getPromoCodesStream() {
    return _db
        .collection('promocodes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PromoCode.fromMap(doc.data())).toList());
  }

  Future<PromoCode?> getPromoCode(String code) async {
    if (code.isEmpty) return null;
    final query = await _db
        .collection('promocodes')
        .where('code', isEqualTo: code.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final promo = PromoCode.fromMap(query.docs.first.data());
    
    // Check expiry
    if (promo.expiryDate.isBefore(DateTime.now())) {
      return null;
    }
    return promo;
  }

  Future<void> seedDefaultPromoCodes() async {
    final query = await _db.collection('promocodes').limit(1).get();
    if (query.docs.isEmpty) {
      final batch = _db.batch();
      
      final codes = [
        PromoCode(
          id: 'welcome10',
          code: 'WELCOME10',
          discountPercentage: 10.0,
          description: 'Get 10% off your first fashion order!',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          isActive: true,
        ),
        PromoCode(
          id: 'fashion20',
          code: 'FASHION20',
          discountPercentage: 20.0,
          description: 'Flash sale! Save 20% on all fashion products.',
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
        ),
        PromoCode(
          id: 'vip30',
          code: 'VIP30',
          discountPercentage: 30.0,
          description: 'Exclusive 30% discount for VIP shoppers.',
          expiryDate: DateTime.now().add(const Duration(days: 90)),
          isActive: true,
        ),
      ];

      for (var code in codes) {
        final docRef = _db.collection('promocodes').doc(code.id);
        batch.set(docRef, code.toMap());
      }
      await batch.commit();
    }
  }

  // Categories
  Stream<List<Category>> getCategoriesStream() {
    return _db
        .collection('categories')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList());
  }

  Future<void> seedDefaultCategories() async {
    final batch = _db.batch();
    final defaultCategories = [
      {'id': 'men', 'name': 'Men'},
      {'id': 'tops', 'name': 'Tops'},
      {'id': 'pants', 'name': 'Pants'},
      {'id': 'accessories', 'name': 'Accessories'},
      {'id': 'shoes', 'name': 'Shoes'},
    ];

    for (var cat in defaultCategories) {
      final docRef = _db.collection('categories').doc(cat['id']!);
      batch.set(docRef, {'name': cat['name']}, SetOptions(merge: true));
    }
    await batch.commit();

    // Explicitly delete 'dresses' category if it exists
    await _db.collection('categories').doc('dresses').delete();
  }

  // User Settings
  Stream<UserSettings> getUserSettingsStream(String userId) {
    if (userId.isEmpty) return Stream.value(const UserSettings());
    return _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return const UserSettings();
      }
      return UserSettings.fromMap(doc.data()!);
    });
  }

  Future<void> updateUserSettings(String userId, UserSettings settings) async {
    if (userId.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences')
        .set(settings.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteUserAccountData(String userId) async {
    if (userId.isEmpty) return;

    // Delete subcollections
    final collections = ['cart', 'addresses', 'payment_methods', 'orders', 'settings'];
    for (var colName in collections) {
      final snapshot = await _db.collection('users').doc(userId).collection(colName).get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Delete main user document
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> seedDefaultProducts() async {
    final defaultProducts = [
      {
        'id': 'men_shirt',
        'name': 'Classic White Linen Shirt',
        'description': 'A premium, lightweight, and highly breathable white linen shirt, designed for a relaxed and sophisticated summer look.',
        'price': 89.99,
        'imageUrl': '',
        'category': 'Men',
        'sizes': ['S', 'M', 'L', 'XL'],
      },
      {
        'id': 'casual_jacket',
        'name': 'Casual Bomber Jacket',
        'description': 'A versatile and stylish bomber jacket tailored for a modern fit, featuring premium hardware and comfortable ribbed cuffs.',
        'price': 149.99,
        'imageUrl': '',
        'category': 'Men',
        'sizes': ['M', 'L', 'XL'],
      },
      {
        'id': 'linen_trousers',
        'name': 'Linen Drawstring Trousers',
        'description': 'Tailored from lightweight linen blend, these trousers feature an elastic waistband and drawstring for ultimate comfort and refined look.',
        'price': 110.00,
        'imageUrl': '',
        'category': 'Pants',
        'sizes': ['S', 'M', 'L', 'XL'],
      },
      {
        'id': 'silk_scarf',
        'name': 'Luxury Silk Scarf',
        'description': 'Made from 100% mulberry silk, this elegant scarf features a unique hand-rolled hem and signature branding.',
        'price': 45.00,
        'imageUrl': '',
        'category': 'Accessories',
        'sizes': ['One Size'],
      },
      {
        'id': 'mens_tshirt',
        'name': "Men's Regular Fit T-Shirt",
        'description': "A classic regular fit t-shirt made of 100% cotton, perfect for everyday casual wear. Features a durable crew neck and premium stitching.",
        'price': 25.00,
        'imageUrl': '',
        'category': 'Men',
        'sizes': ['S', 'M', 'L', 'XL', 'XXL'],
      },
      {
        'id': 'nike_air_max',
        'name': 'Nike Air Max',
        'description': 'Revolutionary Air technology provides lightweight cushioning. Features a mesh and leather upper for durability, comfort, and premium street style.',
        'price': 129.99,
        'imageUrl': '',
        'category': 'Shoes',
        'sizes': ['8', '9', '10', '11'],
      },
      {
        'id': 'summer_shirt',
        'name': 'Summer Floral Shirt',
        'description': 'Stay cool and stylish this summer with this lightweight floral print cotton shirt, featuring a relaxed collar and breathable fabric.',
        'price': 39.99,
        'imageUrl': '',
        'category': 'Men',
        'sizes': ['S', 'M', 'L', 'XL'],
      },
      {
        'id': 'classic_wool_coat',
        'name': 'Classic Wool Coat',
        'description': 'Elegant long wool coat with a modern tailored fit, featuring a soft fabric finish, waist belt, and premium winter comfort.',
        'price': 129.99,
        'imageUrl': '',
        'category': 'Tops',
        'sizes': ['S', 'M', 'L', 'XL'],
      },
    ];

    final batch = _db.batch();
    for (var prod in defaultProducts) {
      final docRef = _db.collection('products').doc(prod['id'] as String);
      batch.set(docRef, prod, SetOptions(merge: true));
    }
    await batch.commit();

    // Clean up any legacy or duplicate products not in the default list
    try {
      final validIds = defaultProducts.map((prod) => prod['id'] as String).toSet();
      final productsSnapshot = await _db.collection('products').get();
      for (var doc in productsSnapshot.docs) {
        if (!validIds.contains(doc.id)) {
          debugPrint('Deleting legacy/duplicate product from Firestore: ${doc.id} ("${doc.data()['name']}")');
          await _db.collection('products').doc(doc.id).delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up legacy products: $e');
    }
  }
}
