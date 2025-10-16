import 'package:equatable/equatable.dart';

import '../../models/job.dart';

abstract class JobEvent extends Equatable {
  const JobEvent();

  @override
  List<Object?> get props => [];
}

class LoadJobList extends JobEvent {
  const LoadJobList(this.type);

  final JobListType type;

  @override
  List<Object?> get props => [type];
}

class LoadJobDetail extends JobEvent {
  const LoadJobDetail(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class CreateJobRequested extends JobEvent {
  const CreateJobRequested({
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.location,
    this.attachments = const [],
  });

  final String title;
  final String description;
  final double price;
  final String category;
  final String location;
  final List<String> attachments;

  @override
  List<Object?> get props => [
        title,
        description,
        price,
        category,
        location,
        attachments,
      ];
}

class AcceptJobRequested extends JobEvent {
  const AcceptJobRequested(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class CompleteJobRequested extends JobEvent {
  const CompleteJobRequested(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class PayJobRequested extends JobEvent {
  const PayJobRequested(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class ClearJobMessage extends JobEvent {
  const ClearJobMessage();
}

enum JobListType { available, mine, completed }
