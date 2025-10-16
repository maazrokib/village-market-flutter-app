import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/theme/theme_controller.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _emailAlerts = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _darkMode = prefs.getBool('admin_dark_mode') ?? false;
        _notifications = prefs.getBool('admin_notifications') ?? true;
        _emailAlerts = prefs.getBool('admin_email_alerts') ?? true;
      });
    } catch (e) {
      _showError('Failed to load settings');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_dark_mode', _darkMode);
      await prefs.setBool('admin_notifications', _notifications);
      await prefs.setBool('admin_email_alerts', _emailAlerts);
      _showSuccess('Settings saved successfully');
      await ThemeController.setDarkMode(_darkMode);
    } catch (e) {
      _showError('Failed to save settings');
    } finally {
      setState(() => _isLoading = false);
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

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _darkMode = false;
                _notifications = true;
                _emailAlerts = true;
              });
              await _saveSettings();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showResetDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text('This will clear all application data including users, products, orders, and messages. This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _showError('Data reset functionality not implemented yet. Please reinstall the app to reset data.');
            },
            child: const Text('Reset Data', style: TextStyle(color: Colors.red)),
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

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      'Appearance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Enable dark theme for the app'),
                      value: _darkMode,
                      onChanged: (value) {
                        setState(() => _darkMode = value);
                        _saveSettings();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Receive notifications for new orders and user registrations'),
                      value: _notifications,
                      onChanged: (value) {
                        setState(() => _notifications = value);
                        _saveSettings();
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Email Alerts'),
                      subtitle: const Text('Receive email alerts for important events'),
                      value: _emailAlerts,
                      onChanged: (value) {
                        setState(() => _emailAlerts = value);
                        _saveSettings();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.backup),
                      title: const Text('Backup Data'),
                      subtitle: const Text('Hive database is automatically backed up'),
                      onTap: () {
                        _showSuccess('Hive database is automatically backed up and doesn\'t require manual backup');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Reset Data'),
                      subtitle: const Text('Clear all application data (use with caution)'),
                      onTap: () {
                        _showResetDataDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('App Version'),
                      subtitle: const Text('1.0.0'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.policy),
                      title: const Text('Privacy Policy'),
                      onTap: () {
                        // TODO: Implement privacy policy
                        _showSuccess('Privacy policy not implemented yet');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Terms of Service'),
                      onTap: () {
                        // TODO: Implement terms of service
                        _showSuccess('Terms of service not implemented yet');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _resetSettings,
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
