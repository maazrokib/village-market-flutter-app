import 'dart:io';
import 'package:flutter/material.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/screens/buyer/buyer_checkout.dart';

class BuyerCart extends StatefulWidget {
  const BuyerCart({super.key});

  @override
  State<BuyerCart> createState() => _BuyerCartState();
}

class _BuyerCartState extends State<BuyerCart> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  double _totalAmount = 0.0;
  int _userId = 1;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id') ?? 1;
      print('Cart screen initialized with user_id: $_userId');
      await _loadCartItems();
    } catch (e) {
      print('Error initializing cart: $e');
      _showError('Failed to initialize cart: $e');
    }
  }

  Future<void> _loadCartItems() async {
    setState(() => _isLoading = true);
    try {
      final cart = HiveService.getCart(_userId);
      final products = { for (final p in HiveService.getAllProducts()) p['id']: p };
      final enriched = cart.map((c) {
        final p = products[c['product_id']];
        return {
          'cart_id': c['id'],
          'product_id': c['product_id'],
          'quantity': c['quantity'],
          'name': p?['name'] ?? 'Unknown Product',
          'price': p?['price'] ?? 0,
          'image': p?['image'] ?? '',
          'category': p?['category'] ?? 'Unknown',
          'farmer_name': '',
        };
      }).toList();
      setState(() { _cartItems = enriched; _calculateTotal(); });
    } catch (e) {
      print('Error loading cart items in cart screen: $e');
      
      // Fallback to Hive if there's an issue
      try {
        final cart = HiveService.getCart(_userId);
        print('Hive cart query returned ${cart.length} items');
        print('Hive cart items: $cart');
      } catch (e2) {
        print('Hive cart query also failed: $e2');
      }
      
      _showError('Failed to load cart items: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCartItem(int cartId, int quantity) async {
    if (quantity < 1) return;
    try {
      await HiveService.updateCartQuantity(cartId, quantity);
      await _loadCartItems();
    } catch (e) {
      _showError('Failed to update cart item');
    }
  }

  Future<void> _removeFromCart(int cartId) async {
    try {
      await HiveService.removeCartItem(cartId);
      await _loadCartItems();
      _showMessage('Item removed from cart');
    } catch (e) {
      _showError('Failed to remove item from cart');
    }
  }

  void _calculateTotal() {
    double total = 0.0;
    for (var item in _cartItems) {
      total += (item['price'] as num) * (item['quantity'] as num);
    }
    _totalAmount = total;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _proceedToCheckout() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BuyerCheckout(
            cartItems: _cartItems,
            isDirectPurchase: false,
          ),
        ),
      );
      await _loadCartItems();
    } catch (e) {
      _showError('Failed to proceed to checkout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('Manual refresh triggered');
              _loadCartItems();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Add items to your cart to continue shopping', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.shopping_bag),
                        label: const Text('Continue Shopping'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadCartItems,
                        child: ListView.builder(
                          itemCount: _cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            final itemTotal = (item['price'] as num) * (item['quantity'] as num);
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                leading: item['image'] != null && item['image'].toString().isNotEmpty
                                    ? Image.file(File(item['image']), width: 60, height: 60, fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 60),
                                title: Text(item['name']),
                                subtitle: Text('৳${item['price'].toStringAsFixed(2)} x ${item['quantity']} = ৳${itemTotal.toStringAsFixed(2)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => _updateCartItem(item['cart_id'], (item['quantity'] as int) + 1),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => _updateCartItem(item['cart_id'], (item['quantity'] as int) - 1),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeFromCart(item['cart_id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[200],
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('৳${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _cartItems.isEmpty ? null : _proceedToCheckout,
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: const Text('Proceed to Checkout'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
