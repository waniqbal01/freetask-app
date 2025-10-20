import 'package:equatable/equatable.dart';

class Review extends Equatable {
  const Review({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      reviewerId: json['reviewerId']?.toString() ??
          json['authorId']?.toString() ??
          '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment']?.toString() ?? json['feedback']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String jobId;
  final String reviewerId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review copyWith({
    String? id,
    String? jobId,
    String? reviewerId,
    double? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      reviewerId: reviewerId ?? this.reviewerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'reviewerId': reviewerId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, jobId, reviewerId, rating, comment, createdAt];
}
