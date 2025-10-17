import 'package:equatable/equatable.dart';

import '../../models/job.dart';

abstract class JobEvent extends Equatable {
  const JobEvent();

  @override
  List<Object?> get props => [];
}

class JobTabChanged extends JobEvent {
  const JobTabChanged(this.tab);

  final JobListType tab;

  @override
  List<Object?> get props => [tab];
}

class JobListRequested extends JobEvent {
  const JobListRequested(this.type, {this.refresh = false});

  final JobListType type;
  final bool refresh;

  @override
  List<Object?> get props => [type, refresh];
}

class JobLoadMoreRequested extends JobEvent {
  const JobLoadMoreRequested(this.type);

  final JobListType type;

  @override
  List<Object?> get props => [type];
}

class JobSearchChanged extends JobEvent {
  const JobSearchChanged({
    required this.type,
    required this.query,
  });

  final JobListType type;
  final String query;

  @override
  List<Object?> get props => [type, query];
}

class JobFilterChanged extends JobEvent {
  const JobFilterChanged({
    required this.type,
    this.status,
    this.category,
    this.minBudget,
    this.maxBudget,
    this.location,
    this.clearBudget = false,
    this.clearLocation = false,
  });

  final JobListType type;
  final JobStatus? status;
  final String? category;
  final double? minBudget;
  final double? maxBudget;
  final String? location;
  final bool clearBudget;
  final bool clearLocation;

  @override
  List<Object?> get props => [
        type,
        status,
        category,
        minBudget,
        maxBudget,
        location,
        clearBudget,
        clearLocation,
      ];
}

class LoadJobDetail extends JobEvent {
  const LoadJobDetail(this.jobId, {this.force = false});

  final String jobId;
  final bool force;

  @override
  List<Object?> get props => [jobId, force];
}

class CreateJobRequested extends JobEvent {
  const CreateJobRequested({
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.location,
    this.imagePaths = const [],
  });

  final String title;
  final String description;
  final double price;
  final String category;
  final String location;
  final List<String> imagePaths;

  @override
  List<Object?> get props => [
        title,
        description,
        price,
        category,
        location,
        imagePaths,
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

class CancelJobRequested extends JobEvent {
  const CancelJobRequested(this.jobId);

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

class JobRealtimeUpdated extends JobEvent {
  const JobRealtimeUpdated(this.job);

  final Job job;

  @override
  List<Object?> get props => [job];
}

class ClearJobMessage extends JobEvent {
  const ClearJobMessage();
}

enum JobListType { available, mine, completed, all }
