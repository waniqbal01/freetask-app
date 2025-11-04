import 'service.dart';
import 'user.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    this.requirements,
    this.deliveredWork,
    this.revisionNotes,
    this.service,
    this.client,
    this.freelancer,
    this.deliveryDate,
    this.deliveredAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String status;
  final double totalAmount;
  final String? requirements;
  final String? deliveredWork;
  final String? revisionNotes;
  final Service? service;
  final UserModel? client;
  final UserModel? freelancer;
  final DateTime? deliveryDate;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    Service? parseService(dynamic value) {
      if (value is Map<String, dynamic>) {
        return Service.fromJson(value);
      }
      return null;
    }

    UserModel? parseUser(dynamic value) {
      if (value is Map<String, dynamic>) {
        return UserModel.fromJson(value);
      }
      return null;
    }

    return OrderModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? 'pending',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble() ??
          0,
      requirements: json['requirements'] as String?,
      deliveredWork: json['deliveredWork'] as String? ?? json['delivered_work'] as String?,
      revisionNotes: json['revisionNotes'] as String? ?? json['revision_notes'] as String?,
      service: parseService(json['service']),
      client: parseUser(json['client']),
      freelancer: parseUser(json['freelancer']),
      deliveryDate: parseDate(json['deliveryDate'] ?? json['delivery_date']),
      deliveredAt: parseDate(json['deliveredAt'] ?? json['delivered_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'totalAmount': totalAmount,
      'requirements': requirements,
      'deliveredWork': deliveredWork,
      'revisionNotes': revisionNotes,
      'service': service?.toJson(),
      'client': client?.toJson(),
      'freelancer': freelancer?.toJson(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
