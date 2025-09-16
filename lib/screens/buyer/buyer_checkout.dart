import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:village_market/screens/buyer/buyer_orders.dart';

class BuyerCheckout extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final bool isDirectPurchase;

  const BuyerCheckout({
    super.key,
    required this.cartItems,
    this.isDirectPurchase = false,
  });

  @override
  State<BuyerCheckout> createState() => _BuyerCheckoutState();
}

class _BuyerCheckoutState extends State<BuyerCheckout> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotal();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Calculate total amount from cart items
  void _calculateTotal() {
    double total = 0;
    for (var item in widget.cartItems) {
      total += (item['price'] as num) * (item['quantity'] as num);
    }
    setState(() => _totalAmount = total);
  }

  // Load user information from shared preferences
  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final db = await DatabaseHelper().database;

      if (userId != null) {
        final users = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );

        if (users.isNotEmpty) {
          final user = users.first;
          setState(() {
            _nameController.text = user['name'] as String? ?? '';
            _phoneController.text = user['phone'] as String? ?? '';
            _addressController.text = user['address'] as String? ?? '';
          });
        }
      }
    } catch (e) {
      _showError('Failed to load user information: $e');
    }
  }

  // Process the order
  Future<void> _processOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: const Text('Are you sure you want to place this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;
      final orderDate = DateTime.now().toIso8601String();

      // Store shipping information in shared preferences for future use
      await prefs.setString('buyer_name', _nameController.text);
      await prefs.setString('buyer_phone', _phoneController.text);
      await prefs.setString('buyer_address', _addressController.text);

      // Update user profile with shipping information if available
      try {
        await db.update(
          'users',
          {
            'phone': _phoneController.text,
            'address': _addressController.text,
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
      } catch (e) {
        print('Non-critical error updating user profile: $e');
        // Continue with order placement even if profile update fails
      }

      // Process each item as a separate order in the existing schema
      for (var item in widget.cartItems) {
        try {
          // Debug: Print product and farmer info
          final productId = item['product_id'];
          final product = await db.query('products', where: 'id = ?', whereArgs: [productId]);
          if (product.isNotEmpty) {
            print('Placing order for product_id: '
              '\x1B[32m$productId\x1B[0m, '
              'farmer_id: \x1B[34m${product.first['farmer_id']}\x1B[0m, '
              'buyer_id: \x1B[36m$userId\x1B[0m');
          } else {
            print('Product not found for product_id: $productId');
          }
          // Try to insert with the new schema first
          await db.insert('orders', {
            'buyer_id': userId,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'total_price': (item['price'] as num) * (item['quantity'] as num),
            'status': 'pending',
            'shipping_address': _addressController.text,
            'contact_number': _phoneController.text,
            'buyer_name': _nameController.text,
            'created_at': orderDate,
          });
        } catch (e) {
          print('Error with new schema, trying old schema: $e');
          // If that fails, try with the old schema
          await db.insert('orders', {
            'buyer_id': userId,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'total_price': (item['price'] as num) * (item['quantity'] as num),
            'status': 'pending',
            'created_at': orderDate,
          });
        }
      }

      // If not direct purchase, clear the cart
      if (!widget.isDirectPurchase) {
        await db.delete(
          'cart',
          where: 'buyer_id = ?',
          whereArgs: [userId],
        );
      }

      // Show success message and navigate back
      _showSuccess('Order placed successfully!');
      
      // Show order confirmation dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Order Placed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your order has been placed successfully!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: ৳${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  child: const Text('View Home'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    // Navigate to orders screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BuyerOrders(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  child: const Text('View Orders'),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error placing order: $e');
      _showError('Failed to place order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // List of items
                          ...widget.cartItems.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    // Product image
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey[200],
                                      ),
                                      child: item['image'] != null &&
                                              item['image'].toString().isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(item['image']),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, stackTrace) =>
                                                        const Icon(Icons.image),
                                              ),
                                            )
                                          : const Icon(Icons.image),
                                    ),
                                    const SizedBox(width: 16),
                                    // Product details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '৳${item['price'].toStringAsFixed(2)} × ${item['quantity']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Item total
                                    Text(
                                      '৳${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(),
                          // Total amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '৳${_totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Shipping information form
                  Form(
                    key: _formKey,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shipping Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Name field
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Phone field
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Address field
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Shipping Address',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your shipping address';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Place order button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _processOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Place Order',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
