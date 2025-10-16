import 'package:flutter/material.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _userId = 1;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id') ?? 1;
      
      final notifications = HiveService.getNotificationsForUser(_userId);
      setState(() => _notifications = notifications);
    } catch (e) {
      _showError('Failed to load notifications');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final isRead = (notification['is_read'] as int? ?? 0) == 1;
    if (!isRead) {
      await HiveService.markNotificationRead(notification['id']);
      _loadNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    for (final notification in _notifications) {
      if ((notification['is_read'] as int? ?? 0) == 0) {
        await HiveService.markNotificationRead(notification['id']);
      }
    }
    _loadNotifications();
    _showSuccess('All notifications marked as read');
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    await HiveService.deleteNotification(notification['id']);
    _loadNotifications();
    _showSuccess('Notification deleted');
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'order':
        return Colors.blue;
      case 'message':
        return Colors.green;
      case 'product':
        return Colors.orange;
      case 'general':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_cart;
      case 'message':
        return Icons.message;
      case 'product':
        return Icons.shopping_bag;
      case 'general':
        return Icons.notifications;
      default:
        return Icons.notification_important;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => (n['is_read'] as int? ?? 0) == 0))
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You will see notifications here when you receive them',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getTypeColor(notification['type'] ?? 'general'),
                            child: Icon(
                              _getTypeIcon(notification['type'] ?? 'general'),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            notification['title'] ?? '',
                            style: TextStyle(
                              fontWeight: (notification['is_read'] as int? ?? 0) == 1 ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(notification['created_at'] ?? ''),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((notification['is_read'] as int? ?? 0) == 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'read' && (notification['is_read'] as int? ?? 0) == 0) {
                                    _markAsRead(notification);
                                  } else if (value == 'delete') {
                                    _deleteNotification(notification);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if ((notification['is_read'] as int? ?? 0) == 0)
                                    const PopupMenuItem(
                                      value: 'read',
                                      child: Text('Mark as Read'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            if ((notification['is_read'] as int? ?? 0) == 0) {
                              _markAsRead(notification);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
