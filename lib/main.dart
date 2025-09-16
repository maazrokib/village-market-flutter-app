import 'package:flutter/material.dart';
import 'package:village_market/theme/theme_controller.dart';
import 'package:village_market/screens/auth/login_screen.dart';
import 'package:village_market/screens/auth/register_screen.dart';
import 'package:village_market/screens/buyer/buyer_main.dart';
import 'package:village_market/screens/farmer/farmer_main.dart';
import 'package:village_market/screens/admin/admin_main.dart';
import 'package:village_market/database/sample_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Insert sample data
  await SampleData.insertSampleData();
  await ThemeController.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      useMaterial3: true,
      primaryColor: Colors.green,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.green,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.green),
          foregroundColor: Colors.green,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.green, foregroundColor: Colors.white),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Colors.green, foregroundColor: Colors.white),
    );

    final ThemeData darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      useMaterial3: true,
      primaryColor: Colors.green,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.green.shade300,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.green.shade400),
          foregroundColor: Colors.green.shade300,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Village Market',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: const LoginScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/farmer': (context) => const FarmerMain(),
            '/buyer': (context) => const BuyerMain(),
            '/admin': (context) => const AdminMain(),
          },
        );
      },
    );
  }
}
