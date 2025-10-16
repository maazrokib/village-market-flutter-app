import 'package:flutter/material.dart';
import 'package:village_market/services/hive_service.dart';
import 'package:village_market/screens/admin/admin_main.dart'; 
import 'package:village_market/screens/buyer/buyer_main.dart';
import 'package:village_market/screens/farmer/farmer_main.dart';
import 'package:village_market/utils/constants.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Use Hive database
      final email = _emailController.text.trim();
      final hashed = _hashPassword(_passwordController.text);

      Map<String, dynamic>? foundUser = HiveService.getUserByEmail(email);

      if (foundUser != null) {
        // Accept either plain or hashed (migrate to hashed)
        final pass = foundUser['password'] as String?;
        final ok = pass == _passwordController.text || pass == hashed;
        if (ok) {
          // migrate to hashed if needed
          if (pass == _passwordController.text) {
            foundUser = {...foundUser, 'password': hashed};
            await HiveService.upsertUser(foundUser);
          }
          _handleSuccessfulLogin(foundUser);
          return;
        }
      }

      _showError('Invalid email or password');
    } catch (e) {
      _showError('An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _handleSuccessfulLogin(Map<String, dynamic> user) {
    if (user['status'] == AppConstants.userBanned) {
      _showError('Your account has been banned');
      return;
    }

    // Save user ID to SharedPreferences
    _saveUserId(user['id']);

    // Navigate based on role
    switch (user['role']) {
      case AppConstants.roleAdmin:
        _navigateToHome(const AdminMain()); 
        break;
      case AppConstants.roleFarmer:
        _navigateToHome(const FarmerMain());
        break;
      case AppConstants.roleBuyer:
        _navigateToHome(const BuyerMain());
        break;
      default:
        _showError('Invalid user role');
    }
  }

  Future<void> _saveUserId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);
    } catch (e) {
      print('Error saving user ID: $e');
    }
  }

  void _navigateToHome(Widget home) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => home),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Village Market',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Login'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Create an Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
