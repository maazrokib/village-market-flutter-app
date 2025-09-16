import 'dart:io';
import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/screens/buyer/buyer_cart.dart';
import 'package:village_market/screens/buyer/buyer_checkout.dart';
import 'package:village_market/screens/buyer/buyer_wishlist.dart';

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
    final db = await DatabaseHelper().database;
    final products = await db.query('products', orderBy: 'name ASC');
    
    print('Loaded ${products.length} products');
    if (products.isNotEmpty) {
      print('First product: ${products.first}');
    }

    final categorySet = <String>{'All'};
    for (var product in products) {
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
    try {
      final db = await DatabaseHelper().database;
      
      // First check cart count
      final cartCount = await db.rawQuery('SELECT COUNT(*) as c FROM cart WHERE buyer_id = ?', [_userId]);
      print('Home screen: Cart has ${cartCount.first['c']} items for user $_userId');
      
      final cartItems = await db.rawQuery(
        '''
        SELECT c.*, 
               COALESCE(p.name, 'Unknown Product') as name,
               COALESCE(p.price, 0) as price,
               COALESCE(p.image, '') as image,
               COALESCE(p.category, 'Unknown') as category
        FROM cart c
        LEFT JOIN products p ON c.product_id = p.id
        WHERE c.buyer_id = ?
        ''',
        [_userId],
      );
      print('Home screen: Loaded ${cartItems.length} cart items for user $_userId');
      if (cartItems.isNotEmpty) {
        print('Home screen: First cart item: ${cartItems.first}');
      }
      setState(() => _cartItems = cartItems);
    } catch (e) {
      print('Home screen: Error loading cart items: $e');
      
      // Try simple query
      try {
        final db = await DatabaseHelper().database;
        final simpleCart = await db.query('cart', where: 'buyer_id = ?', whereArgs: [_userId]);
        print('Home screen: Simple cart query returned ${simpleCart.length} items');
      } catch (e2) {
        print('Home screen: Simple cart query also failed: $e2');
      }
    }
  }

  Future<void> _loadWishlistItems() async {
    final db = await DatabaseHelper().database;
    final wishlistItems = await db.rawQuery(
      '''
      SELECT w.*, p.name, p.price, p.image, p.category
      FROM wishlist w
      JOIN products p ON w.product_id = p.id
      WHERE w.buyer_id = ?
      ''',
      [_userId],
    );
    setState(() => _wishlistItems = wishlistItems);
  }

  Future<void> _addToWishlist(Map<String, dynamic> product) async {
    final db = await DatabaseHelper().database;
    final existing = await db.query(
      'wishlist',
      where: 'buyer_id = ? AND product_id = ?',
      whereArgs: [_userId, product['id']],
    );

    if (existing.isEmpty) {
      await db.insert('wishlist', {
        'buyer_id': _userId,
        'product_id': product['id'],
      });
      _showMessage('Added to wishlist');
    } else {
      await db.delete(
        'wishlist',
        where: 'buyer_id = ? AND product_id = ?',
        whereArgs: [_userId, product['id']],
      );
      _showMessage('Removed from wishlist');
    }

    await _loadWishlistItems();
    if (widget.onCartOrWishlistChanged != null) {
      await widget.onCartOrWishlistChanged!();
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      if (product['id'] == null) {
        print('Product ID is null');
        _showMessage('Product ID is missing');
        return;
      }
      
      final db = await DatabaseHelper().database;
      print('Adding to cart: product_id=${product['id']}, buyer_id=$_userId');
      
      // First check if product exists
      final productCheck = await db.query('products', where: 'id = ?', whereArgs: [product['id']]);
      print('Product exists: ${productCheck.isNotEmpty}');
      
      final existing = await db.query(
        'cart',
        where: 'buyer_id = ? AND product_id = ?',
        whereArgs: [_userId, product['id']],
      );
      print('Existing cart items: ${existing.length}');

      int currentQuantity = 0;
      if (existing.isNotEmpty) {
        currentQuantity = existing.first['quantity'] as int;
      }

      if (existing.isEmpty) {
        final result = await db.insert('cart', {
          'buyer_id': _userId,
          'product_id': product['id'],
          'quantity': 1,
        });
        print('Inserted new cart item with id: $result');
        _showMessage('Added to cart');
      } else {
        await db.update(
          'cart',
          {'quantity': currentQuantity + 1},
          where: 'buyer_id = ? AND product_id = ?',
          whereArgs: [_userId, product['id']],
        );
        print('Updated cart quantity to ${currentQuantity + 1}');
        _showMessage('Updated cart quantity');
      }

      // Verify the insert/update worked
      final verifyCart = await db.query('cart', where: 'buyer_id = ?', whereArgs: [_userId]);
      print('Cart now has ${verifyCart.length} items');

      await _loadCartItems();
      if (widget.onCartOrWishlistChanged != null) {
        await widget.onCartOrWishlistChanged!();
      }
    } catch (e) {
      print('Error adding to cart: $e');
      _showMessage('Error adding to cart: $e');
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
