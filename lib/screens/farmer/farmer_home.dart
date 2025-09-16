import 'dart:io';

import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:village_market/utils/constants.dart';

class FarmerHome extends StatefulWidget {
  const FarmerHome({super.key});

  @override
  State<FarmerHome> createState() => _FarmerHomeState();
}

class _FarmerHomeState extends State<FarmerHome> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // Load products from database
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final products = await db.query('products');
      setState(() => _products = products);
    } catch (e) {
      _showError('Failed to load products');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Display error messages
  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Filter products based on selected category
  List<Map<String, dynamic>> _getFilteredProducts() {
    if (_selectedCategory == 'All') {
      return _products;
    } else {
      return _products
          .where((product) => product['category'] == _selectedCategory)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();

    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Home')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Category filter chips
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedCategory == 'All',
                          onSelected: (selected) {
                            setState(() => _selectedCategory = 'All');
                          },
                        ),
                        const SizedBox(width: 8),
                        ...AppConstants.productCategories.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (selected) {
                                setState(() => _selectedCategory = category);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadProducts,
                      child:
                          filteredProducts.isEmpty
                              ? const Center(child: Text('No products found'))
                              : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          2, // Adjust this for more or fewer columns
                                      childAspectRatio:
                                          0.65, // Adjusted to give more vertical space
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];

                                  // Get product image
                                  final productImage = product['image'];

                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Image widget
                                        Expanded(
                                          flex: 3, // 3/5 of the available space
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              image:
                                                  productImage != null
                                                      ? DecorationImage(
                                                        image: FileImage(
                                                          File(productImage),
                                                        ),
                                                        fit: BoxFit.cover,
                                                        onError: (
                                                          exception,
                                                          stackTrace,
                                                        ) {
                                                          // Handle error while loading image
                                                        },
                                                      )
                                                      : null,
                                            ),
                                            child:
                                                productImage == null
                                                    ? const Icon(
                                                      Icons.image,
                                                      size: 50,
                                                      color: Colors.white,
                                                    )
                                                    : null,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2, // 2/5 of the available space
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  product['name'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '৳${product['price'].toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Category: ${product['category']}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                  ),
                ],
              ),
    );
  }
}
