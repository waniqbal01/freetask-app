import 'package:equatable/equatable.dart';

class Job extends Equatable {
  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.location,
    required this.status,
    required this.clientId,
    this.freelancerId,
    required this.createdAt,
    this.attachments = const [],
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      category: json['category'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: _mapStatus(json['status'] as String?),
      clientId: json['clientId']?.toString() ?? '',
      freelancerId: json['freelancerId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String location;
  final JobStatus status;
  final String clientId;
  final String? freelancerId;
  final DateTime createdAt;
  final List<String> attachments;

  Job copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? category,
    String? location,
    JobStatus? status,
    String? clientId,
    String? freelancerId,
    DateTime? createdAt,
    List<String>? attachments,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      location: location ?? this.location,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      freelancerId: freelancerId ?? this.freelancerId,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
    );
  }

  static JobStatus _mapStatus(String? status) {
    switch (status) {
      case 'pending':
        return JobStatus.pending;
      case 'in_progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      default:
        return JobStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'location': location,
      'status': status.name,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'createdAt': createdAt.toIso8601String(),
      'attachments': attachments,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        price,
        category,
        location,
        status,
        clientId,
        freelancerId,
        createdAt,
        attachments,
      ];
}

enum JobStatus { pending, inProgress, completed }
