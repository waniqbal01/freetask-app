import 'user.dart';

class Service {
  const Service({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.deliveryTime,
    required this.status,
    this.media = const [],
    this.freelancerId,
    this.freelancer,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final int deliveryTime;
  final String status;
  final List<String> media;
  final String? freelancerId;
  final UserModel? freelancer;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Service.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    List<String> parseMedia(dynamic value) {
      if (value is List) {
        return value.whereType<String>().toList(growable: false);
      }
      return const [];
    }

    UserModel? parseFreelancer(dynamic value) {
      if (value is Map<String, dynamic>) {
        return UserModel.fromJson(value);
      }
      return null;
    }

    return Service(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      deliveryTime: (json['deliveryTime'] as num?)?.toInt() ??
          int.tryParse(json['delivery_time']?.toString() ?? '') ??
          0,
      status: json['status'] as String? ?? 'published',
      media: parseMedia(json['media']),
      freelancerId: json['freelancer']?.toString(),
      freelancer: parseFreelancer(json['freelancer']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'deliveryTime': deliveryTime,
      'status': status,
      'media': media,
      'freelancer': freelancer?.toJson() ?? freelancerId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Service copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? price,
    int? deliveryTime,
    String? status,
    List<String>? media,
    String? freelancerId,
    UserModel? freelancer,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      status: status ?? this.status,
      media: media ?? this.media,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancer: freelancer ?? this.freelancer,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
