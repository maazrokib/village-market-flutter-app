import 'package:village_market/database/database_helper.dart';
import 'package:village_market/models/notification.dart';

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
      final db = await DatabaseHelper().database;
      await db.insert('notifications', {
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
      final db = await DatabaseHelper().database;
      final notifications = await db.query(
        'notifications',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return notifications.map((n) => NotificationModel.fromMap(n)).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadNotificationCount(int userId) async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0',
        [userId],
      );
      return result.first['count'] as int;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [notificationId],
      );
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(int userId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [notificationId],
      );
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
