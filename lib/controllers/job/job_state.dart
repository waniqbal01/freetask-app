import 'package:equatable/equatable.dart';

import '../../models/job.dart';
import 'job_event.dart';

class JobState extends Equatable {
  const JobState({
    this.jobLists = const {},
    this.selectedJob,
    this.isLoadingList = false,
    this.isLoadingDetail = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.currentList = JobListType.available,
  });

  final Map<JobListType, List<Job>> jobLists;
  final Job? selectedJob;
  final bool isLoadingList;
  final bool isLoadingDetail;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final JobListType currentList;

  List<Job> get jobsForCurrentTab => jobLists[currentList] ?? const [];

  JobState copyWith({
    Map<JobListType, List<Job>>? jobLists,
    Job? selectedJob,
    bool? isLoadingList,
    bool? isLoadingDetail,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    JobListType? currentList,
    bool clearSelectedJob = false,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return JobState(
      jobLists: jobLists ?? this.jobLists,
      selectedJob:
          clearSelectedJob ? null : (selectedJob ?? this.selectedJob),
      isLoadingList: isLoadingList ?? this.isLoadingList,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError
          ? null
          : (errorMessage ?? this.errorMessage),
      successMessage: clearMessage
          ? null
          : (successMessage ?? this.successMessage),
      currentList: currentList ?? this.currentList,
    );
  }

  @override
  List<Object?> get props => [
        jobLists,
        selectedJob,
        isLoadingList,
        isLoadingDetail,
        isSubmitting,
        errorMessage,
        successMessage,
        currentList,
      ];
}
