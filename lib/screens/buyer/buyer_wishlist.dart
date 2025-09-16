import 'dart:io';
import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/screens/buyer/buyer_checkout.dart';

class BuyerWishlist extends StatefulWidget {
  const BuyerWishlist({super.key});

  @override
  State<BuyerWishlist> createState() => _BuyerWishlistState();
}

class _BuyerWishlistState extends State<BuyerWishlist> {
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoading = true;
  int _userId = 1;

  @override
  void initState() {
    super.initState();
    _loadWishlistItems();
  }

  Future<void> _loadWishlistItems() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id') ?? 1;

      final wishlistItems = await db.rawQuery('''
        SELECT w.id as wishlist_id, p.*
        FROM wishlist w
        JOIN products p ON w.product_id = p.id
        WHERE w.buyer_id = ?
      ''', [_userId]);

      setState(() => _wishlistItems = wishlistItems);
    } catch (e) {
      _showError('Failed to load wishlist items: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(int wishlistId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('wishlist', where: 'id = ?', whereArgs: [wishlistId]);
      _loadWishlistItems();
      _showMessage('Item removed from wishlist');
    } catch (e) {
      _showError('Failed to remove item');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      if (product['id'] == null) {
        print('Product ID is null in wishlist');
        _showError('Product ID is missing');
        return;
      }
      
      final db = await DatabaseHelper().database;
      print('Adding to cart from wishlist: product_id=${product['id']}, buyer_id=$_userId');

      final existingCartItems = await db.query(
        'cart',
        where: 'buyer_id = ? AND product_id = ?',
        whereArgs: [_userId, product['id']],
      );

      if (existingCartItems.isEmpty) {
        await db.insert('cart', {'buyer_id': _userId, 'product_id': product['id'], 'quantity': 1});
        print('Inserted new cart item from wishlist');
      } else {
        final existingItem = existingCartItems.first;
        await db.update('cart', {'quantity': (existingItem['quantity'] as int) + 1}, where: 'id = ?', whereArgs: [existingItem['id']]);
        print('Updated cart quantity from wishlist');
      }

      // Remove from wishlist after adding to cart
      final wishlistId = product['wishlist_id'] as int?;
      if (wishlistId != null) {
        await db.delete('wishlist', where: 'id = ?', whereArgs: [wishlistId]);
        print('Removed from wishlist by id: $wishlistId');
      } else {
        // Fallback delete by buyer and product
        await db.delete('wishlist', where: 'buyer_id = ? AND product_id = ?', whereArgs: [_userId, product['id']]);
        print('Removed from wishlist by buyer and product');
      }

      await _loadWishlistItems();
      _showMessage('Added to cart and removed from wishlist');
    } catch (e) {
      print('Error adding to cart from wishlist: $e');
      _showError('Failed to add to cart: $e');
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
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuyerCheckout(
          cartItems: [checkoutItem],
          isDirectPurchase: true,
        ),
      ),
    ).then((_) => _loadWishlistItems());
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Wishlist'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadWishlistItems),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wishlistItems.isEmpty
              ? const Center(child: Text('Your wishlist is empty'))
              : ListView.builder(
                  itemCount: _wishlistItems.length,
                  itemBuilder: (context, index) {
                    final item = _wishlistItems[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: item['image'] != null && item['image'].toString().isNotEmpty
                            ? Image.file(File(item['image']), width: 60, height: 60, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 60),
                        title: Text(item['name']),
                        subtitle: Text('৳${item['price']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => _addToCart(item)),
                            IconButton(icon: const Icon(Icons.shopping_bag), onPressed: () => _buyNow(item)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeFromWishlist(item['wishlist_id'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
