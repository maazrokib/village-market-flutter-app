import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmerContact extends StatefulWidget {
  const FarmerContact({super.key});

  @override
  State<FarmerContact> createState() => _FarmerContactState();
}

class _FarmerContactState extends State<FarmerContact> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  Map<String, dynamic>? _adminContact;
  bool _isLoading = false;
  List<Map<String, dynamic>> _previousMessages = [];

  @override
  void initState() {
    super.initState();
    _loadAdminContact();
    _loadPreviousMessages();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminContact() async {
    setState(() => _isLoading = true);
    try {
      final admins = HiveService.getUsersByRole('admin');

      if (admins.isNotEmpty) {
        setState(() => _adminContact = admins.first);
      }
    } catch (e) {
      _showError('Failed to load admin contact');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPreviousMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id') ?? 1;
      
      // Load both sent and received messages
      final sentMessages = HiveService.getMessagesForSender(farmerId);
      final receivedMessages = HiveService.getMessagesForReceiver(farmerId);
      
      final allMessages = [
        ...sentMessages.map((m) => {...m, 'message_type': 'sent'}),
        ...receivedMessages.map((m) => {...m, 'message_type': 'received'}),
      ];
      
      allMessages.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      
      setState(() => _previousMessages = allMessages.take(10).toList());
    } catch (e) {
      _showError('Failed to load previous messages');
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id') ?? 1;
      
      await HiveService.addMessage(
        subject: _subjectController.text,
        message: _messageController.text,
        senderId: farmerId,
        receiverId: _adminContact?['id'] ?? 1,
      );

      _subjectController.clear();
      _messageController.clear();
      _showSuccess('Message sent successfully');
      _loadPreviousMessages();
    } catch (e) {
      _showError('Failed to send message: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callAdmin() async {
    if (_adminContact == null || _adminContact!['phone'] == null) {
      _showError('Admin phone number not available');
      return;
    }

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: _adminContact!['phone'],
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showError('Could not launch phone call');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Admin'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Admin',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildAdminContactCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'Send Message',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMessageForm(),
                  const SizedBox(height: 24),
                  if (_previousMessages.isNotEmpty) ...[  
                    const Text(
                      'Previous Messages',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildPreviousMessages(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAdminContactCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 25,
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminContact?['name'] ?? 'Admin',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Village Market Administrator',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (_adminContact != null) ...[  
              if (_adminContact!['email'] != null)
                ListTile(
                  leading: Icon(Icons.email, color: Theme.of(context).primaryColor),
                  title: Text(_adminContact!['email']),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: _adminContact!['email'],
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    }
                  },
                ),
              if (_adminContact!['phone'] != null)
                ListTile(
                  leading: Icon(Icons.phone, color: Theme.of(context).primaryColor),
                  title: Text(_adminContact!['phone']),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    onPressed: _callAdmin,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
            ] else
              const Center(
                child: Text('Admin contact information not available'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.subject),
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
            decoration: InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.message),
            ),
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a message';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send Message'),
              onPressed: _isLoading ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousMessages() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _previousMessages.length,
      itemBuilder: (context, index) {
        final message = _previousMessages[index];
        final isSent = message['message_type'] == 'sent';
        final otherPartyName = message['other_party_name'] ?? 'Unknown';
        final otherPartyRole = message['other_party_role'] ?? 'Unknown';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              message['subject'] ?? 'No Subject',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(message['created_at'])),
                Text(
                  isSent ? 'To: $otherPartyName ($otherPartyRole)' : 'From: $otherPartyName ($otherPartyRole)',
                  style: TextStyle(
                    color: isSent ? Colors.blue : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSent ? Colors.blue : (message['is_read'] == 1 ? Colors.green : Colors.orange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSent ? 'Sent' : (message['is_read'] == 1 ? 'Read' : 'Unread'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                if (!isSent && message['is_read'] == 0)
                  const SizedBox(width: 8),
                if (!isSent && message['is_read'] == 0)
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
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(message['message'] ?? 'No message content'),
                    if (!isSent && message['is_read'] == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          onPressed: () => _markAsRead(message['id']),
                          icon: const Icon(Icons.mark_email_read),
                          label: const Text('Mark as Read'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
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

  Future<void> _markAsRead(int messageId) async {
    try {
      await HiveService.markMessageRead(messageId);
      _loadPreviousMessages();
      _showSuccess('Message marked as read');
    } catch (e) {
      _showError('Failed to mark message as read');
    }
  }
}
