import 'package:village_market/models/notification.dart';
import 'package:village_market/services/hive_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    required int userId,
  }) async {
    try {
      await HiveService.notificationsBox.add({
        'title': title,
        'message': message,
        'type': type,
        'user_id': userId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<List<NotificationModel>> getUserNotifications(int userId) async {
    try {
      final all = HiveService.notificationsBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((n) => n['user_id'] == userId)
          .toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return all.map((n) => NotificationModel.fromMap(n)).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadNotificationCount(int userId) async {
    try {
      return HiveService.notificationsBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((n) => n['user_id'] == userId && (n['is_read'] as int? ?? 0) == 0)
          .length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final n = HiveService.notificationsBox.get(notificationId);
      if (n != null) {
        await HiveService.notificationsBox.put(notificationId, {
          ...Map<String, dynamic>.from(n),
          'is_read': 1,
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(int userId) async {
    try {
      final keys = <dynamic>[];
      for (final k in HiveService.notificationsBox.keys) {
        final v = HiveService.notificationsBox.get(k);
        if (v == null) continue;
        final m = Map<String, dynamic>.from(v);
        if (m['user_id'] == userId) keys.add(k);
      }
      for (final k in keys) {
        final v = HiveService.notificationsBox.get(k);
        if (v == null) continue;
        await HiveService.notificationsBox.put(k, {
          ...Map<String, dynamic>.from(v),
          'is_read': 1,
        });
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await HiveService.notificationsBox.delete(notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Helper methods for creating specific types of notifications
  Future<void> createOrderNotification({
    required int userId,
    required String orderId,
    required String status,
  }) async {
    String title = 'Order Update';
    String message = 'Your order #$orderId has been $status';
    
    await createNotification(
      title: title,
      message: message,
      type: 'order',
      userId: userId,
    );
  }

  Future<void> createMessageNotification({
    required int userId,
    required String senderName,
    required String subject,
  }) async {
    String title = 'New Message';
    String message = 'You have a new message from $senderName: $subject';
    
    await createNotification(
      title: title,
      message: message,
      type: 'message',
      userId: userId,
    );
  }

  Future<void> createProductNotification({
    required int userId,
    required String productName,
    required String action,
  }) async {
    String title = 'Product $action';
    String message = 'Product "$productName" has been $action';
    
    await createNotification(
      title: title,
      message: message,
      type: 'product',
      userId: userId,
    );
  }

  Future<void> createGeneralNotification({
    required int userId,
    required String title,
    required String message,
  }) async {
    await createNotification(
      title: title,
      message: message,
      type: 'general',
      userId: userId,
    );
  }
}
