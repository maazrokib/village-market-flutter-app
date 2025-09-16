import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:village_market/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmerOrders extends StatefulWidget {
  const FarmerOrders({super.key});

  @override
  State<FarmerOrders> createState() => _FarmerOrdersState();
}

class _FarmerOrdersState extends State<FarmerOrders> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'all';
            break;
          case 1:
            _selectedFilter = AppConstants.orderPending;
            break;
          case 2:
            _selectedFilter = AppConstants.orderConfirmed;
            break;
          case 3:
            _selectedFilter = AppConstants.orderDelivered;
            break;
        }
      });
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id');
      
      if (farmerId == null) {
        throw Exception('Farmer ID not found. Please log in again.');
      }
      
      String whereClause = '';
      List<dynamic> whereArgs = [farmerId]; // Use actual farmer ID from SharedPreferences
      
      if (_selectedFilter != 'all') {
        whereClause = ' AND o.status = ?';
        whereArgs.add(_selectedFilter);
      }
      
      final orders = await db.rawQuery('''
        SELECT o.*, p.name as product_name, p.image, p.category, u.name as buyer_name, u.phone as buyer_phone, o.shipping_address as buyer_address
        FROM orders o
        JOIN products p ON o.product_id = p.id
        JOIN users u ON o.buyer_id = u.id
        WHERE p.farmer_id = ?$whereClause
        ORDER BY o.created_at DESC
      ''', whereArgs);

      print('Loaded ${orders.length} orders for farmer ID: $farmerId');
      
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load orders: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'orders',
        {'status': status},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      _loadOrders();
      _showSuccess('Order status updated');
    } catch (e) {
      _showError('Failed to update order status');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.orderPending:
        return Colors.orange;
      case AppConstants.orderConfirmed:
        return Colors.blue;
      case AppConstants.orderDelivered:
        return Colors.green;
      case AppConstants.orderCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Pending'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Delivered'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'all'
                                  ? 'No orders found'
                                  : 'No ${_selectedFilter.toLowerCase()} orders',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: ExpansionTile(
                                title: Text(
                                  'Order #${order['id']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Product: ${order['product_name']}'),
                                    Text('Date: ${_formatDate(order['created_at'])}'),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    order['status'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        Row(
                                          children: [
                                            const Icon(Icons.person, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text('Buyer: ${order['buyer_name']}'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone, color: Colors.green),
                                            const SizedBox(width: 8),
                                            Text('Phone: ${order['buyer_phone']}'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.shopping_cart, color: Colors.orange),
                                            const SizedBox(width: 8),
                                            Text('Quantity: ${order['quantity']}'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.attach_money, color: Colors.green),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Total: \u09f3${order['total_price'].toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        if (order['status'] == AppConstants.orderPending)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton(
                                                onPressed: () => _updateOrderStatus(
                                                  order['id'],
                                                  AppConstants.orderCancelled,
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: const Text('Cancel Order'),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => _updateOrderStatus(
                                                  order['id'],
                                                  AppConstants.orderConfirmed,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Confirm Order'),
                                              ),
                                            ],
                                          ),
                                        if (order['status'] == AppConstants.orderConfirmed)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton(
                                                onPressed: () => _updateOrderStatus(
                                                  order['id'],
                                                  AppConstants.orderDelivered,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Mark as Delivered'),
                                              ),
                                            ],
                                          ),
                                      ],
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
