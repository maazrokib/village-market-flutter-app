import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminMessages extends StatefulWidget {
  const AdminMessages({super.key});

  @override
  State<AdminMessages> createState() => _AdminMessagesState();
}

class _AdminMessagesState extends State<AdminMessages> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'unread', 'read'

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getInt('user_id') ?? 1;
      
      String whereClause = 'receiver_id = ?';
      List<dynamic> whereArgs = [adminId];
      
      if (_selectedFilter == 'unread') {
        whereClause += ' AND is_read = 0';
      } else if (_selectedFilter == 'read') {
        whereClause += ' AND is_read = 1';
      }
      
      final messages = await db.rawQuery('''
        SELECT m.*, u.name as sender_name, u.email as sender_email, u.role as sender_role
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        WHERE $whereClause
        ORDER BY m.created_at DESC
      ''', whereArgs);
      
      setState(() => _messages = messages);
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
      _showError('Failed to mark message as read');
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );
      _loadMessages();
      _showSuccess('Message deleted');
    } catch (e) {
      _showError('Failed to delete message');
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
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
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
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedFilter = value);
              _loadMessages();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Messages')),
              const PopupMenuItem(value: 'unread', child: Text('Unread Only')),
              const PopupMenuItem(value: 'read', child: Text('Read Only')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSendMessageDialog,
        child: const Icon(Icons.send),
        tooltip: 'Send Message',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.message_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No messages found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFilter == 'all'
                            ? 'You have no messages yet'
                            : 'No ${_selectedFilter} messages',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isRead = message['is_read'] == 1;
                    
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(message['sender_role']),
                          child: Text(
                            message['sender_name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          message['subject'] ?? 'No Subject',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From: ${message['sender_name']} (${message['sender_role']})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDate(message['created_at']),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isRead)
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
                                if (value == 'read' && !isRead) {
                                  _markAsRead(message['id']);
                                } else if (value == 'delete') {
                                  _deleteMessage(message['id']);
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isRead)
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
                          if (!isRead) {
                            _markAsRead(message['id']);
                          }
                          _showMessageDialog(message);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showMessageDialog(Map<String, dynamic> message) {
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
                  const Text('From: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${message['sender_name']} (${message['sender_role']})'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_formatDate(message['created_at'])),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message['message'] ?? 'No message content'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showReplyDialog(message);
            },
            child: const Text('Reply'),
          ),
          if (message['is_read'] == 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsRead(message['id']);
              },
              child: const Text('Mark as Read'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(message['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(Map<String, dynamic> originalMessage) {
    final _replySubjectController = TextEditingController();
    final _replyMessageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${originalMessage['sender_name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _replySubjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Re: ${originalMessage['subject']}',
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
                controller: _replyMessageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
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
              if (_replySubjectController.text.isNotEmpty && _replyMessageController.text.isNotEmpty) {
                await _sendReply(
                  originalMessage['sender_id'],
                  _replySubjectController.text,
                  _replyMessageController.text,
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

  Future<void> _sendReply(int receiverId, String subject, String message) async {
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getInt('user_id') ?? 1;
      
      await db.insert('messages', {
        'subject': subject,
        'message': message,
        'sender_id': adminId,
        'receiver_id': receiverId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': 0,
      });

      _showSuccess('Reply sent successfully');
      _loadMessages();
    } catch (e) {
      _showError('Failed to send reply: $e');
    }
  }

  void _showSendMessageDialog() {
    final _subjectController = TextEditingController();
    final _messageController = TextEditingController();
    String _selectedRole = 'all';
    int? _selectedUserId;
    List<Map<String, dynamic>> _users = [];
    bool _isLoadingUsers = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Send to'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'farmer', child: Text('All Farmers')),
                    DropdownMenuItem(value: 'buyer', child: Text('All Buyers')),
                    DropdownMenuItem(value: 'specific', child: Text('Specific User')),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _selectedRole = value!;
                      _selectedUserId = null;
                    });
                    
                    if (value == 'specific') {
                      setState(() => _isLoadingUsers = true);
                      try {
                        final db = await DatabaseHelper().database;
                        _users = await db.query('users', where: 'role != ?', whereArgs: ['admin']);
                        setState(() => _isLoadingUsers = false);
                      } catch (e) {
                        setState(() => _isLoadingUsers = false);
                        _showError('Failed to load users');
                      }
                    }
                  },
                ),
                if (_selectedRole == 'specific') ...[
                  const SizedBox(height: 16),
                  if (_isLoadingUsers)
                    const CircularProgressIndicator()
                  else
                    DropdownButtonFormField<int>(
                      value: _selectedUserId,
                      decoration: const InputDecoration(labelText: 'Select User'),
                      items: _users.map((user) => DropdownMenuItem<int>(
                        value: user['id'] as int,
                        child: Text('${user['name']} (${user['role']})'),
                      )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedUserId = value);
                      },
                    ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
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
                  if (_selectedRole == 'specific' && _selectedUserId == null) {
                    _showError('Please select a user');
                    return;
                  }
                  
                  await _sendMessageToUsers(
                    _selectedRole,
                    _selectedUserId,
                    _subjectController.text,
                    _messageController.text,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessageToUsers(String role, int? userId, String subject, String message) async {
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getInt('user_id') ?? 1;
      
      List<Map<String, dynamic>> targetUsers = [];
      
      if (role == 'specific' && userId != null) {
        targetUsers = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      } else if (role == 'all') {
        targetUsers = await db.query('users', where: 'role != ?', whereArgs: ['admin']);
      } else if (role == 'farmer') {
        targetUsers = await db.query('users', where: 'role = ?', whereArgs: ['farmer']);
      } else if (role == 'buyer') {
        targetUsers = await db.query('users', where: 'role = ?', whereArgs: ['buyer']);
      }

      for (var user in targetUsers) {
        await db.insert('messages', {
          'subject': subject,
          'message': message,
          'sender_id': adminId,
          'receiver_id': user['id'],
          'created_at': DateTime.now().toIso8601String(),
          'is_read': 0,
        });
      }

      _showSuccess('Message sent to ${targetUsers.length} user(s)');
      _loadMessages();
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }
}

