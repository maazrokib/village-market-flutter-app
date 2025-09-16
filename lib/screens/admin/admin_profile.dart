import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AdminProfile extends StatefulWidget {
  const AdminProfile({super.key});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  Map<String, dynamic>? _userData;
  bool _isEditing = false;
  bool _isLoading = true;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;
      
      final users = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (users.isNotEmpty) {
        setState(() {
          _userData = users.first;
          _nameController.text = _userData!['name'] ?? '';
          _phoneController.text = _userData!['phone'] ?? '';
          _addressController.text = _userData!['address'] ?? '';
          final avatarPath = _userData!['avatar'] as String?;
          if (avatarPath != null && avatarPath.isNotEmpty) {
            final file = File(avatarPath);
            if (file.existsSync()) {
              _profileImage = file;
            }
          }
        });
      }
    } catch (e) {
      _showError('Failed to load profile');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'users',
        {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          if (_profileImage != null) 'avatar': _profileImage!.path,
        },
        where: 'id = ?',
        whereArgs: [_userData!['id']],
      );

      setState(() => _isEditing = false);
      _loadUserData();
      _showSuccess('Profile updated successfully');
    } catch (e) {
      _showError('Failed to update profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _profileImage = file;
      });
      try {
        final db = await DatabaseHelper().database;
        await db.update(
          'users',
          { 'avatar': file.path },
          where: 'id = ?',
          whereArgs: [_userData!['id']],
        );
      } catch (_) {}
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

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = currentController.text.trim();
              final newPass = newController.text.trim();
              final confirm = confirmController.text.trim();
              if (newPass.isEmpty || confirm.isEmpty || current.isEmpty) {
                _showError('Please fill all fields');
                return;
              }
              if (newPass != confirm) {
                _showError('New passwords do not match');
                return;
              }
              try {
                final db = await DatabaseHelper().database;
                final userId = _userData!['id'] as int;
                final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
                if (rows.isEmpty || rows.first['password'] != current) {
                  _showError('Current password is incorrect');
                  return;
                }
                await db.update('users', { 'password': newPass }, where: 'id = ?', whereArgs: [userId]);
                // Update in-memory reference
                setState(() { _userData = { ...?_userData, 'password': newPass }; });
                if (context.mounted) Navigator.pop(context);
                _showSuccess('Password updated');
              } catch (e) {
                _showError('Failed to change password');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userData == null) {
      return const Center(child: Text('Failed to load profile data'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).primaryColor,
                      backgroundImage: _profileImage != null 
                          ? FileImage(_profileImage!) 
                          : null,
                      child: _profileImage == null
                          ? const Icon(
                              Icons.admin_panel_settings,
                              size: 60,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (!_isEditing)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => setState(() => _isEditing = true),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        enabled: _isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        enabled: _isEditing,
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _userData!['email'],
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _userData!['role'],
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                        ),
                        enabled: false,
                      ),
                      if (_isEditing) ...[  
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _nameController.text = _userData!['name'];
                                  _phoneController.text = _userData!['phone'] ?? '';
                                  _addressController.text = _userData!['address'] ?? '';
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _updateProfile,
                              child: const Text('Save Changes'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Security',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _changePassword,
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
