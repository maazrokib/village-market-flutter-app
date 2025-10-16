import 'package:flutter/material.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:village_market/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  TabController? _tabController;

  // Stats
  int _totalUsers = 0;
  int _totalFarmers = 0;
  int _totalBuyers = 0;
  int _totalProducts = 0;
  int _totalOrders = 0;
  double _totalSales = 0.0;

  // Lists
  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _buyers = [];
  List<Map<String, dynamic>> _recentOrders = [];

  // Chart data
  Map<String, double> _productCategoriesCount = {};
  Map<String, double> _orderStatusCount = {};
  List<Map<String, dynamic>> _monthlySales = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final users = HiveService.getAllUsers();
      final products = HiveService.getAllProducts();
      final orders = HiveService.getAllOrdersEnriched();

      _totalUsers = users.length;
      _totalFarmers = users.where((u) => u['role'] == AppConstants.roleFarmer).length;
      _totalBuyers = users.where((u) => u['role'] == AppConstants.roleBuyer).length;
      _totalProducts = products.length;
      _totalOrders = orders.length;
      _totalSales = orders.fold<double>(0.0, (acc, o) => acc + ((o['total_price'] as num?)?.toDouble() ?? 0.0));

      _farmers = users.where((u) => u['role'] == AppConstants.roleFarmer).toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      _buyers = users.where((u) => u['role'] == AppConstants.roleBuyer).toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      _recentOrders = orders.take(10).toList();

      _productCategoriesCount = HiveService.getProductCategoriesCountGlobal();
      _orderStatusCount = HiveService.getOrderStatusCountGlobal();
      _monthlySales = HiveService.getMonthlySalesForYear(DateTime.now().year);
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

  void _toggleUserStatus(Map<String, dynamic> user) async {
    try {
      final newStatus =
          user['status'] == AppConstants.userActive
              ? AppConstants.userBanned
              : AppConstants.userActive;
      await HiveService.setUserStatus(user['id'] as int, newStatus);

      // Refresh data
      _loadDashboardData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user['name']} is now ${newStatus == AppConstants.userActive ? 'active' : 'banned'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to update user status: $e');
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to delete ${user['name']}\'s account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(user);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    try {
      final userId = user['id'] as int;
      await HiveService.deleteUserCascade(userId);

      // Refresh data
      _loadDashboardData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['name']}\'s account has been deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to delete user: $e');
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }

  String _getMonthName(int month) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return monthNames[month - 1];
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
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatCards(),
                      const SizedBox(height: 24),
                      _buildSalesChart(),
                      const SizedBox(height: 24),
                      _buildProductCategoriesChart(),
                      const SizedBox(height: 24),
                      _buildOrderStatusChart(),
                      const SizedBox(height: 24),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Farmers'),
                          Tab(text: 'Buyers'),
                          Tab(text: 'Recent Orders'),
                        ],
                        labelColor: Theme.of(context).primaryColor,
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFarmersList(),
                            _buildBuyersList(),
                            _buildRecentOrders(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatCards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Users',
          _totalUsers.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Total Products',
          _totalProducts.toString(),
          Icons.shopping_bag,
          Colors.orange,
        ),
        _buildStatCard(
          'Total Orders',
          _totalOrders.toString(),
          Icons.receipt_long,
          Colors.purple,
        ),
        _buildStatCard(
          'Total Sales',
          '৳${_totalSales.toStringAsFixed(2)}',
          Icons.monetization_on,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      _monthlySales
                          .map((m) => m['sales'] as double)
                          .fold(0.0, (a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueAccent,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '৳${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final int monthIndex = value.toInt();
                          if (monthIndex < 0 ||
                              monthIndex >= _monthlySales.length) {
                            return const Text('');
                          }
                          return Text(
                            _getMonthName(_monthlySales[monthIndex]['month']),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  barGroups: List.generate(
                    _monthlySales.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: _monthlySales[index]['sales'],
                          color: Theme.of(context).primaryColor,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCategoriesChart() {
    if (_productCategoriesCount.isEmpty) {
      return const Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No product categories data available')),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections:
                      _productCategoriesCount.entries.map((entry) {
                        final color = _getCategoryColor(entry.key);
                        return PieChartSectionData(
                          color: color,
                          value: entry.value,
                          title: '${entry.key}\n${entry.value.toInt()}',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    if (_orderStatusCount.isEmpty) {
      return const Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No order status data available')),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections:
                      _orderStatusCount.entries.map((entry) {
                        final color = _getStatusColor(entry.key);
                        return PieChartSectionData(
                          color: color,
                          value: entry.value,
                          title: '${entry.key}\n${entry.value.toInt()}',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmersList() {
    if (_farmers.isEmpty) {
      return const Center(child: Text('No farmers found'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _farmers.length,
      itemBuilder: (context, index) {
        final farmer = _farmers[index];
        final isActive = farmer['status'] == AppConstants.userActive;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(farmer['name'] ?? 'Unknown'),
            subtitle: Text(farmer['email'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  onChanged: (_) => _toggleUserStatus(farmer),
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(farmer);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Account'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuyersList() {
    if (_buyers.isEmpty) {
      return const Center(child: Text('No buyers found'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _buyers.length,
      itemBuilder: (context, index) {
        final buyer = _buyers[index];
        final isActive = buyer['status'] == AppConstants.userActive;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(buyer['name'] ?? 'Unknown'),
            subtitle: Text(buyer['email'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  onChanged: (_) => _toggleUserStatus(buyer),
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(buyer);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Account'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) {
      return const Center(child: Text('No recent orders'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _recentOrders.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final order = _recentOrders[index];
        return ListTile(
          title: Text(
            'Order #${order['id']} - ${order['product_name'] ?? 'Unknown'}',
          ),
          subtitle: Text(
            'By: ${order['buyer_name'] ?? 'Unknown'} - ${_formatDate(order['created_at'])}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '৳${(order['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
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
            ],
          ),
          onTap: () {
            // Show order details in a dialog
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('Order #${order['id']}'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderDetailRow(
                          'Product',
                          order['product_name'] ?? 'Unknown',
                        ),
                        _buildOrderDetailRow(
                          'Buyer',
                          order['buyer_name'] ?? 'Unknown',
                        ),
                        _buildOrderDetailRow(
                          'Quantity',
                          '${order['quantity'] ?? 0}',
                        ),
                        _buildOrderDetailRow(
                          'Price',
                          '৳${(order['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                        _buildOrderDetailRow(
                          'Status',
                          order['status'] ?? 'Unknown',
                        ),
                        _buildOrderDetailRow(
                          'Date',
                          _formatDate(order['created_at']),
                        ),
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
        );
      },
    );
  }

  Widget _buildOrderDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
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

  Color _getCategoryColor(String category) {
    final colors = {
      'Vegetables': Colors.green,
      'Fruits': Colors.orange,
      'Grains': Colors.amber,
      'Dairy': Colors.blue,
      'Meat': Colors.red,
      'Others': Colors.purple,
    };

    return colors[category] ?? Colors.grey;
  }
}
