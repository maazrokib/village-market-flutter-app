class User {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String? phone;
  final String? address;
  final String? avatar;
  final String role;
  final String status;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.phone,
    this.address,
    this.avatar,
    required this.role,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'address': address,
      'avatar': avatar,
      'role': role,
      'status': status,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      phone: map['phone'],
      address: map['address'],
      avatar: map['avatar'],
      role: map['role'],
      status: map['status'],
    );
  }
}
