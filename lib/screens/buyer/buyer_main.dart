import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:village_market/screens/auth/login_screen.dart';
import 'package:village_market/screens/buyer/buyer_home.dart';
import 'package:village_market/screens/buyer/buyer_profile.dart';
import 'package:village_market/screens/buyer/buyer_settings.dart';
import 'package:village_market/screens/buyer/buyer_cart.dart';
import 'package:village_market/screens/buyer/buyer_wishlist.dart';
import 'package:village_market/screens/buyer/buyer_contact.dart';
import 'package:village_market/screens/buyer/buyer_orders.dart';
import 'package:village_market/screens/buyer/buyer_farmers.dart';
import 'package:village_market/screens/notifications/notification_screen.dart';
import 'package:village_market/screens/covi/covi_screen.dart';
import 'package:village_market/screens/messages/universal_messages.dart';

class BuyerMain extends StatefulWidget {
  const BuyerMain({super.key});

  @override
  State<BuyerMain> createState() => _BuyerMainState();
}

class _BuyerMainState extends State<BuyerMain> {
  int _selectedIndex = 0;
  int _cartCount = 0;
  int _wishlistCount = 0;
  int _userId = 1;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      BuyerHome(onCartOrWishlistChanged: _loadCounts),
      const CoviScreen(),
      const BuyerProfile(),
      const BuyerSettings(),
    ];
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id') ?? 1;
      final db = await DatabaseHelper().database;

      final cart = await db.rawQuery(
        'SELECT COUNT(*) as c FROM cart WHERE buyer_id = ?',
        [_userId],
      );
      final wish = await db.rawQuery(
        'SELECT COUNT(*) as c FROM wishlist WHERE buyer_id = ?',
        [_userId],
      );

      final cartCount = (cart.first['c'] as int?) ?? 0;
      final wishlistCount = (wish.first['c'] as int?) ?? 0;
      
      print('Main screen counts - Cart: $cartCount, Wishlist: $wishlistCount for user $_userId');
      
      setState(() {
        _cartCount = cartCount;
        _wishlistCount = wishlistCount;
      });
    } catch (e) {
      print('Error loading counts in main screen: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Village Market'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
            tooltip: 'Notifications',
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BuyerWishlist()),
                  ).then((_) => _loadCounts());
                },
                tooltip: 'Wishlist',
              ),
              if (_wishlistCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _wishlistCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BuyerCart()),
                  ).then((_) => _loadCounts());
                },
                tooltip: 'Cart',
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _cartCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),

      // ✅ সুন্দর Drawer শুধু এখানে থাকবে
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              accountName: const Text("Welcome, Buyer"),
              accountEmail: const Text("village.market@example.com"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.green),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.agriculture),
              title: const Text('Farmers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuyerFarmers()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Messages'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UniversalMessages()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Cart'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuyerCart()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('My Orders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuyerOrders()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Wishlist'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuyerWishlist(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contact'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuyerContact()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),

      body: _pages[_selectedIndex],

      // ✅ BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'COVI'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
