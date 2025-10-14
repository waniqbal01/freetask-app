class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.verified,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final bool verified;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'client',
      avatarUrl: json['avatarUrl'] as String?,
      verified: json['verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatarUrl': avatarUrl,
      'verified': verified,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    bool? verified,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      verified: verified ?? this.verified,
    );
  }
}
