import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String usersBoxName = 'users_box';
  static const String productsBoxName = 'products_box';
  static const String cartBoxName = 'cart_box';
  static const String wishlistBoxName = 'wishlist_box';
  static const String ordersBoxName = 'orders_box';
  static const String coviImagesBoxName = 'covi_images_box';
  static const String coviLikesBoxName = 'covi_likes_box';
  static const String notificationsBoxName = 'notifications_box';
  static const String messagesBoxName = 'messages_box';
  static const String metaBoxName = 'meta_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(usersBoxName),
      Hive.openBox<Map>(productsBoxName),
      Hive.openBox(metaBoxName),
      Hive.openBox<Map>(cartBoxName),
      Hive.openBox<Map>(wishlistBoxName),
      Hive.openBox<Map>(ordersBoxName),
      Hive.openBox<Map>(coviImagesBoxName),
      Hive.openBox<Map>(coviLikesBoxName),
      Hive.openBox<Map>(notificationsBoxName),
      Hive.openBox<Map>(messagesBoxName),
    ]);
  }

  static Box<Map> get usersBox => Hive.box<Map>(usersBoxName);
  static Box<Map> get productsBox => Hive.box<Map>(productsBoxName);
  static Box get metaBox => Hive.box(metaBoxName);
  static Box<Map> get cartBox => Hive.box<Map>(cartBoxName);
  static Box<Map> get wishlistBox => Hive.box<Map>(wishlistBoxName);
  static Box<Map> get ordersBox => Hive.box<Map>(ordersBoxName);
  static Box<Map> get coviImagesBox => Hive.box<Map>(coviImagesBoxName);
  static Box<Map> get coviLikesBox => Hive.box<Map>(coviLikesBoxName);
  static Box<Map> get notificationsBox => Hive.box<Map>(notificationsBoxName);
  static Box<Map> get messagesBox => Hive.box<Map>(messagesBoxName);

  static int _maxNumericKey(Iterable<dynamic> keys) {
    int maxKey = 0;
    for (final k in keys) {
      if (k is int && k > maxKey) maxKey = k;
      if (k is String) {
        final parsed = int.tryParse(k);
        if (parsed != null && parsed > maxKey) maxKey = parsed;
      }
    }
    return maxKey;
  }

  static Future<int> nextUserId() async {
    final existingMax = _maxNumericKey(usersBox.keys);
    final stored = metaBox.get('last_user_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_user_id', next);
    return next;
  }

  static Future<int> nextProductId() async {
    final existingMax = _maxNumericKey(productsBox.keys);
    final stored = metaBox.get('last_product_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_product_id', next);
    return next;
  }

  static Future<int> nextCartId() async {
    final existingMax = _maxNumericKey(cartBox.keys);
    final stored = metaBox.get('last_cart_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_cart_id', next);
    return next;
  }

  static Future<int> nextWishlistId() async {
    final existingMax = _maxNumericKey(wishlistBox.keys);
    final stored = metaBox.get('last_wishlist_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_wishlist_id', next);
    return next;
  }

  static Future<int> nextOrderId() async {
    final existingMax = _maxNumericKey(ordersBox.keys);
    final stored = metaBox.get('last_order_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_order_id', next);
    return next;
  }

  static Future<int> nextMessageId() async {
    final existingMax = _maxNumericKey(messagesBox.keys);
    final stored = metaBox.get('last_message_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_message_id', next);
    return next;
  }

  static Future<int> nextCoviId() async {
    final existingMax = _maxNumericKey(coviImagesBox.keys);
    final stored = metaBox.get('last_covi_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_covi_id', next);
    return next;
  }

  static Future<int> nextCoviLikeId() async {
    final existingMax = _maxNumericKey(coviLikesBox.keys);
    final stored = metaBox.get('last_covi_like_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_covi_like_id', next);
    return next;
  }

  static Future<int> nextNotificationId() async {
    final existingMax = _maxNumericKey(notificationsBox.keys);
    final stored = metaBox.get('last_notification_id') as int?;
    final next = [existingMax, stored ?? 0].reduce((a, b) => a > b ? a : b) + 1;
    await metaBox.put('last_notification_id', next);
    return next;
  }

  static Map<String, dynamic>? getUserByEmail(String email) {
    for (final key in usersBox.keys) {
      final data = usersBox.get(key);
      if (data == null) continue;
      final map = Map<String, dynamic>.from(data);
      if ((map['email'] as String?) == email) return map;
    }
    return null;
  }

  static Map<String, dynamic>? getUserById(int id) {
    final data = usersBox.get(id) ?? usersBox.get(id.toString());
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  static Future<void> upsertUser(Map<String, dynamic> user) async {
    final key = user['id'] ?? await nextUserId();
    final normalized = {...user, 'id': key};
    await usersBox.put(key, normalized);
  }

  static Future<void> seedDefaultsIfEmpty() async {
    if (usersBox.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    final adminId = await nextUserId();
    await usersBox.put(adminId, {
      'id': adminId,
      'name': 'Admin User',
      'email': 'admin@villagemarket.com',
      'password': 'admin123',
      'phone': '+8801234567890',
      'address': 'Dhaka, Bangladesh',
      'role': 'admin',
      'status': 'active',
      'avatar': null,
      'created_at': now,
    });
    final farmerId = await nextUserId();
    await usersBox.put(farmerId, {
      'id': farmerId,
      'name': 'Farmer John',
      'email': 'farmer@example.com',
      'password': 'farmer123',
      'phone': '+8801234567891',
      'address': 'Village Road, Dhaka',
      'role': 'farmer',
      'status': 'active',
      'avatar': null,
      'created_at': now,
    });
    final buyerId = await nextUserId();
    await usersBox.put(buyerId, {
      'id': buyerId,
      'name': 'Buyer Smith',
      'email': 'buyer@example.com',
      'password': 'buyer123',
      'phone': '+8801234567892',
      'address': 'City Center, Dhaka',
      'role': 'buyer',
      'status': 'active',
      'avatar': null,
      'created_at': now,
    });

    // Add sample notifications
    await addNotification(
      title: 'Welcome to Village Market!',
      message: 'Thank you for joining our community. Start exploring products and connecting with farmers.',
      type: 'general',
      userId: adminId,
    );
    await addNotification(
      title: 'Welcome to Village Market!',
      message: 'Thank you for joining our community. Start exploring products and connecting with farmers.',
      type: 'general',
      userId: farmerId,
    );
    await addNotification(
      title: 'Welcome to Village Market!',
      message: 'Thank you for joining our community. Start exploring products and connecting with farmers.',
      type: 'general',
      userId: buyerId,
    );
  }

  // Products
  static Future<void> upsertProduct(Map<String, dynamic> product) async {
    final key = product['id'] ?? await nextProductId();
    final normalized = {...product, 'id': key};
    await productsBox.put(key, normalized);
  }

  static List<Map<String, dynamic>> getAllProducts() {
    return productsBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> getAllUsers() {
    return usersBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> getProductsByFarmer(int farmerId) {
    return getAllProducts().where((p) => p['farmer_id'] == farmerId).toList();
  }

  static Future<void> deleteProduct(int id) async {
    await productsBox.delete(id);
  }

  // Wishlist
  static List<Map<String, dynamic>> getWishlist(int buyerId) {
    return wishlistBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((w) => w['buyer_id'] == buyerId)
        .toList();
  }

  static Future<void> toggleWishlist({required int buyerId, required int productId}) async {
    MapEntry<dynamic, Map>? existing;
    for (final k in wishlistBox.keys) {
      final v = wishlistBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['buyer_id'] == buyerId && m['product_id'] == productId) {
        existing = MapEntry(k, m);
        break;
      }
    }
    if (existing != null) {
      await wishlistBox.delete(existing.key);
    } else {
      final id = await nextWishlistId();
      await wishlistBox.put(id, {'id': id, 'buyer_id': buyerId, 'product_id': productId});
    }
  }

  static Future<void> removeFromWishlist(int id) async {
    await wishlistBox.delete(id);
  }

  // Cart
  static List<Map<String, dynamic>> getCart(int buyerId) {
    return cartBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['buyer_id'] == buyerId)
        .toList();
  }

  static Future<void> addToCart({required int buyerId, required int productId, int quantity = 1}) async {
    MapEntry<dynamic, Map>? existing;
    for (final k in cartBox.keys) {
      final v = cartBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['buyer_id'] == buyerId && m['product_id'] == productId) {
        existing = MapEntry(k, m);
        break;
      }
    }
    if (existing == null) {
      final id = await nextCartId();
      await cartBox.put(id, {'id': id, 'buyer_id': buyerId, 'product_id': productId, 'quantity': quantity});
    } else {
      final m = existing.value;
      final newQty = (m['quantity'] as int? ?? 0) + quantity;
      await cartBox.put(existing.key, {...m, 'quantity': newQty});
    }
  }

  static Future<void> updateCartQuantity(int cartId, int quantity) async {
    final m = cartBox.get(cartId);
    if (m == null) return;
    if (quantity < 1) {
      await cartBox.delete(cartId);
    } else {
      await cartBox.put(cartId, {...Map<String, dynamic>.from(m), 'quantity': quantity});
    }
  }

  static Future<void> removeCartItem(int cartId) async {
    await cartBox.delete(cartId);
  }

  static Future<void> clearCartByBuyer(int buyerId) async {
    final toDelete = <dynamic>[];
    for (final k in cartBox.keys) {
      final v = cartBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['buyer_id'] == buyerId) toDelete.add(k);
    }
    await cartBox.deleteAll(toDelete);
  }

  // Orders
  static Future<void> addOrder(Map<String, dynamic> order) async {
    final id = await nextOrderId();
    await ordersBox.put(id, {...order, 'id': id});
  }

  // COVI
  static Future<void> addCoviImage({
    required String imagePath,
    String? caption,
    String? story,
    required int uploaderId,
    required String uploaderRole,
  }) async {
    final id = await nextCoviId();
    await coviImagesBox.put(id, {
      'id': id,
      'image_path': imagePath,
      'caption': caption,
      'story': story,
      'uploader_id': uploaderId,
      'uploader_role': uploaderRole,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> getCoviImagesEnriched({int? viewerUserId}) {
    final images = coviImagesBox.values.map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    final users = { for (final u in usersBox.values) (u as Map)['id']: u };
    return images.map((img) {
      final likes = coviLikesBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((l) => l['covi_id'] == img['id'])
          .toList();
      final liked = viewerUserId == null ? false : likes.any((l) => l['user_id'] == viewerUserId);
      final uploader = users[img['uploader_id']];
      return {
        ...img,
        'likes': likes.length,
        'liked': liked,
        'uploader_name': uploader != null ? (uploader as Map)['name'] : 'User',
      };
    }).toList();
  }

  static Future<void> toggleCoviLike({required int coviId, required int userId}) async {
    MapEntry<dynamic, Map>? existing;
    for (final k in coviLikesBox.keys) {
      final v = coviLikesBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['covi_id'] == coviId && m['user_id'] == userId) {
        existing = MapEntry(k, m);
        break;
      }
    }
    if (existing != null) {
      await coviLikesBox.delete(existing.key);
    } else {
      final id = await nextCoviLikeId();
      await coviLikesBox.put(id, {'id': id, 'covi_id': coviId, 'user_id': userId, 'created_at': DateTime.now().toIso8601String()});
    }
  }

  static Future<void> deleteCoviImage(int coviId) async {
    await coviImagesBox.delete(coviId);
    // cascade delete likes
    final toDelete = <dynamic>[];
    for (final k in coviLikesBox.keys) {
      final v = coviLikesBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['covi_id'] == coviId) toDelete.add(k);
    }
    await coviLikesBox.deleteAll(toDelete);
  }

  static List<Map<String, dynamic>> getOrdersByBuyer(int buyerId) {
    return ordersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((o) => o['buyer_id'] == buyerId)
        .toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  }

  static List<Map<String, dynamic>> getOrdersByFarmer(int farmerId, {String filter = 'all'}) {
    final productsById = { for (final p in getAllProducts()) p['id']: p };
    final all = ordersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((o) {
          final p = productsById[o['product_id']];
          return p != null && p['farmer_id'] == farmerId;
        })
        .toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    final filtered = filter == 'all' ? all : all.where((o) => o['status'] == filter).toList();
    return filtered.map((o) {
      final p = productsById[o['product_id']];
      return {
        ...o,
        'product_name': p?['name'],
        'image': p?['image'],
        'category': p?['category'],
      };
    }).toList();
  }

  static Future<void> updateOrderStatus(int orderId, String status) async {
    final m = ordersBox.get(orderId);
    if (m == null) return;
    await ordersBox.put(orderId, {
      ...Map<String, dynamic>.from(m),
      'status': status,
    });
  }

  static Map<String, double> getProductCategoriesCountGlobal() {
    final counts = <String, double>{};
    for (final p in getAllProducts()) {
      final c = (p['category'] as String?) ?? 'Unknown';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, double> getOrderStatusCountGlobal() {
    final counts = <String, double>{};
    for (final o in ordersBox.values.map((e) => Map<String, dynamic>.from(e))) {
      final s = (o['status'] as String?) ?? 'unknown';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  static List<Map<String, dynamic>> getMonthlySalesForYear(int year) {
    final salesByMonth = List<double>.filled(12, 0.0);
    for (final o in ordersBox.values.map((e) => Map<String, dynamic>.from(e))) {
      final created = DateTime.tryParse(o['created_at'] ?? '');
      if (created == null || created.year != year) continue;
      final price = (o['total_price'] as num?)?.toDouble() ?? 0.0;
      salesByMonth[created.month - 1] += price;
    }
    final list = <Map<String, dynamic>>[];
    for (int m = 1; m <= 12; m++) {
      list.add({'month': m, 'sales': salesByMonth[m - 1]});
    }
    return list;
  }

  static List<Map<String, dynamic>> getAllOrdersEnriched() {
    final products = { for (final p in getAllProducts()) p['id']: p };
    final users = { for (final u in getAllUsers()) u['id']: u };
    return ordersBox.values.map((e) {
      final o = Map<String, dynamic>.from(e);
      final p = products[o['product_id']];
      final buyer = users[o['buyer_id']];
      return {
        ...o,
        'product_name': p?['name'],
        'image': p?['image'],
        'buyer_name': buyer?['name'],
      };
    }).toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  }

  static Future<void> setUserStatus(int userId, String status) async {
    final u = usersBox.get(userId);
    if (u == null) return;
    await usersBox.put(userId, { ...Map<String, dynamic>.from(u), 'status': status });
  }

  static Future<void> deleteUserCascade(int userId) async {
    // Remove carts
    final cartKeys = <dynamic>[];
    for (final k in cartBox.keys) {
      final v = cartBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['buyer_id'] == userId) cartKeys.add(k);
    }
    await cartBox.deleteAll(cartKeys);

    // Remove wishlist
    final wishKeys = <dynamic>[];
    for (final k in wishlistBox.keys) {
      final v = wishlistBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['buyer_id'] == userId) wishKeys.add(k);
    }
    await wishlistBox.deleteAll(wishKeys);

    // Remove messages
    final msgKeys = <dynamic>[];
    for (final k in messagesBox.keys) {
      final v = messagesBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['sender_id'] == userId || m['receiver_id'] == userId) msgKeys.add(k);
    }
    await messagesBox.deleteAll(msgKeys);

    // Remove notifications
    final notiKeys = <dynamic>[];
    for (final k in notificationsBox.keys) {
      final v = notificationsBox.get(k);
      if (v == null) continue;
      final m = Map<String, dynamic>.from(v);
      if (m['user_id'] == userId) notiKeys.add(k);
    }
    await notificationsBox.deleteAll(notiKeys);

    // Remove products and related orders if farmer
    final user = usersBox.get(userId) as Map?;
    if (user != null && user['role'] == 'farmer') {
      final prodKeys = <dynamic>[];
      for (final k in productsBox.keys) {
        final v = productsBox.get(k);
        if (v == null) continue;
        final m = Map<String, dynamic>.from(v);
        if (m['farmer_id'] == userId) prodKeys.add(k);
      }
      await productsBox.deleteAll(prodKeys);

      // delete orders referencing removed products or buyer
      final orderKeys = <dynamic>[];
      for (final k in ordersBox.keys) {
        final v = ordersBox.get(k);
        if (v == null) continue;
        final m = Map<String, dynamic>.from(v);
        if (m['buyer_id'] == userId) { orderKeys.add(k); continue; }
        // If product no longer exists, remove
        if (!productsBox.containsKey(m['product_id'])) orderKeys.add(k);
      }
      await ordersBox.deleteAll(orderKeys);
    } else {
      // Remove orders for this buyer
      final orderKeys = <dynamic>[];
      for (final k in ordersBox.keys) {
        final v = ordersBox.get(k);
        if (v == null) continue;
        final m = Map<String, dynamic>.from(v);
        if (m['buyer_id'] == userId) orderKeys.add(k);
      }
      await ordersBox.deleteAll(orderKeys);
    }

    // Finally delete user
    await usersBox.delete(userId);
  }

  // Farmer dashboard aggregates
  static int countProductsByFarmer(int farmerId) {
    return getProductsByFarmer(farmerId).length;
  }

  static int countProductsByFarmerSince(int farmerId, DateTime since) {
    return getProductsByFarmer(farmerId)
        .where((p) {
          final created = DateTime.tryParse(p['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return created.isAfter(since);
        })
        .length;
  }

  static int countOrdersForFarmer(int farmerId) {
    return getOrdersByFarmer(farmerId).length;
  }

  static int countOrdersForFarmerSince(int farmerId, DateTime since) {
    return getOrdersByFarmer(farmerId)
        .where((o) {
          final created = DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return created.isAfter(since);
        })
        .length;
  }

  static double sumSalesForFarmer(int farmerId) {
    return getOrdersByFarmer(farmerId)
        .fold<double>(0.0, (acc, o) => acc + ((o['total_price'] as num?)?.toDouble() ?? 0.0));
  }

  static double sumSalesForFarmerSince(int farmerId, DateTime since) {
    return getOrdersByFarmer(farmerId)
        .where((o) {
          final created = DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return created.isAfter(since);
        })
        .fold<double>(0.0, (acc, o) => acc + ((o['total_price'] as num?)?.toDouble() ?? 0.0));
  }

  // Messages
  static Future<void> addMessage({
    required String subject,
    required String message,
    required int senderId,
    required int receiverId,
  }) async {
    final id = await nextMessageId();
    await messagesBox.put(id, {
      'id': id,
      'subject': subject,
      'message': message,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0,
    });
  }

  static List<Map<String, dynamic>> getMessagesForReceiver(int receiverId, {String filter = 'all'}) {
    final all = messagesBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((m) => m['receiver_id'] == receiverId)
        .toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    List<Map<String, dynamic>> filtered = all;
    if (filter == 'unread') {
      filtered = all.where((m) => (m['is_read'] as int? ?? 0) == 0).toList();
    } else if (filter == 'read') {
      filtered = all.where((m) => (m['is_read'] as int? ?? 0) == 1).toList();
    }
    final users = { for (final u in usersBox.values) (u as Map)['id']: u };
    return filtered.map((m) {
      final sender = users[m['sender_id']];
      return {
        ...m,
        'sender_name': sender != null ? (sender as Map)['name'] : 'User',
        'sender_email': sender != null ? (sender as Map)['email'] : null,
        'sender_role': sender != null ? (sender as Map)['role'] : null,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> getMessagesForSender(int senderId, {String filter = 'all'}) {
    final all = messagesBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((m) => m['sender_id'] == senderId)
        .toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    List<Map<String, dynamic>> filtered = all;
    if (filter == 'unread') {
      filtered = all.where((m) => (m['is_read'] as int? ?? 0) == 0).toList();
    } else if (filter == 'read') {
      filtered = all.where((m) => (m['is_read'] as int? ?? 0) == 1).toList();
    }
    final users = { for (final u in usersBox.values) (u as Map)['id']: u };
    return filtered.map((m) {
      final receiver = users[m['receiver_id']];
      return {
        ...m,
        'receiver_name': receiver != null ? (receiver as Map)['name'] : 'User',
        'receiver_email': receiver != null ? (receiver as Map)['email'] : null,
        'receiver_role': receiver != null ? (receiver as Map)['role'] : null,
      };
    }).toList();
  }

  static Future<void> markMessageRead(int messageId) async {
    final m = messagesBox.get(messageId);
    if (m == null) return;
    await messagesBox.put(messageId, {...Map<String, dynamic>.from(m), 'is_read': 1});
  }

  static Future<void> deleteMessage(int messageId) async {
    await messagesBox.delete(messageId);
  }

  // Users listing by role
  static List<Map<String, dynamic>> getUsersByRole(String role) {
    return usersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((u) => u['role'] == role)
        .toList();
  }

  static List<Map<String, dynamic>> getAllNonAdminUsers() {
    return usersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((u) => u['role'] != 'admin')
        .toList();
  }

  // Notifications
  static Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    required int userId,
  }) async {
    final id = await nextNotificationId();
    await notificationsBox.put(id, {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'user_id': userId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> getNotificationsForUser(int userId, {String filter = 'all'}) {
    final all = notificationsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((n) => n['user_id'] == userId)
        .toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    
    List<Map<String, dynamic>> filtered = all;
    if (filter == 'unread') {
      filtered = all.where((n) => (n['is_read'] as int? ?? 0) == 0).toList();
    } else if (filter == 'read') {
      filtered = all.where((n) => (n['is_read'] as int? ?? 0) == 1).toList();
    }
    return filtered;
  }

  static Future<void> markNotificationRead(int notificationId) async {
    final n = notificationsBox.get(notificationId);
    if (n == null) return;
    await notificationsBox.put(notificationId, {...Map<String, dynamic>.from(n), 'is_read': 1});
  }

  static Future<void> deleteNotification(int notificationId) async {
    await notificationsBox.delete(notificationId);
  }
}


