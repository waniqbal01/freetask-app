import 'user.dart';

class PayoutModel {
  const PayoutModel({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.status,
    this.freelancer,
    this.method,
    this.reference,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String transactionId;
  final double amount;
  final String status;
  final UserModel? freelancer;
  final String? method;
  final String? reference;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    UserModel? parseFreelancer(dynamic value) {
      if (value is Map<String, dynamic>) {
        return UserModel.fromJson(value);
      }
      return null;
    }

    return PayoutModel(
      id: json['id']?.toString() ?? '',
      transactionId: json['transaction']?.toString() ?? json['transactionId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      freelancer: parseFreelancer(json['freelancer']),
      method: json['method'] as String?,
      reference: json['reference'] as String?,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction': transactionId,
      'amount': amount,
      'status': status,
      'freelancer': freelancer?.toJson(),
      'method': method,
      'reference': reference,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
