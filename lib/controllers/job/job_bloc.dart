import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';
import 'job_event.dart';
import 'job_state.dart';

class JobBloc extends Bloc<JobEvent, JobState> {
  JobBloc(this._jobService, this._storageService)
      : super(
          JobState(
            feeds: {
              JobListType.available:
                  const JobFeedState(statusFilter: JobStatus.pending),
              JobListType.mine: const JobFeedState(),
              JobListType.completed:
                  const JobFeedState(statusFilter: JobStatus.completed),
            },
          ),
        ) {
    on<JobTabChanged>(_onTabChanged);
    on<JobListRequested>(_onListRequested);
    on<JobLoadMoreRequested>(_onLoadMoreRequested);
    on<JobSearchChanged>(_onSearchChanged);
    on<JobFilterChanged>(_onFilterChanged);
    on<LoadJobDetail>(_onLoadJobDetail);
    on<CreateJobRequested>(_onCreateJobRequested);
    on<AcceptJobRequested>(_onAcceptJobRequested);
    on<CompleteJobRequested>(_onCompleteJobRequested);
    on<CancelJobRequested>(_onCancelJobRequested);
    on<PayJobRequested>(_onPayJobRequested);
    on<JobRealtimeUpdated>(_onRealtimeUpdated);
    on<ClearJobMessage>(_onClearJobMessage);
  }

  final JobService _jobService;
  final StorageService _storageService;

  String? get _currentUserId => _storageService.getUser()?.id;
  Future<void> _onTabChanged(
    JobTabChanged event,
    Emitter<JobState> emit,
  ) async {
    emit(state.copyWith(currentList: event.tab));
    final feed = state.feedFor(event.tab);
    if (!feed.initialized && !feed.isLoadingInitial) {
      add(JobListRequested(event.tab));
    }
  }

  Future<void> _onListRequested(
    JobListRequested event,
    Emitter<JobState> emit,
  ) async {
    final feed = state.feedFor(event.type);
    final isRefresh = event.refresh && feed.initialized;
    final updatedFeeds = Map<JobListType, JobFeedState>.from(state.feeds)
      ..[event.type] = feed.copyWith(
        isLoadingInitial: !isRefresh && !feed.initialized,
        isRefreshing: isRefresh,
        isLoadingMore: false,
        clearError: true,
      );
    emit(
      state.copyWith(
        feeds: updatedFeeds,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      final result = await _jobService.fetchJobs(
        page: 1,
        pageSize: feed.pageSize,
        status: feed.statusFilter ?? _defaultStatus(event.type),
        category: feed.categoryFilter,
        search: feed.searchQuery,
        mine: event.type != JobListType.available,
        includeHistory: event.type == JobListType.completed,
        minBudget: feed.minBudget,
        maxBudget: feed.maxBudget,
        location: feed.locationFilter,
        useCache: !isRefresh,
      );

      final categories = _mergeCategories(result.jobs);
      emit(
        state.copyWith(
          feeds: {
            ...state.feeds,
            event.type: feed.copyWith(
              jobs: result.jobs,
              page: result.page,
              pageSize: result.pageSize,
              hasMore: result.hasNextPage,
              isLoadingInitial: false,
              isRefreshing: false,
              initialized: true,
              clearError: true,
            ),
          },
          categories: categories,
        ),
      );
    } on JobException catch (error, stackTrace) {
      appLog('Failed to load jobs', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          feeds: {
            ...state.feeds,
            event.type: feed.copyWith(
              isLoadingInitial: false,
              isRefreshing: false,
              errorMessage: error.message,
            ),
          },
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on load jobs', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          feeds: {
            ...state.feeds,
            event.type: feed.copyWith(
              isLoadingInitial: false,
              isRefreshing: false,
              errorMessage: 'Unable to load jobs right now.',
            ),
          },
          errorMessage: 'Unable to load jobs right now.',
        ),
      );
    }
  }

  Future<void> _onLoadMoreRequested(
    JobLoadMoreRequested event,
    Emitter<JobState> emit,
  ) async {
    final feed = state.feedFor(event.type);
    if (!feed.initialized || feed.isLoadingMore || !feed.hasMore) {
      return;
    }
    emit(
      state.copyWith(
        feeds: {
          ...state.feeds,
          event.type: feed.copyWith(isLoadingMore: true, clearError: true),
        },
      ),
    );

    try {
      final result = await _jobService.fetchJobs(
        page: feed.page + 1,
        pageSize: feed.pageSize,
        status: feed.statusFilter ?? _defaultStatus(event.type),
        category: feed.categoryFilter,
        search: feed.searchQuery,
        mine: event.type != JobListType.available,
        includeHistory: event.type == JobListType.completed,
        minBudget: feed.minBudget,
        maxBudget: feed.maxBudget,
        location: feed.locationFilter,
        useCache: false,
      );

      final mergedJobs = <Job>[...feed.jobs];
      for (final job in result.jobs) {
        final index = mergedJobs.indexWhere((item) => item.id == job.id);
        if (index == -1) {
          mergedJobs.add(job);
        } else {
          mergedJobs[index] = job;
        }
      }

      emit(
        state.copyWith(
          feeds: {
            ...state.feeds,
            event.type: feed.copyWith(
              jobs: mergedJobs,
              page: result.page,
              pageSize: result.pageSize,
              hasMore: result.hasNextPage,
              isLoadingMore: false,
              initialized: true,
              clearError: true,
            ),
          },
          categories: _mergeCategories(result.jobs),
        ),
      );
    } on JobException catch (error, stackTrace) {
      appLog('Failed to load more jobs', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          feeds: {
            ...state.feeds,
            event.type: feed.copyWith(
              isLoadingMore: false,
              errorMessage: error.message,
            ),
          },
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on load more jobs', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          feeds: {
            ...state.feeds,
            event.type: feed.copyWith(
              isLoadingMore: false,
              errorMessage: 'Unable to load more jobs.',
            ),
          },
          errorMessage: 'Unable to load more jobs.',
        ),
      );
    }
  }

  FutureOr<void> _onSearchChanged(
    JobSearchChanged event,
    Emitter<JobState> emit,
  ) {
    final feed = state.feedFor(event.type);
    emit(
      state.copyWith(
        feeds: {
          ...state.feeds,
          event.type: feed.copyWith(
            searchQuery: event.query,
            page: 0,
            hasMore: true,
            initialized: feed.initialized,
          ),
        },
      ),
    );
    add(JobListRequested(event.type, refresh: true));
  }

  FutureOr<void> _onFilterChanged(
    JobFilterChanged event,
    Emitter<JobState> emit,
  ) {
    final feed = state.feedFor(event.type);
    final normalizedCategory = (event.category ?? '').trim();
    final shouldClearStatus = event.status == null;
    final shouldClearCategory = normalizedCategory.isEmpty;
    emit(
      state.copyWith(
        feeds: {
          ...state.feeds,
          event.type: feed.copyWith(
            statusFilter: event.status,
            categoryFilter:
                shouldClearCategory ? null : normalizedCategory,
            minBudget: event.minBudget,
            maxBudget: event.maxBudget,
            locationFilter: event.location,
            page: 0,
            hasMore: true,
            initialized: feed.initialized,
            clearStatusFilter: shouldClearStatus,
            clearCategoryFilter: shouldClearCategory,
            clearBudgetFilter: event.clearBudget,
            clearLocationFilter: event.clearLocation,
          ),
        },
      ),
    );
    add(JobListRequested(event.type, refresh: true));
  }

  Future<void> _onLoadJobDetail(
    LoadJobDetail event,
    Emitter<JobState> emit,
  ) async {
    if (state.isLoadingDetail && !event.force) return;
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
        imagePaths: event.imagePaths,
      );
      _emitWithUpdatedJob(
        emit,
        job,
        successMessage: 'Job created successfully.',
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
    await _handleMutation(
      emit,
      action: () => _jobService.acceptJob(event.jobId),
      successMessage: 'Job accepted! Let\'s get to work.',
      notificationBuilder: (job) => JobAlert(
        title: 'Job accepted',
        message: 'You have accepted ${job.title}.',
        job: job,
      ),
    );
  }

  Future<void> _onCompleteJobRequested(
    CompleteJobRequested event,
    Emitter<JobState> emit,
  ) async {
    await _handleMutation(
      emit,
      action: () => _jobService.completeJob(event.jobId),
      successMessage: 'Job marked as complete.',
      notificationBuilder: (job) => JobAlert(
        title: 'Job completed',
        message: '${job.title} has been completed.',
        job: job,
      ),
    );
  }

  Future<void> _onCancelJobRequested(
    CancelJobRequested event,
    Emitter<JobState> emit,
  ) async {
    await _handleMutation(
      emit,
      action: () => _jobService.cancelJob(event.jobId),
      successMessage: 'Job has been cancelled.',
      notificationBuilder: (job) => JobAlert(
        title: 'Job cancelled',
        message: '${job.title} was cancelled.',
        job: job,
      ),
    );
  }

  Future<void> _onPayJobRequested(
    PayJobRequested event,
    Emitter<JobState> emit,
  ) async {
    await _handleMutation(
      emit,
      action: () => _jobService.payForJob(event.jobId),
      successMessage: 'Payment processed successfully.',
    );
  }

  Future<void> _handleMutation(
    Emitter<JobState> emit, {
    required Future<Job> Function() action,
    required String successMessage,
    JobAlert Function(Job job)? notificationBuilder,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearMessage: true));
    try {
      final job = await action();
      _emitWithUpdatedJob(
        emit,
        job,
        successMessage: successMessage,
        notification: notificationBuilder?.call(job),
      );
    } on JobException catch (error, stackTrace) {
      appLog('Job mutation failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on job mutation', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Unable to update job.',
        ),
      );
    }
  }

  FutureOr<void> _onRealtimeUpdated(
    JobRealtimeUpdated event,
    Emitter<JobState> emit,
  ) {
    _emitWithUpdatedJob(emit, event.job);
  }

  void _emitWithUpdatedJob(
    Emitter<JobState> emit,
    Job job, {
    String? successMessage,
    JobAlert? notification,
  }) {
    final feeds = <JobListType, JobFeedState>{};
    for (final type in JobListType.values) {
      final feed = state.feedFor(type);
      final updated = _upsertJob(feed, job, type);
      feeds[type] = updated;
    }

    emit(
      state.copyWith(
        feeds: feeds,
        selectedJob: state.selectedJob?.id == job.id ? job : state.selectedJob,
        isSubmitting: false,
        successMessage: successMessage,
        notification: notification,
        categories: _mergeCategories([job]),
      ),
    );
  }

  JobFeedState _upsertJob(
    JobFeedState feed,
    Job job,
    JobListType type,
  ) {
    final matchesFilters = feed.matchesFilters(job);
    final include = matchesFilters && _shouldIncludeInList(job, type);
    final jobs = List<Job>.from(feed.jobs);
    final index = jobs.indexWhere((item) => item.id == job.id);

    if (include) {
      if (index >= 0) {
        jobs[index] = job;
      } else {
        jobs.insert(0, job);
      }
    } else if (index >= 0) {
      jobs.removeAt(index);
    }

    return feed.copyWith(jobs: jobs, initialized: true);
  }

  bool _shouldIncludeInList(Job job, JobListType type) {
    final userId = _currentUserId;
    switch (type) {
      case JobListType.available:
        final isUnassigned = job.freelancerId == null || job.freelancerId!.isEmpty;
        return job.status == JobStatus.pending && isUnassigned;
      case JobListType.mine:
        if (userId == null) return false;
        return job.clientId == userId || job.freelancerId == userId;
      case JobListType.completed:
        final isHistoryStatus =
            job.status == JobStatus.completed || job.status == JobStatus.cancelled;
        if (!isHistoryStatus) return false;
        if (userId == null) return true;
        return job.clientId == userId || job.freelancerId == userId;
    }
  }

  Set<String> _mergeCategories(List<Job> jobs) {
    final categories = {...state.categories};
    for (final job in jobs) {
      if (job.category.isNotEmpty) {
        categories.add(job.category);
      }
    }
    return categories;
  }

  JobStatus? _defaultStatus(JobListType type) {
    switch (type) {
      case JobListType.available:
        return JobStatus.pending;
      case JobListType.mine:
        return null;
      case JobListType.completed:
        return JobStatus.completed;
    }
  }

  void _onClearJobMessage(ClearJobMessage event, Emitter<JobState> emit) {
    emit(state.copyWith(clearMessage: true, clearError: true, clearNotification: true));
  }
}
