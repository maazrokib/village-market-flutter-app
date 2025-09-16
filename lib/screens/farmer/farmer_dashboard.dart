import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  bool _isLoading = true;
  int _totalProducts = 0;
  int _weeklyProductsAdded = 0;
  int _totalOrders = 0;
  int _weeklyOrdersReceived = 0;
  double _totalSales = 0.0;
  double _weeklySales = 0.0;
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id') ?? 1;
      
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoStr = weekAgo.toIso8601String();

      // Get total products
      final productsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE farmer_id = ?',
        [farmerId],
      );
      _totalProducts = Sqflite.firstIntValue(productsResult) ?? 0;

      // Get weekly products added
      final weeklyProductsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE farmer_id = ? AND created_at >= ?',
        [farmerId, weekAgoStr],
      );
      _weeklyProductsAdded = Sqflite.firstIntValue(weeklyProductsResult) ?? 0;

      // Get total orders
      final ordersResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM orders o 
        JOIN products p ON o.product_id = p.id 
        WHERE p.farmer_id = ?
      ''',
        [farmerId],
      );
      _totalOrders = Sqflite.firstIntValue(ordersResult) ?? 0;

      // Get weekly orders received
      final weeklyOrdersResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM orders o 
        JOIN products p ON o.product_id = p.id 
        WHERE p.farmer_id = ? AND o.created_at >= ?
      ''',
        [farmerId, weekAgoStr],
      );
      _weeklyOrdersReceived = Sqflite.firstIntValue(weeklyOrdersResult) ?? 0;

      // Get total sales
      final salesResult = await db.rawQuery(
        '''
        SELECT SUM(o.total_price) as total 
        FROM orders o 
        JOIN products p ON o.product_id = p.id 
        WHERE p.farmer_id = ?
      ''',
        [farmerId],
      );
      _totalSales =
          salesResult.first['total'] != null
              ? (salesResult.first['total'] as num).toDouble()
              : 0.0;

      // Get weekly sales
      final weeklySalesResult = await db.rawQuery(
        '''
        SELECT SUM(o.total_price) as total 
        FROM orders o 
        JOIN products p ON o.product_id = p.id 
        WHERE p.farmer_id = ? AND o.created_at >= ?
      ''',
        [farmerId, weekAgoStr],
      );
      _weeklySales =
          weeklySalesResult.first['total'] != null
              ? (weeklySalesResult.first['total'] as num).toDouble()
              : 0.0;

      // Get recent orders
      _recentOrders = await db.rawQuery(
        '''
        SELECT o.id, o.quantity, o.total_price, o.status, o.created_at, p.name as product_name, p.category
        FROM orders o 
        JOIN products p ON o.product_id = p.id 
        WHERE p.farmer_id = ? 
        ORDER BY o.created_at DESC LIMIT 5
      ''',
        [farmerId],
      );
    } catch (e) {
      _showError('Failed to load dashboard data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildWeeklySummary(),
                      const SizedBox(height: 24),
                      _buildStatCards(),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildRecentOrders(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWeeklySummary() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Products Added',
                  _weeklyProductsAdded.toString(),
                  Icons.add_box,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Orders Received',
                  _weeklyOrdersReceived.toString(),
                  Icons.shopping_cart,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'Sales',
                  '\u09f3${_weeklySales.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Products',
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.inventory_2, color: Colors.blue[400], size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _totalProducts.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Orders',
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.shopping_bag, color: Colors.orange[400], size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _totalOrders.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Sales',
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.monetization_on, color: Colors.green[400], size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\u09f3${_totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No recent orders')),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentOrders.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final order = _recentOrders[index];
          return ListTile(
            title: Text(
              order['product_name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: ${order['category']}'),
                Text('Date: ${_formatDate(order['created_at'])}'),
              ],
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '\u09f3${order['total_price'].toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order['status'],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
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
}
