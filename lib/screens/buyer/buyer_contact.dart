import 'package:flutter/material.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuyerContact extends StatefulWidget {
  const BuyerContact({super.key});

  @override
  State<BuyerContact> createState() => _BuyerContactState();
}

class _BuyerContactState extends State<BuyerContact> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _contactMethod = 'message'; // 'message' or 'phone'
  List<Map<String, dynamic>> _previousMessages = [];

  @override
  void initState() {
    super.initState();
    _loadPreviousMessages();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final buyerId = prefs.getInt('user_id') ?? 1;
      
      // Load both sent and received messages
      final sentMessages = HiveService.getMessagesForSender(buyerId);
      final receivedMessages = HiveService.getMessagesForReceiver(buyerId);
      
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

  Future<void> _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get admin user ID
      final adminUsers = HiveService.getUsersByRole('admin');
      
      if (adminUsers.isEmpty) {
        _showError('No admin found to contact');
        return;
      }
      
      final adminId = adminUsers.first['id'];
      
      // Get buyer ID
      final prefs = await SharedPreferences.getInstance();
      final buyerId = prefs.getInt('user_id') ?? 1;
      
      // Insert message
      await HiveService.addMessage(
        subject: _subjectController.text,
        message: _contactMethod == 'message' 
            ? _messageController.text 
            : 'Please contact me at: ${_phoneController.text}',
        senderId: buyerId,
        receiverId: adminId,
      );
      
      _showSuccess('Your message has been sent');
      _clearForm();
      _loadPreviousMessages();
    } catch (e) {
      _showError('Failed to send message: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _subjectController.clear();
    _messageController.clear();
    _phoneController.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact Admin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please fill out the form below to contact our admin team. We will get back to you as soon as possible.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'How would you like us to contact you?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Message'),
                      value: 'message',
                      groupValue: _contactMethod,
                      onChanged: (value) {
                        setState(() => _contactMethod = value!);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Phone'),
                      value: 'phone',
                      groupValue: _contactMethod,
                      onChanged: (value) {
                        setState(() => _contactMethod = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_contactMethod == 'message')
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your message';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitContactForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit'),
                ),
              ),
              const SizedBox(height: 24),
              if (_previousMessages.isNotEmpty) ...[
                const Text(
                  'Previous Messages',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildPreviousMessages(),
                const SizedBox(height: 24),
              ],
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.email, color: Colors.green),
                          SizedBox(width: 8),
                          Text('admin@villagemarket.com'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.green),
                          SizedBox(width: 8),
                          Text('+880 1234 567890'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Village Market, Dhaka, Bangladesh'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
