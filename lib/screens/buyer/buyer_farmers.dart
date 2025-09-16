import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuyerFarmers extends StatefulWidget {
  const BuyerFarmers({super.key});

  @override
  State<BuyerFarmers> createState() => _BuyerFarmersState();
}

class _BuyerFarmersState extends State<BuyerFarmers> {
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final farmers = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['farmer'],
        orderBy: 'name ASC',
      );
      setState(() => _farmers = farmers);
    } catch (e) {
      _showError('Failed to load farmers');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> farmer) async {
    final _subjectController = TextEditingController();
    final _messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to ${farmer['name']}'),
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
                await _sendMessageToFarmer(
                  farmer['id'],
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

  Future<void> _sendMessageToFarmer(int farmerId, String subject, String message) async {
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final buyerId = prefs.getInt('user_id') ?? 1;
      
      await db.insert('messages', {
        'subject': subject,
        'message': message,
        'sender_id': buyerId,
        'receiver_id': farmerId,
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

  List<Map<String, dynamic>> _getFilteredFarmers() {
    if (_searchQuery.isEmpty) {
      return _farmers;
    }
    return _farmers.where((farmer) =>
        farmer['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        farmer['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFarmers = _getFilteredFarmers();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFarmers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search farmers',
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
                : filteredFarmers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.agriculture, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No farmers found' : 'No farmers match your search',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredFarmers.length,
                        itemBuilder: (context, index) {
                          final farmer = filteredFarmers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Text(
                                  farmer['name'].toString().substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                farmer['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(farmer['email'] ?? ''),
                                  if (farmer['phone'] != null)
                                    Text('Phone: ${farmer['phone']}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.message),
                                    onPressed: () => _sendMessage(farmer),
                                    tooltip: 'Send Message',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.info),
                                    onPressed: () => _showFarmerDetails(farmer),
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

  void _showFarmerDetails(Map<String, dynamic> farmer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${farmer['name']} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', farmer['name'] ?? 'Unknown'),
            _buildDetailRow('Email', farmer['email'] ?? 'Not provided'),
            _buildDetailRow('Phone', farmer['phone'] ?? 'Not provided'),
            _buildDetailRow('Address', farmer['address'] ?? 'Not provided'),
            _buildDetailRow('Status', farmer['status'] ?? 'Unknown'),
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
              _sendMessage(farmer);
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
