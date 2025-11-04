class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.platformFee,
    required this.freelancerAmount,
    required this.status,
    required this.type,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final double amount;
  final double platformFee;
  final double freelancerAmount;
  final String status;
  final String type;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order']?.toString() ?? json['orderId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ??
          (json['platform_fee'] as num?)?.toDouble() ??
          0,
      freelancerAmount: (json['freelancerAmount'] as num?)?.toDouble() ??
          (json['freelancer_amount'] as num?)?.toDouble() ??
          0,
      status: json['status'] as String? ?? 'escrow',
      type: json['type'] as String? ?? 'escrow',
      notes: json['notes'] as String?,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': orderId,
      'amount': amount,
      'platformFee': platformFee,
      'freelancerAmount': freelancerAmount,
      'status': status,
      'type': type,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
