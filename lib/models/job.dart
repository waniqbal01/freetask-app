import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum JobStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

extension JobStatusX on JobStatus {
  String get apiValue {
    switch (this) {
      case JobStatus.pending:
        return 'pending';
      case JobStatus.inProgress:
        return 'in_progress';
      case JobStatus.completed:
        return 'completed';
      case JobStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case JobStatus.pending:
        return '🟢 Open';
      case JobStatus.inProgress:
        return '🟡 In Progress';
      case JobStatus.completed:
        return '🔵 Completed';
      case JobStatus.cancelled:
        return '🔴 Cancelled';
    }
  }

  double get progress {
    switch (this) {
      case JobStatus.pending:
        return 0.1;
      case JobStatus.inProgress:
        return 0.6;
      case JobStatus.completed:
        return 1;
      case JobStatus.cancelled:
        return 0;
    }
  }

  Color statusColor(ThemeData theme) {
    switch (this) {
      case JobStatus.pending:
        return theme.colorScheme.primary;
      case JobStatus.inProgress:
        return Colors.orange;
      case JobStatus.completed:
        return Colors.blue;
      case JobStatus.cancelled:
        return Colors.red;
    }
  }
}

class JobAttachment extends Equatable {
  const JobAttachment({
    required this.url,
    required this.name,
    this.thumbnailUrl,
  });

  factory JobAttachment.fromJson(Map<String, dynamic> json) {
    return JobAttachment(
      url: json['url']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['filename']?.toString() ??
          json['originalName']?.toString() ??
          '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ??
          json['thumbnail']?.toString(),
    );
  }

  final String url;
  final String name;
  final String? thumbnailUrl;

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  @override
  List<Object?> get props => [url, name, thumbnailUrl];
}

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
    this.clientName,
    this.freelancerId,
    this.freelancerName,
    required this.createdAt,
    this.updatedAt,
    this.attachments = const [],
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final status = _mapStatus(json['status']);
    return Job(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _parsePrice(json['price']),
      category: json['category']?.toString() ??
          json['categoryName']?.toString() ??
          json['category_label']?.toString() ??
          '',
      location: json['location']?.toString() ??
          json['address']?.toString() ??
          '',
      status: status,
      clientId: json['clientId']?.toString() ??
          json['client_id']?.toString() ??
          '',
      clientName: json['clientName']?.toString() ??
          json['client']?['name']?.toString(),
      freelancerId: json['freelancerId']?.toString() ??
          json['freelancer_id']?.toString() ??
          json['assignedFreelancerId']?.toString(),
      freelancerName: json['freelancerName']?.toString() ??
          json['freelancer']?['name']?.toString(),
      createdAt: _parseDate(json['createdAt']) ??
          _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _parseDate(json['updatedAt']) ??
          _parseDate(json['updated_at']),
      attachments: _parseAttachments(json['attachments']),
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
  final String? clientName;
  final String? freelancerId;
  final String? freelancerName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<JobAttachment> attachments;

  bool get isPending => status == JobStatus.pending;

  bool get isInProgress => status == JobStatus.inProgress;

  bool get isCompleted => status == JobStatus.completed;

  bool get isCancelled => status == JobStatus.cancelled;

  Job copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? category,
    String? location,
    JobStatus? status,
    String? clientId,
    String? clientName,
    String? freelancerId,
    String? freelancerName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<JobAttachment>? attachments,
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
      clientName: clientName ?? this.clientName,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'location': location,
      'status': status.apiValue,
      'clientId': clientId,
      'clientName': clientName,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
    };
  }

  static JobStatus _mapStatus(dynamic value) {
    final status = value?.toString().toLowerCase() ?? 'pending';
    switch (status) {
      case 'pending':
        return JobStatus.pending;
      case 'in_progress':
      case 'in-progress':
      case 'inprogress':
        return JobStatus.inProgress;
      case 'completed':
      case 'complete':
        return JobStatus.completed;
      case 'cancelled':
      case 'canceled':
        return JobStatus.cancelled;
      default:
        return JobStatus.pending;
    }
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static List<JobAttachment> _parseAttachments(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .map(JobAttachment.fromJson)
          .toList(growable: false);
    }
    return const [];
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
        clientName,
        freelancerId,
        freelancerName,
        createdAt,
        updatedAt,
        attachments,
      ];
}
