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
    this.averageRating = 0,
    this.reviewCount = 0,
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
  final double averageRating;
  final int reviewCount;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? readString(dynamic value) {
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
      avatarUrl: readString(
        json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'],
      )?.trim(),
      bio: readString(json['bio'] ?? json['about'])?.trim(),
      location: readString(
        json['location'] ?? json['address'] ?? json['city'],
      )?.trim(),
      phoneNumber: readString(
        json['phoneNumber'] ?? json['phone'] ?? json['contactNumber'],
      )?.trim(),
      verified: json['verified'] as bool? ?? false,
      averageRating: (json['averageRating'] as num?)?.toDouble() ??
          (json['rating'] as num?)?.toDouble() ??
          (json['avg_rating'] as num?)?.toDouble() ??
          0,
      reviewCount: json['reviewCount'] as int? ??
          json['reviewsCount'] as int? ??
          json['total_reviews'] as int? ??
          0,
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
      'averageRating': averageRating,
      'reviewCount': reviewCount,
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
    double? averageRating,
    int? reviewCount,
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
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
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
    super.averageRating,
    super.reviewCount,
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
      averageRating: model.averageRating,
      reviewCount: model.reviewCount,
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
    double? averageRating,
    int? reviewCount,
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
      averageRating: averageRating,
      reviewCount: reviewCount,
    );
    return User.fromModel(model);
  }
}
