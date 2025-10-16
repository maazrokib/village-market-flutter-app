class NotificationModel {
  final int? id;
  final String title;
  final String message;
  final String type; // 'order', 'message', 'product', 'general'
  final int userId;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'user_id': userId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      type: map['type'],
      userId: map['user_id'],
      isRead: map['is_read'] == 1,
      createdAt: map['created_at'],
    );
  }
}
