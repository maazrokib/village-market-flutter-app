import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:village_market/utils/constants.dart';
import 'dart:io';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  final Map<String, int> _stats = {
    'totalUsers': 0,
    'totalFarmers': 0,
    'totalBuyers': 0,
    'totalProducts': 0,
    'totalOrders': 0,
    'pendingOrders': 0,
    'confirmedOrders': 0,
    'deliveredOrders': 0,
    'cancelledOrders': 0,
    'totalRevenue': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      
      // Load users
      _users = await db.query('users', orderBy: 'name');
      
      // Load products
      _products = await db.rawQuery('''
        SELECT p.*, u.name as farmer_name 
        FROM products p 
        JOIN users u ON p.farmer_id = u.id 
        ORDER BY p.created_at DESC
      ''');
      
      // Load orders with shipping information
      _orders = await db.rawQuery('''
        SELECT o.*, p.name as product_name, p.image, p.price, 
               b.name as buyer_name, b.email as buyer_email,
               f.name as farmer_name, f.email as farmer_email
        FROM orders o 
        JOIN products p ON o.product_id = p.id 
        JOIN users b ON o.buyer_id = b.id 
        JOIN users f ON p.farmer_id = f.id
        ORDER BY o.created_at DESC
      ''');
      
      // Calculate stats
      _stats['totalUsers'] = _users.length;
      _stats['totalFarmers'] = _users.where((u) => u['role'] == AppConstants.roleFarmer).length;
      _stats['totalBuyers'] = _users.where((u) => u['role'] == AppConstants.roleBuyer).length;
      _stats['totalProducts'] = _products.length;
      _stats['totalOrders'] = _orders.length;
      _stats['pendingOrders'] = _orders.where((o) => o['status'] == 'pending').length;
      _stats['confirmedOrders'] = _orders.where((o) => o['status'] == 'confirmed').length;
      _stats['deliveredOrders'] = _orders.where((o) => o['status'] == 'delivered').length;
      _stats['cancelledOrders'] = _orders.where((o) => o['status'] == 'cancelled').length;
      
      // Calculate revenue
      double totalRevenue = 0;
      for (var order in _orders) {
        if (order['total_price'] != null) {
          totalRevenue += order['total_price'] as double;
        }
      }
      _stats['totalRevenue'] = totalRevenue.toInt();
      
    } catch (e) {
      print('Error loading admin data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final currentStatus = user['status'];
    final newStatus = currentStatus == AppConstants.userActive 
      ? AppConstants.userBanned 
      : AppConstants.userActive;

    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'users',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [user['id']],
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${user['name']} is now $newStatus')),
      );
      
      _loadData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard Header
                Row(
                  children: [
                    Icon(
                      Icons.dashboard,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                _buildQuickStats(),
                const SizedBox(height: 24),
                _buildRecentSection('Recent Orders', _buildOrderList()),
                const SizedBox(height: 24),
                _buildRecentSection('Recent Products', _buildProductList()),
                const SizedBox(height: 24),
                _buildRecentSection('Users Management', _buildUserList()),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Total Users', _stats['totalUsers'].toString(), Icons.people),
        _buildStatCard('Total Products', _stats['totalProducts'].toString(), Icons.inventory_2),
        _buildStatCard('Total Orders', _stats['totalOrders'].toString(), Icons.shopping_bag),
        _buildStatCard('Revenue', '৳${_stats['totalRevenue']}', Icons.monetization_on),
        _buildOrderStatusCard(),
        _buildUserRolesCard(),
      ],
    );
  }
  
  Widget _buildOrderStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusIndicator('Pending', _stats['pendingOrders'], Colors.orange),
            const SizedBox(height: 4),
            _buildStatusIndicator('Confirmed', _stats['confirmedOrders'], Colors.blue),
            const SizedBox(height: 4),
            _buildStatusIndicator('Delivered', _stats['deliveredOrders'], Colors.green),
            const SizedBox(height: 4),
            _buildStatusIndicator('Cancelled', _stats['cancelledOrders'], Colors.red),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserRolesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Roles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusIndicator('Farmers', _stats['totalFarmers'], Colors.green),
            const SizedBox(height: 4),
            _buildStatusIndicator('Buyers', _stats['totalBuyers'], Colors.blue),
            const SizedBox(height: 4),
            _buildStatusIndicator('Admins', _users.where((u) => u['role'] == 'admin').length, Colors.red),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusIndicator(String label, int? count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          count?.toString() ?? '0',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection(String title, Widget content) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to detailed view
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No orders found', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _orders.length > 5 ? 5 : _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ExpansionTile(
            title: Text(
              'Order #${order['id']} - ${order['product_name'] ?? 'Unknown Product'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('By ${order['buyer_name'] ?? 'Unknown Buyer'}'),
            leading: order['image'] != null && order['image'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(order['image']),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image),
                ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(order['status']),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order['status'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Quantity: ${order['quantity']}'),
                        Text(
                          'Total: ৳${order['total_price']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    // Shipping information
                    if (order['shipping_address'] != null || order['contact_number'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shipping Information:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (order['buyer_name'] != null)
                            Text('Name: ${order['buyer_name']}'),
                          if (order['contact_number'] != null)
                            Text('Phone: ${order['contact_number']}'),
                          if (order['shipping_address'] != null)
                            Text('Address: ${order['shipping_address']}'),
                          if (order['buyer_email'] != null)
                            Text('Email: ${order['buyer_email']}'),
                          const Divider(),
                        ],
                      ),
                    // Farmer information
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller Information:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Name: ${order['farmer_name'] ?? 'Unknown'}'),
                        if (order['farmer_email'] != null)
                          Text('Email: ${order['farmer_email']}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No products found', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _products.length > 5 ? 5 : _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product['image'] != null && product['image'].toString().isNotEmpty
                ? Image.file(
                    File(product['image']),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
            ),
            title: Text(product['name'] ?? 'Unknown Product'),
            subtitle: Text(
              '${product['category'] ?? 'Uncategorized'} by ${product['farmer_name'] ?? 'Unknown'}'  
            ),
            trailing: Text(
              '৳${product['price']}',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserList() {
    if (_users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _users.length > 5 ? 5 : _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isActive = user['status'] == AppConstants.userActive;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getRoleColor(user['role']),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          title: Text(user['name'] ?? 'Unknown'),
          subtitle: Text('${user['email']} (${user['role']})'),
          trailing: Switch(
            value: isActive,
            onChanged: (_) => _toggleUserStatus(user),
            activeColor: Colors.green,
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return Colors.red;
      case AppConstants.roleFarmer:
        return Colors.green;
      case AppConstants.roleBuyer:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
