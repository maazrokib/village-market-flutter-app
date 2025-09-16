class Product {
  final int? id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String? image;
  final int farmerId;
  final String createdAt;

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    this.image,
    required this.farmerId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'image': image,
      'farmer_id': farmerId,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      category: map['category'],
      description: map['description'],
      image: map['image'],
      farmerId: map['farmer_id'],
      createdAt: map['created_at'],
    );
  }
}
