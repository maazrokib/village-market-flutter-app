import 'package:village_market/database/database_helper.dart';

class SampleData {
  static Future<void> insertSampleData() async {
    final db = await DatabaseHelper().database;
    
    // Check if data already exists
    final users = await db.query('users');
    if (users.isNotEmpty) {
      print('Sample data already exists, skipping...');
      return;
    }
    
    // Insert sample users
    await db.insert('users', {
      'name': 'Admin User',
      'email': 'admin@villagemarket.com',
      'password': 'admin123',
      'phone': '+8801234567890',
      'address': 'Dhaka, Bangladesh',
      'role': 'admin',
      'status': 'active',
    });
    
    await db.insert('users', {
      'name': 'Farmer John',
      'email': 'farmer@example.com',
      'password': 'farmer123',
      'phone': '+8801234567891',
      'address': 'Village Road, Dhaka',
      'role': 'farmer',
      'status': 'active',
    });
    
    await db.insert('users', {
      'name': 'Buyer Smith',
      'email': 'buyer@example.com',
      'password': 'buyer123',
      'phone': '+8801234567892',
      'address': 'City Center, Dhaka',
      'role': 'buyer',
      'status': 'active',
    });
    
    // Insert sample products
    await db.insert('products', {
      'name': 'Fresh Tomatoes',
      'price': 50.0,
      'category': 'Vegetables',
      'description': 'Fresh organic tomatoes from local farm',
      'image': null,
      'farmer_id': 2, // Farmer John's ID
      'created_at': DateTime.now().toIso8601String(),
    });
    
    await db.insert('products', {
      'name': 'Green Apples',
      'price': 80.0,
      'category': 'Fruits',
      'description': 'Crispy green apples, perfect for snacking',
      'image': null,
      'farmer_id': 2,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    await db.insert('products', {
      'name': 'Fresh Milk',
      'price': 60.0,
      'category': 'Dairy',
      'description': 'Fresh cow milk, delivered daily',
      'image': null,
      'farmer_id': 2,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    await db.insert('products', {
      'name': 'Brown Rice',
      'price': 40.0,
      'category': 'Grains',
      'description': 'Organic brown rice, high quality',
      'image': null,
      'farmer_id': 2,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    print('Sample data inserted successfully!');
  }
}

