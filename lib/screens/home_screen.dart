import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../widgets/product_card.dart';
import '../theme/app_theme.dart';
import '../screens/product_listing_screen.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';

  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Using products from Firestore

  List<Product> _getFilteredProducts(List<Product> products) {
    return products.where((p) {
      if (p.category.toLowerCase() == 'dresses') return false;
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  bool get _isSearching => _searchQuery.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Product>>(
        stream: FirestoreService().getProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allProducts = snapshot.data ?? [];
          final filtered = _getFilteredProducts(allProducts);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 16),

                  // ── Search Bar ──────────────────────────────────────────
                  TextFormField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search clothes, accessories...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Show search results count when searching
                  if (_isSearching) ...[
                    Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'} for "$_searchQuery"',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Categories (hidden while searching) ─────────────────
                  if (!_isSearching) ...[
                    StreamBuilder<List<Category>>(
                      stream: FirestoreService().getCategoriesStream(),
                      builder: (context, catSnapshot) {
                        if (catSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final dbCategories = catSnapshot.data ?? [];
                        final categoryNames = [
                          'All',
                          ...dbCategories
                              .map((c) => c.name)
                              .where((name) => name.toLowerCase() != 'dresses')
                        ];

                        if (!categoryNames.contains(_selectedCategory)) {
                          _selectedCategory = 'All';
                        }

                        return SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: categoryNames.length,
                            itemBuilder: (context, index) {
                              final catName = categoryNames[index];
                              final isSelected = _selectedCategory == catName;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedCategory = catName);
                                  if (index != 0) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductListingScreen(
                                          categoryName: catName,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primaryText
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryText
                                          : AppTheme.secondaryText.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    catName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).scaffoldBackgroundColor
                                          : AppTheme.secondaryText,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Promo Banner ────────────────────────────────────────
Container(
  width: double.infinity,
  height: 160,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    image: const DecorationImage(
      image: NetworkImage(
        'https://res.cloudinary.com/dvqbzsh71/image/upload/v1779264122/banner_mcdfzc.jpg',
      ),
      fit: BoxFit.cover,
    ),
  ),
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 0.6),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'New Collection',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),
        
        Text(
          'Up to 50% off',
          style: TextStyle(
            color: AppTheme.accentColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
),

const SizedBox(height: 32),
        ], 
                  // ── Featured / Results header ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isSearching ? 'Search Results' : 'Featured Items',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (!_isSearching)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductListingScreen(
                                  categoryName: 'All Products',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'See All',
                            style: TextStyle(color: AppTheme.secondaryText),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Product Grid ─────────────────────────────────────────
                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 56,
                              color: AppTheme.secondaryText,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppTheme.secondaryText),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return ProductCard(product: filtered[index]);
                      },
                    ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
