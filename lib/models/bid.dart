import 'package:equatable/equatable.dart';

import 'user.dart';

class Bid extends Equatable {
  const Bid({
    required this.id,
    required this.jobId,
    required this.bidder,
    required this.amount,
    required this.message,
    required this.submittedAt,
    this.status = BidStatus.pending,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      bidder: User.fromJson(
        (json['bidder'] as Map<String, dynamic>?) ??
            <String, dynamic>{'id': json['bidderId'] ?? '', 'name': json['bidderName'] ?? ''},
      ),
      amount: (json['amount'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0,
      message: json['message']?.toString() ?? json['coverLetter']?.toString() ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: BidStatusX.fromValue(json['status']?.toString()),
    );
  }

  final String id;
  final String jobId;
  final User bidder;
  final double amount;
  final String message;
  final DateTime submittedAt;
  final BidStatus status;

  Bid copyWith({
    String? id,
    String? jobId,
    User? bidder,
    double? amount,
    String? message,
    DateTime? submittedAt,
    BidStatus? status,
  }) {
    return Bid(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      bidder: bidder ?? this.bidder,
      amount: amount ?? this.amount,
      message: message ?? this.message,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'bidder': bidder.toJson(),
      'amount': amount,
      'message': message,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.value,
    };
  }

  @override
  List<Object?> get props => [
        id,
        jobId,
        bidder,
        amount,
        message,
        submittedAt,
        status,
      ];
}

enum BidStatus {
  pending,
  accepted,
  rejected,
  withdrawn,
}

extension BidStatusX on BidStatus {
  static BidStatus fromValue(String? value) {
    switch (value) {
      case 'accepted':
        return BidStatus.accepted;
      case 'rejected':
        return BidStatus.rejected;
      case 'withdrawn':
        return BidStatus.withdrawn;
      case 'pending':
      default:
        return BidStatus.pending;
    }
  }

  String get value {
    switch (this) {
      case BidStatus.pending:
        return 'pending';
      case BidStatus.accepted:
        return 'accepted';
      case BidStatus.rejected:
        return 'rejected';
      case BidStatus.withdrawn:
        return 'withdrawn';
    }
  }

  String get label {
    switch (this) {
      case BidStatus.pending:
        return 'Pending';
      case BidStatus.accepted:
        return 'Accepted';
      case BidStatus.rejected:
        return 'Rejected';
      case BidStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}
