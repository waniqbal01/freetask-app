import '../utils/role_permissions.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.location,
    this.phoneNumber,
    this.verified = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final String? phoneNumber;
  final bool verified;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? _readString(dynamic value) {
      if (value is String) {
        return value;
      }
      if (value is num || value is bool) {
        return value.toString();
      }
      return null;
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? UserRoles.client,
      avatarUrl: _readString(
        json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'],
      )?.trim(),
      bio: _readString(json['bio'] ?? json['about'])?.trim(),
      location: _readString(
        json['location'] ?? json['address'] ?? json['city'],
      )?.trim(),
      phoneNumber: _readString(
        json['phoneNumber'] ?? json['phone'] ?? json['contactNumber'],
      )?.trim(),
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
      'bio': bio,
      'location': location,
      'phoneNumber': phoneNumber,
      'verified': verified,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    String? bio,
    String? location,
    String? phoneNumber,
    bool? verified,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verified: verified ?? this.verified,
    );
  }
}

class User extends UserModel {
  const User({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.avatarUrl,
    super.bio,
    super.location,
    super.phoneNumber,
    super.verified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User.fromModel(UserModel.fromJson(json));
  }

  factory User.fromModel(UserModel model) {
    return User(
      id: model.id,
      name: model.name,
      email: model.email,
      role: model.role,
      avatarUrl: model.avatarUrl,
      bio: model.bio,
      location: model.location,
      phoneNumber: model.phoneNumber,
      verified: model.verified,
    );
  }

  @override
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    String? bio,
    String? location,
    String? phoneNumber,
    bool? verified,
  }) {
    final model = super.copyWith(
      id: id,
      name: name,
      email: email,
      role: role,
      avatarUrl: avatarUrl,
      bio: bio,
      location: location,
      phoneNumber: phoneNumber,
      verified: verified,
    );
    return User.fromModel(model);
  }
}
