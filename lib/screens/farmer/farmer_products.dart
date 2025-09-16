import 'dart:io';

import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:village_market/utils/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';

class FarmerProducts extends StatefulWidget {
  const FarmerProducts({super.key});

  @override
  State<FarmerProducts> createState() => _FarmerProductsState();
}

class _FarmerProductsState extends State<FarmerProducts> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = AppConstants.productCategories.first;
  List<Map<String, dynamic>> _products = [];
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  TabController? _tabController;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id') ?? 1;
      
      final products = await db.query(
        'products',
        where: 'farmer_id = ?',
        whereArgs: [farmerId],
      );
      setState(() => _products = products);
    } catch (e) {
      _showError('Failed to load products');
    }
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? imagePath;
      if (_imageFile != null) {
        final appDir = await path_provider.getApplicationDocumentsDirectory();
        final fileName = path.basename(_imageFile!.path);
        final savedImage = await _imageFile!.copy('${appDir.path}/$fileName');
        imagePath = savedImage.path;
      }

      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id') ?? 1;
      
      await db.insert('products', {
        'name': _nameController.text,
        'price': double.parse(_priceController.text),
        'category': _selectedCategory,
        'description': _descriptionController.text,
        'image': imagePath,
        'farmer_id': farmerId,
        'created_at': DateTime.now().toIso8601String(),
      });

      _clearForm();
      _loadProducts();
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to add product: $e');
    }
  }

  Future<void> _updateProduct(Map<String, dynamic> product) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'products',
        {
          'name': _nameController.text,
          'price': double.parse(_priceController.text),
          'category': _selectedCategory,
          'description': _descriptionController.text,
        },
        where: 'id = ?',
        whereArgs: [product['id']],
      );
      _clearForm();
      _loadProducts();
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to update product');
    }
  }

  Future<void> _deleteProduct(int id) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      _loadProducts();
    } catch (e) {
      _showError('Failed to delete product');
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _selectedCategory = AppConstants.productCategories.first;
    _imageFile = null;
  }

  void _showAddProductDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add Product',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _imageFile != null
                          ? Image.file(_imageFile!, fit: BoxFit.cover)
                          : const Icon(Icons.add_a_photo, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: AppConstants.productCategories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addProduct,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    _nameController.text = product['name'];
    _priceController.text = product['price'].toString();
    _descriptionController.text = product['description'] ?? '';
    _selectedCategory = product['category'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Edit Product',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: AppConstants.productCategories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _updateProduct(product),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    if (_selectedFilter == 'All') {
      return _products;
    } else {
      return _products.where((product) => product['category'] == _selectedFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Products'),
            Tab(text: 'My Products'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Categories')),
              ...AppConstants.productCategories.map(
                (category) => PopupMenuItem(value: category, child: Text(category)),
              ),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Products Tab
          ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: product['image'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(product['image']),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                  title: Text(product['name']),
                  subtitle: Text(
                    '${product['category']} - ৳${product['price']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditProductDialog(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(product['id']),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Show product details
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(product['name']),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product['image'] != null)
                              Image.file(
                                File(product['image']),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            const SizedBox(height: 16),
                            Text('Category: ${product['category']}'),
                            Text('Price: ৳${product['price']}'),
                            const SizedBox(height: 8),
                            Text('Description: ${product['description']}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          
          // My Products Tab
          ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: product['image'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(product['image']),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                  title: Text(product['name']),
                  subtitle: Text(
                    '${product['category']} - ৳${product['price']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditProductDialog(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(product['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _tabController?.dispose();
    super.dispose();
  }
}
