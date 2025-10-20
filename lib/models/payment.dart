import 'package:equatable/equatable.dart';

enum PaymentStatus {
  pending,
  released,
  withdrawn,
  failed,
}

extension PaymentStatusX on PaymentStatus {
  static PaymentStatus fromValue(String? value) {
    switch (value) {
      case 'released':
        return PaymentStatus.released;
      case 'withdrawn':
        return PaymentStatus.withdrawn;
      case 'failed':
        return PaymentStatus.failed;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending (Escrow)';
      case PaymentStatus.released:
        return 'Released';
      case PaymentStatus.withdrawn:
        return 'Withdrawn';
      case PaymentStatus.failed:
        return 'Failed';
    }
  }

  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.released:
        return 'released';
      case PaymentStatus.withdrawn:
        return 'withdrawn';
      case PaymentStatus.failed:
        return 'failed';
    }
  }
}

class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.status,
    required this.updatedAt,
    this.releasedBy,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ??
          (json['value'] as num?)?.toDouble() ??
          0,
      status: PaymentStatusX.fromValue(json['status']?.toString()),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      releasedBy: json['releasedBy']?.toString() ?? json['released_by']?.toString(),
    );
  }

  final String id;
  final String jobId;
  final double amount;
  final PaymentStatus status;
  final DateTime updatedAt;
  final String? releasedBy;

  bool get isPending => status == PaymentStatus.pending;
  bool get isReleased => status == PaymentStatus.released;
  bool get isWithdrawn => status == PaymentStatus.withdrawn;

  Payment copyWith({
    String? id,
    String? jobId,
    double? amount,
    PaymentStatus? status,
    DateTime? updatedAt,
    String? releasedBy,
  }) {
    return Payment(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      releasedBy: releasedBy ?? this.releasedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'amount': amount,
      'status': status.value,
      'updatedAt': updatedAt.toIso8601String(),
      'releasedBy': releasedBy,
    };
  }

  @override
  List<Object?> get props => [id, jobId, amount, status, updatedAt, releasedBy];
}
