import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UniversalMessages extends StatefulWidget {
  const UniversalMessages({super.key});

  @override
  State<UniversalMessages> createState() => _UniversalMessagesState();
}

class _UniversalMessagesState extends State<UniversalMessages> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _receivedMessages = [];
  List<Map<String, dynamic>> _sentMessages = [];
  int _userId = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id') ?? 1;
      await _loadMessages();
    } catch (e) {
      _showError('Failed to load user data');
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      
      // Load received messages
      final receivedResult = await db.rawQuery('''
        SELECT m.*, u.name as sender_name, u.role as sender_role
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.receiver_id = ?
        ORDER BY m.created_at DESC
      ''', [_userId]);
      
      // Load sent messages
      final sentResult = await db.rawQuery('''
        SELECT m.*, u.name as receiver_name, u.role as receiver_role
        FROM messages m
        JOIN users u ON m.receiver_id = u.id
        WHERE m.sender_id = ?
        ORDER BY m.created_at DESC
      ''', [_userId]);
      
      setState(() {
        _receivedMessages = receivedResult;
        _sentMessages = sentResult;
      });
    } catch (e) {
      _showError('Failed to load messages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int messageId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'messages',
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [messageId],
      );
      _loadMessages();
    } catch (e) {
      print('Failed to mark message as read: $e');
    }
  }

  Future<void> _sendReply(Map<String, dynamic> originalMessage) async {
    final _subjectController = TextEditingController(text: 'Re: ${originalMessage['subject']}');
    final _messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${originalMessage['sender_name'] ?? originalMessage['receiver_name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_subjectController.text.isNotEmpty && _messageController.text.isNotEmpty) {
                await _sendMessage(
                  originalMessage['sender_id'] ?? originalMessage['receiver_id'],
                  _subjectController.text,
                  _messageController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(int receiverId, String subject, String message) async {
    try {
      final db = await DatabaseHelper().database;
      
      await db.insert('messages', {
        'subject': subject,
        'message': message,
        'sender_id': _userId,
        'receiver_id': receiverId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': 0,
      });

      _showSuccess('Message sent successfully');
      _loadMessages();
    } catch (e) {
      _showError('Failed to send message: $e');
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

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'farmer':
        return Colors.green;
      case 'buyer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMessagesList(_receivedMessages, true),
                _buildMessagesList(_sentMessages, false),
              ],
            ),
    );
  }

  Widget _buildMessagesList(List<Map<String, dynamic>> messages, bool isReceived) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isRead = message['is_read'] == 1;
        final senderName = isReceived ? message['sender_name'] : message['receiver_name'];
        final senderRole = isReceived ? message['sender_role'] : message['receiver_role'];

        return Card(
          elevation: isRead ? 1 : 3,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(senderRole),
              child: Text(
                senderName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    message['subject'] ?? 'No Subject',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From: $senderName (${senderRole?.toUpperCase() ?? 'UNKNOWN'})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message['message'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(message['created_at']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            onTap: () {
              if (isReceived && !isRead) {
                _markAsRead(message['id']);
              }
              _showMessageDetail(message, isReceived);
            },
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'reply') {
                  _sendReply(message);
                } else if (value == 'delete') {
                  _deleteMessage(message['id']);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reply',
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16),
                      SizedBox(width: 8),
                      Text('Reply'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageDetail(Map<String, dynamic> message, bool isReceived) {
    final senderName = isReceived ? message['sender_name'] : message['receiver_name'];
    final senderRole = isReceived ? message['sender_role'] : message['receiver_role'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message['subject'] ?? 'No Subject'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(senderRole),
                    radius: 20,
                    child: Text(
                      senderName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${senderRole?.toUpperCase() ?? 'UNKNOWN'} • ${_formatDate(message['created_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message['message'] ?? '',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sendReply(message);
            },
            icon: const Icon(Icons.reply),
            label: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
      _showSuccess('Message deleted successfully');
      _loadMessages();
    } catch (e) {
      _showError('Failed to delete message: $e');
    }
  }
}
