class User {
  final int id;
  final String name;
  final String email;
  final DateTime? createdAt;

  User({required this.id, required this.name, required this.email, this.createdAt});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'createdAt': createdAt?.toIso8601String()};

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
  );

  User copyWith({int? id, String? name, String? email, DateTime? createdAt}) =>
      User(id: id ?? this.id, name: name ?? this.name, email: email ?? this.email, createdAt: createdAt ?? this.createdAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is User && id == other.id && name == other.name && email == other.email && createdAt == other.createdAt;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode ^ createdAt.hashCode;
}
