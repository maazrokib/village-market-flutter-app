import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmerBuyers extends StatefulWidget {
  const FarmerBuyers({super.key});

  @override
  State<FarmerBuyers> createState() => _FarmerBuyersState();
}

class _FarmerBuyersState extends State<FarmerBuyers> {
  List<Map<String, dynamic>> _buyers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBuyers();
  }

  Future<void> _loadBuyers() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final buyers = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['buyer'],
        orderBy: 'name ASC',
      );
      setState(() => _buyers = buyers);
    } catch (e) {
      _showError('Failed to load buyers');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> buyer) async {
    final _subjectController = TextEditingController();
    final _messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to ${buyer['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                await _sendMessageToBuyer(
                  buyer['id'],
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
    );
  }

  Future<void> _sendMessageToBuyer(int buyerId, String subject, String message) async {
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('user_id') ?? 1;
      
      await db.insert('messages', {
        'subject': subject,
        'message': message,
        'sender_id': farmerId,
        'receiver_id': buyerId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': 0,
      });

      _showSuccess('Message sent successfully');
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

  List<Map<String, dynamic>> _getFilteredBuyers() {
    if (_searchQuery.isEmpty) {
      return _buyers;
    }
    return _buyers.where((buyer) =>
        buyer['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        buyer['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBuyers = _getFilteredBuyers();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBuyers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search buyers',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBuyers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No buyers found' : 'No buyers match your search',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredBuyers.length,
                        itemBuilder: (context, index) {
                          final buyer = filteredBuyers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  buyer['name'].toString().substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                buyer['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(buyer['email'] ?? ''),
                                  if (buyer['phone'] != null)
                                    Text('Phone: ${buyer['phone']}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.message),
                                    onPressed: () => _sendMessage(buyer),
                                    tooltip: 'Send Message',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.info),
                                    onPressed: () => _showBuyerDetails(buyer),
                                    tooltip: 'View Details',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showBuyerDetails(Map<String, dynamic> buyer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${buyer['name']} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', buyer['name'] ?? 'Unknown'),
            _buildDetailRow('Email', buyer['email'] ?? 'Not provided'),
            _buildDetailRow('Phone', buyer['phone'] ?? 'Not provided'),
            _buildDetailRow('Address', buyer['address'] ?? 'Not provided'),
            _buildDetailRow('Status', buyer['status'] ?? 'Unknown'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage(buyer);
            },
            child: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
