import 'dart:io';
import 'package:flutter/material.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/screens/buyer/buyer_checkout.dart';

class BuyerHome extends StatefulWidget {
  final Future<void> Function()? onCartOrWishlistChanged;
  const BuyerHome({super.key, this.onCartOrWishlistChanged});

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoading = true;
  List<String> _categories = ['All'];
  int _userId = 1;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id') ?? 1;

    await Future.wait([
      _loadProducts(),
      _loadCartItems(),
      _loadWishlistItems(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadProducts() async {
    final products = HiveService.getAllProducts()..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final categorySet = <String>{'All'};
    for (final product in products) {
      if (product['category'] != null && product['category'].toString().isNotEmpty) {
        categorySet.add(product['category'].toString());
      }
    }

    setState(() {
      _products = products;
      _categories = categorySet.toList();
    });
  }

  Future<void> _loadCartItems() async {
    final cart = HiveService.getCart(_userId);
    // enrich cart with product info
    final products = { for (final p in HiveService.getAllProducts()) p['id']: p };
    final enriched = cart.map((c) {
      final p = products[c['product_id']];
      return {
        ...c,
        'name': p?['name'] ?? 'Unknown Product',
        'price': p?['price'] ?? 0,
        'image': p?['image'] ?? '',
        'category': p?['category'] ?? 'Unknown',
      };
    }).toList();
    setState(() => _cartItems = enriched);
  }

  Future<void> _loadWishlistItems() async {
    final wishlist = HiveService.getWishlist(_userId);
    final products = { for (final p in HiveService.getAllProducts()) p['id']: p };
    final enriched = wishlist.map((w) {
      final p = products[w['product_id']];
      return {
        ...w,
        'name': p?['name'] ?? 'Unknown Product',
        'price': p?['price'] ?? 0,
        'image': p?['image'] ?? '',
        'category': p?['category'] ?? 'Unknown',
      };
    }).toList();
    setState(() => _wishlistItems = enriched);
  }

  Future<void> _addToWishlist(Map<String, dynamic> product) async {
    await HiveService.toggleWishlist(buyerId: _userId, productId: product['id']);
    _showMessage('Wishlist updated');
    await _loadWishlistItems();
    if (widget.onCartOrWishlistChanged != null) {
      await widget.onCartOrWishlistChanged!();
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    if (product['id'] == null) {
      _showMessage('Product ID is missing');
      return;
    }
    await HiveService.addToCart(buyerId: _userId, productId: product['id'], quantity: 1);
    _showMessage('Cart updated');
    await _loadCartItems();
    if (widget.onCartOrWishlistChanged != null) {
      await widget.onCartOrWishlistChanged!();
    }
  }

  Future<void> _buyNow(Map<String, dynamic> product) async {
    final checkoutItem = {
      'product_id': product['id'],
      'buyer_id': _userId,
      'quantity': 1,
      'name': product['name'],
      'price': product['price'],
      'image': product['image'],
      'category': product['category'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuyerCheckout(
          cartItems: [checkoutItem],
          isDirectPurchase: true,
        ),
      ),
    ).then((_) {
      _loadProducts();
      _loadCartItems();
      _loadWishlistItems();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _selectedCategory == 'All'
        ? _products
        : _products.where((p) => p['category'] == _selectedCategory).toList();

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Category filter
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (_) => setState(() => _selectedCategory = category),
                        selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                        checkmarkColor: Theme.of(context).primaryColor,
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Product grid
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: filteredProducts.isEmpty
                      ? const Center(child: Text("No products available"))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.6,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image
                                  SizedBox(
                                    height: 120,
                                    width: double.infinity,
                                    child: product['image'] != null &&
                                            product['image'].toString().isNotEmpty
                                        ? Image.file(
                                            File(product['image']),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                        : const Center(child: Icon(Icons.image)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '৳${product['price'].toStringAsFixed(2)}',
                                          style: TextStyle(
                                              color: Theme.of(context).primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Buttons
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () => _buyNow(product),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 30),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      child: const Text('Buy Now'),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _wishlistItems.any((item) => item['product_id'] == product['id'])
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Colors.red,
                                          size: 22,
                                        ),
                                        onPressed: () => _addToWishlist(product),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_shopping_cart, size: 22),
                                        onPressed: () => _addToCart(product),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
  }
}
