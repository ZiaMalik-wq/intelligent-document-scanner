class User {
  final int id;
  final String? name;
  final String email;
  final DateTime createdAt;

  User({
    required this.id,
    this.name,
    required this.email,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['full_name'] ?? json['name'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
