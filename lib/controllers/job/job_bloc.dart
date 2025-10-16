import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/job.dart';
import '../../utils/logger.dart';
import 'job_event.dart';
import 'job_state.dart';
import '../../services/job_service.dart';

class JobBloc extends Bloc<JobEvent, JobState> {
  JobBloc(this._jobService) : super(const JobState()) {
    on<LoadJobList>(_onLoadJobList);
    on<LoadJobDetail>(_onLoadJobDetail);
    on<CreateJobRequested>(_onCreateJobRequested);
    on<AcceptJobRequested>(_onAcceptJobRequested);
    on<CompleteJobRequested>(_onCompleteJobRequested);
    on<PayJobRequested>(_onPayJobRequested);
    on<ClearJobMessage>(_onClearJobMessage);
  }

  final JobService _jobService;

  Future<void> _onLoadJobList(
    LoadJobList event,
    Emitter<JobState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingList: true,
        currentList: event.type,
        clearError: true,
        clearMessage: true,
      ),
    );
    try {
      final jobs = await _jobService.fetchJobs(
        status: _statusFor(event.type),
        mine: event.type == JobListType.mine,
      );
      emit(
        state.copyWith(
          jobLists: {
            ...state.jobLists,
            event.type: jobs,
          },
          isLoadingList: false,
        ),
      );
    } on JobException catch (error, stackTrace) {
      appLog('Failed to load jobs', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoadingList: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on load jobs', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoadingList: false,
          errorMessage: 'Unable to load jobs right now.',
        ),
      );
    }
  }

  Future<void> _onLoadJobDetail(
    LoadJobDetail event,
    Emitter<JobState> emit,
  ) async {
    emit(state.copyWith(isLoadingDetail: true, clearError: true));
    try {
      final job = await _jobService.fetchJobDetail(event.jobId);
      emit(
        state.copyWith(
          selectedJob: job,
          isLoadingDetail: false,
        ),
      );
    } on JobException catch (error, stackTrace) {
      appLog('Failed to load job detail', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoadingDetail: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on load job detail',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoadingDetail: false,
          errorMessage: 'Unable to load job detail.',
        ),
      );
    }
  }

  Future<void> _onCreateJobRequested(
    CreateJobRequested event,
    Emitter<JobState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearMessage: true));
    try {
      final job = await _jobService.createJob(
        title: event.title,
        description: event.description,
        price: event.price,
        category: event.category,
        location: event.location,
        attachments: event.attachments,
      );
      final updatedMyJobs = [job, ...state.jobLists[JobListType.mine] ?? const []];
      emit(
        state.copyWith(
          jobLists: {
            ...state.jobLists,
            JobListType.mine: updatedMyJobs,
            JobListType.available: [
              job,
              ...state.jobLists[JobListType.available] ?? const [],
            ],
          },
          isSubmitting: false,
          successMessage: 'Job created successfully.',
        ),
      );
    } on JobException catch (error, stackTrace) {
      appLog('Failed to create job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on create job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Unable to create job.',
        ),
      );
    }
  }

  Future<void> _onAcceptJobRequested(
    AcceptJobRequested event,
    Emitter<JobState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final job = await _jobService.acceptJob(event.jobId);
      _updateJobLists(emit, job, successMessage: 'Job accepted!');
    } on JobException catch (error, stackTrace) {
      appLog('Failed to accept job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on accept job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Unable to accept job.',
        ),
      );
    }
  }

  Future<void> _onCompleteJobRequested(
    CompleteJobRequested event,
    Emitter<JobState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final job = await _jobService.completeJob(event.jobId);
      _updateJobLists(emit, job, successMessage: 'Job marked as complete.');
    } on JobException catch (error, stackTrace) {
      appLog('Failed to complete job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on complete job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Unable to complete job.',
        ),
      );
    }
  }

  Future<void> _onPayJobRequested(
    PayJobRequested event,
    Emitter<JobState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final job = await _jobService.payForJob(event.jobId);
      _updateJobLists(emit, job, successMessage: 'Payment processed successfully.');
    } on JobException catch (error, stackTrace) {
      appLog('Failed to pay for job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on pay job', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Unable to process payment.',
        ),
      );
    }
  }

  void _updateJobLists(
    Emitter<JobState> emit,
    Job job, {
    required String successMessage,
  }) {
    final available = [...state.jobLists[JobListType.available] ?? const []]
      ..removeWhere((item) => item.id == job.id);
    final mine = [...state.jobLists[JobListType.mine] ?? const []]
      ..removeWhere((item) => item.id == job.id);
    final completed = [...state.jobLists[JobListType.completed] ?? const []]
      ..removeWhere((item) => item.id == job.id);

    switch (job.status) {
      case JobStatus.pending:
        available.insert(0, job);
        break;
      case JobStatus.inProgress:
        mine.insert(0, job);
        break;
      case JobStatus.completed:
        completed.insert(0, job);
        break;
    }

    emit(
      state.copyWith(
        jobLists: {
          JobListType.available: available,
          JobListType.mine: mine,
          JobListType.completed: completed,
        },
        selectedJob: job,
        isSubmitting: false,
        successMessage: successMessage,
      ),
    );
  }

  void _onClearJobMessage(ClearJobMessage event, Emitter<JobState> emit) {
    emit(state.copyWith(clearMessage: true, clearError: true));
  }

  JobStatus? _statusFor(JobListType type) {
    switch (type) {
      case JobListType.available:
        return JobStatus.pending;
      case JobListType.mine:
        return null;
      case JobListType.completed:
        return JobStatus.completed;
    }
  }
}
