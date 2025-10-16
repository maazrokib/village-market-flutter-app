class AppConstants {
  static const String appName = 'Village Market';
  
  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleFarmer = 'farmer';
  static const String roleBuyer = 'buyer';

  // Product Categories
  static const List<String> productCategories = [
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Meat',
    'Others'
  ];

  // Order Status
  static const String orderPending = 'pending';
  static const String orderConfirmed = 'confirmed';
  static const String orderProcessing = 'processing';
  static const String orderShipped = 'shipped';
  static const String orderDelivered = 'delivered';
  static const String orderCancelled = 'cancelled';
  static const String orderReturned = 'returned';

  // User Status
  static const String userActive = 'active';
  static const String userBanned = 'banned';
  static const String userSuspended = 'suspended';
  
  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentMobileBanking = 'mobile_banking';
}
